defmodule Sipaex.Commerce do
  @moduledoc """
  Minimal purchase and sales workflows used by tax reporting.
  """

  import Ecto.Query

  alias Sipaex.Accounting
  alias Sipaex.Commerce.Entry
  alias Sipaex.Commerce.EntryLine
  alias Sipaex.Commerce.Party
  alias Sipaex.Common.Currencies
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Inventory
  alias Sipaex.Inventory.Product
  alias Sipaex.Ledger
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo
  alias Sipaex.Taxes
  alias Sipaex.Taxes.VatRate

  def settings(entry_type, organization \\ first_organization!())
      when entry_type in ["purchase", "sale"] do
    organization = Repo.preload(organization, :base_currency)
    currency_settings = Currencies.currency_settings(organization)
    Taxes.ensure_default_vat_rates!(organization)
    vat_rates = active_vat_rates(organization)

    parties =
      Party
      |> where([party], party.organization_id == ^organization.id)
      |> where([party], party.party_type == ^entry_type)
      |> order_by([party], asc: party.name)
      |> Repo.all()

    entries =
      Entry
      |> join(:inner, [entry], party in assoc(entry, :party))
      |> where([entry, party], entry.entry_type == ^entry_type)
      |> where([_entry, party], party.organization_id == ^organization.id)
      |> preload([entry, party], [:currency, :vat_rate_config, lines: :product, party: party])
      |> order_by([entry], desc: entry.entry_date, desc: entry.inserted_at)
      |> Repo.all()

    %{
      organization: organization,
      currency_settings: currency_settings,
      entry_type: entry_type,
      parties: parties,
      entries: entries,
      vat_rates: vat_rates,
      products: Inventory.list_products(organization),
      document_products: Inventory.list_active_products(organization),
      currencies: Enum.map(currency_settings.organization_currencies, & &1.currency),
      totals: totals(entries)
    }
  end

  def create_party(entry_type, attrs, organization \\ first_organization!())
      when entry_type in ["purchase", "sale"] do
    %Party{}
    |> Party.changeset(
      attrs
      |> Map.put("organization_id", organization.id)
      |> Map.put("party_type", entry_type)
    )
    |> Repo.insert()
  end

  def create_product(attrs, organization \\ first_organization!()),
    do: Inventory.create_product(attrs, organization)

  def create_entry(entry_type, attrs, organization \\ first_organization!())
      when entry_type in ["purchase", "sale"] do
    with %Party{} <- get_party_for_organization(attrs["party_id"], entry_type, organization),
         %Currency{} = currency <-
           Currencies.currency_for_organization(attrs["currency_id"], organization),
         entry_date = date_from_param(attrs["entry_date"]),
         :ok <- Accounting.ensure_writable_period(organization, entry_date),
         exchange_rate = exchange_rate_for(currency, attrs["exchange_rate"]),
         {:ok, line_specs} <-
           receipt_line_specs(entry_type, attrs, organization, currency, exchange_rate),
         %VatRate{} = primary_vat_rate <- primary_vat_rate(line_specs) do
      exempt_amount = sum_line_specs(line_specs, :native_exempt_amount)
      taxable_amount = sum_line_specs(line_specs, :native_taxable_amount)
      payment = decimal_from_param(attrs["payment"] || "0")
      vat_amount = sum_line_specs(line_specs, :native_vat_amount)
      total = exempt_amount |> Decimal.add(taxable_amount) |> Decimal.add(vat_amount)

      attrs =
        attrs
        |> Map.put("organization_id", organization.id)
        |> Map.put("entry_type", entry_type)
        |> Map.put("vat_rate_id", primary_vat_rate.id)
        |> Map.put("vat_rate", primary_vat_rate.rate)
        |> Map.put("exempt_amount_usd", amount_to_usd(exempt_amount, currency, exchange_rate))
        |> Map.put("taxable_amount_usd", amount_to_usd(taxable_amount, currency, exchange_rate))
        |> Map.put("vat_amount_usd", amount_to_usd(vat_amount, currency, exchange_rate))
        |> Map.put("total_usd", amount_to_usd(total, currency, exchange_rate))
        |> Map.put("payment_usd", amount_to_usd(payment, currency, exchange_rate))
        |> Map.put(
          "balance_usd",
          amount_to_usd(Decimal.sub(total, payment), currency, exchange_rate)
        )
        |> Map.put("exchange_rate", exchange_rate)

      Ecto.Multi.new()
      |> Ecto.Multi.insert(:entry, Entry.changeset(%Entry{}, attrs))
      |> Ecto.Multi.run(:lines, fn repo, %{entry: entry} ->
        insert_receipt_lines(repo, entry, line_specs)
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{entry: entry}} -> {:ok, entry}
        {:error, _operation, reason, _changes} -> {:error, reason}
      end
    else
      nil -> {:error, :invalid_commerce_reference}
      {:error, reason} -> {:error, reason}
    end
  end

  def vat_total(entry_type, month, year, organization \\ first_organization!())
      when entry_type in ["purchase", "sale"] do
    organization = Repo.preload(organization, :base_currency)

    Entry
    |> join(:inner, [entry], party in assoc(entry, :party))
    |> where([entry, party], entry.entry_type == ^entry_type)
    |> where([_entry, party], party.organization_id == ^organization.id)
    |> where([entry, _party], fragment("EXTRACT(MONTH FROM ?)::int", entry.entry_date) == ^month)
    |> where([entry, _party], fragment("EXTRACT(YEAR FROM ?)::int", entry.entry_date) == ^year)
    |> Repo.all()
    |> Enum.reduce(Decimal.new("0"), fn entry, acc ->
      Decimal.add(acc, entry.vat_amount_usd)
    end)
  end

  def display_amount(amount, settings) do
    Ledger.display_amount(amount, settings.currency_settings)
  end

  def display_native_amount(amount_usd, entry) do
    amount =
      if entry.currency.code == Currencies.storage_currency_code() do
        amount_usd
      else
        Decimal.mult(amount_usd, entry.exchange_rate)
      end

    Ledger.display_native_amount(amount, entry.currency)
  end

  def default_exchange_rate_for_currency(%Currency{code: "USD"}), do: Decimal.new("1")

  def default_exchange_rate_for_currency(%Currency{} = currency) do
    ExchangeRate
    |> where([exchange_rate], exchange_rate.quote_currency_id == ^currency.id)
    |> where([exchange_rate], exchange_rate.scope == "GLOBAL")
    |> order_by([exchange_rate], desc: exchange_rate.as_of)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> nil
      exchange_rate -> exchange_rate.rate
    end
  end

  def party_label("purchase"), do: "Proveedor"
  def party_label("sale"), do: "Cliente"
  def module_title("purchase"), do: "Compras"
  def module_title("sale"), do: "Ventas"
  def panel_path("purchase"), do: "/purchases"
  def panel_path("sale"), do: "/sales"

  def line_count(%Entry{lines: lines}) when is_list(lines), do: length(lines)
  def line_count(_entry), do: 0

  defp active_vat_rates(organization) do
    VatRate
    |> where([rate], rate.organization_id == ^organization.id)
    |> where([rate], rate.active)
    |> order_by([rate], asc: rate.rate, asc: rate.description)
    |> Repo.all()
  end

  defp totals(entries) do
    %{
      exempt: sum_entries(entries, :exempt_amount_usd),
      taxable: sum_entries(entries, :taxable_amount_usd),
      vat: sum_entries(entries, :vat_amount_usd),
      total: sum_entries(entries, :total_usd),
      payments: sum_entries(entries, :payment_usd),
      balance: sum_entries(entries, :balance_usd)
    }
  end

  defp receipt_line_specs("purchase", attrs, organization, currency, exchange_rate) do
    attrs
    |> Map.get("lines", %{})
    |> normalize_line_params()
    |> Enum.reduce_while({:ok, []}, fn params, {:ok, specs} ->
      case build_line_spec(params, organization, currency, exchange_rate) do
        {:ok, spec} -> {:cont, {:ok, [spec | specs]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, specs} ->
        specs =
          specs
          |> Enum.reverse()
          |> Enum.reject(fn spec ->
            Decimal.equal?(spec.native_total, Decimal.new("0")) and spec.description == ""
          end)

        case specs do
          [] -> fallback_line_specs(attrs, organization, currency, exchange_rate)
          specs -> {:ok, specs}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp receipt_line_specs(_entry_type, attrs, organization, currency, exchange_rate) do
    fallback_line_specs(attrs, organization, currency, exchange_rate)
  end

  defp normalize_line_params(lines) when is_map(lines) do
    lines
    |> Enum.sort_by(fn {index, _params} -> index end)
    |> Enum.map(fn {_index, params} -> params end)
  end

  defp normalize_line_params(lines) when is_list(lines), do: lines
  defp normalize_line_params(_lines), do: []

  defp build_line_spec(params, organization, currency, exchange_rate) do
    product = product_from_param(params["product_id"], organization)
    vat_rate = vat_rate_from_param(params["vat_rate_id"], organization)

    cond do
      is_nil(vat_rate) ->
        {:error, :invalid_vat_rate}

      is_nil(product) and params["product_id"] not in [nil, ""] ->
        {:error, :invalid_product}

      true ->
        build_line_spec(params, currency, exchange_rate, product, vat_rate)
    end
  end

  defp build_line_spec(params, currency, exchange_rate, product, vat_rate) do
    quantity = decimal_from_param(params["quantity"] || "1")
    unit_price = decimal_from_param(params["unit_price"] || "0")
    subtotal = Decimal.mult(quantity, unit_price)

    taxable_amount =
      if Decimal.equal?(vat_rate.rate, Decimal.new("0")), do: Decimal.new("0"), else: subtotal

    exempt_amount =
      if Decimal.equal?(vat_rate.rate, Decimal.new("0")), do: subtotal, else: Decimal.new("0")

    vat_amount = Decimal.mult(taxable_amount, vat_rate.rate)
    total = subtotal |> Decimal.add(vat_amount)

    {:ok,
     %{
       product_id: product && product.id,
       description: line_description(params, product),
       quantity: quantity,
       unit_price: unit_price,
       vat_rate_id: vat_rate.id,
       vat_rate: vat_rate.rate,
       native_exempt_amount: exempt_amount,
       native_taxable_amount: taxable_amount,
       native_vat_amount: vat_amount,
       native_total: total,
       exempt_amount_usd: amount_to_usd(exempt_amount, currency, exchange_rate),
       taxable_amount_usd: amount_to_usd(taxable_amount, currency, exchange_rate),
       vat_amount_usd: amount_to_usd(vat_amount, currency, exchange_rate),
       total_usd: amount_to_usd(total, currency, exchange_rate)
     }}
  end

  defp fallback_line_specs(attrs, organization, currency, exchange_rate) do
    vat_rate = vat_rate_from_param(attrs["vat_rate_id"], organization)

    if vat_rate do
      build_fallback_line_specs(attrs, currency, exchange_rate, vat_rate)
    else
      {:error, :invalid_vat_rate}
    end
  end

  defp build_fallback_line_specs(attrs, currency, exchange_rate, vat_rate) do
    exempt_amount = decimal_from_param(attrs["exempt_amount"] || "0")
    taxable_amount = decimal_from_param(attrs["taxable_amount"] || "0")
    vat_amount = Decimal.mult(taxable_amount, vat_rate.rate)
    total = exempt_amount |> Decimal.add(taxable_amount) |> Decimal.add(vat_amount)

    {:ok,
     [
       %{
         description: String.trim(attrs["concept"] || "Documento"),
         product_id: nil,
         quantity: Decimal.new("1"),
         unit_price: Decimal.add(exempt_amount, taxable_amount),
         vat_rate_id: vat_rate.id,
         vat_rate: vat_rate.rate,
         native_exempt_amount: exempt_amount,
         native_taxable_amount: taxable_amount,
         native_vat_amount: vat_amount,
         native_total: total,
         exempt_amount_usd: amount_to_usd(exempt_amount, currency, exchange_rate),
         taxable_amount_usd: amount_to_usd(taxable_amount, currency, exchange_rate),
         vat_amount_usd: amount_to_usd(vat_amount, currency, exchange_rate),
         total_usd: amount_to_usd(total, currency, exchange_rate)
       }
     ]}
  end

  defp primary_vat_rate([first_spec | _line_specs]),
    do: Repo.get!(VatRate, first_spec.vat_rate_id)

  defp sum_line_specs(line_specs, field) do
    Enum.reduce(line_specs, Decimal.new("0"), fn line_spec, acc ->
      Decimal.add(acc, Map.fetch!(line_spec, field))
    end)
  end

  defp insert_receipt_lines(repo, entry, line_specs) do
    line_specs
    |> Enum.map(fn line_spec ->
      attrs = %{
        entry_id: entry.id,
        organization_id: entry.organization_id,
        product_id: line_spec.product_id,
        vat_rate_id: line_spec.vat_rate_id,
        description: line_spec.description,
        quantity: line_spec.quantity,
        unit_price: line_spec.unit_price,
        vat_rate: line_spec.vat_rate,
        exempt_amount_usd: line_spec.exempt_amount_usd,
        taxable_amount_usd: line_spec.taxable_amount_usd,
        vat_amount_usd: line_spec.vat_amount_usd,
        total_usd: line_spec.total_usd
      }

      %EntryLine{}
      |> EntryLine.changeset(attrs)
      |> repo.insert()
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, line}, {:ok, lines} -> {:cont, {:ok, [line | lines]}}
      {:error, changeset}, _acc -> {:halt, {:error, changeset}}
    end)
  end

  defp sum_entries(entries, field) do
    Enum.reduce(entries, Decimal.new("0"), fn entry, acc ->
      Decimal.add(acc, Map.fetch!(entry, field))
    end)
  end

  defp get_party_for_organization(id, entry_type, organization) do
    Party
    |> where([party], party.id == ^id)
    |> where([party], party.organization_id == ^organization.id)
    |> where([party], party.party_type == ^entry_type)
    |> Repo.one()
  end

  defp product_from_param(product_id, _organization) when product_id in [nil, ""], do: nil

  defp product_from_param(product_id, organization) do
    Product
    |> where([product], product.id == ^product_id)
    |> where([product], product.organization_id == ^organization.id)
    |> Repo.one()
  end

  defp vat_rate_from_param(vat_rate_id, organization) do
    VatRate
    |> where([rate], rate.id == ^vat_rate_id)
    |> where([rate], rate.organization_id == ^organization.id)
    |> Repo.one()
  end

  defp line_description(params, nil), do: String.trim(params["description"] || "")

  defp line_description(params, %Product{} = product) do
    case String.trim(params["description"] || "") do
      "" -> product.name
      description -> description
    end
  end

  defp first_organization! do
    Organization
    |> order_by([organization], asc: organization.inserted_at)
    |> preload(:base_currency)
    |> Repo.one!()
  end

  defp exchange_rate_for(%Currency{code: "USD"}, _exchange_rate), do: Decimal.new("1")

  defp exchange_rate_for(currency, exchange_rate) when exchange_rate in [nil, ""] do
    default_exchange_rate_for_currency(currency) || Decimal.new("1")
  end

  defp exchange_rate_for(_currency, exchange_rate), do: decimal_from_param(exchange_rate)

  defp amount_to_usd(amount, %Currency{code: "USD"}, _exchange_rate), do: amount
  defp amount_to_usd(amount, _currency, exchange_rate), do: Decimal.div(amount, exchange_rate)

  defp decimal_from_param(%Decimal{} = value), do: value
  defp decimal_from_param(nil), do: Decimal.new("0")
  defp decimal_from_param(""), do: Decimal.new("0")
  defp decimal_from_param(value) when is_integer(value), do: Decimal.new(value)
  defp decimal_from_param(value) when is_binary(value), do: Decimal.new(value)

  defp date_from_param(%Date{} = value), do: value
  defp date_from_param(value) when is_binary(value), do: Date.from_iso8601!(value)
end
