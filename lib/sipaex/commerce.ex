defmodule Sipaex.Commerce do
  @moduledoc """
  Minimal purchase and sales workflows used by tax reporting.
  """

  import Ecto.Query

  alias Sipaex.Commerce.Entry
  alias Sipaex.Commerce.Party
  alias Sipaex.Common.Currencies
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Ledger
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo
  alias Sipaex.Taxes
  alias Sipaex.Taxes.VatRate

  def settings(entry_type) when entry_type in ["purchase", "sale"] do
    organization = first_organization!()
    currency_settings = Currencies.currency_settings()
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
      |> preload([entry, party], [:currency, :vat_rate_config, party: party])
      |> order_by([entry], desc: entry.entry_date, desc: entry.inserted_at)
      |> Repo.all()

    %{
      organization: organization,
      currency_settings: currency_settings,
      entry_type: entry_type,
      parties: parties,
      entries: entries,
      vat_rates: vat_rates,
      currencies: Enum.map(currency_settings.organization_currencies, & &1.currency),
      totals: totals(entries)
    }
  end

  def create_party(entry_type, attrs) when entry_type in ["purchase", "sale"] do
    organization = first_organization!()

    %Party{}
    |> Party.changeset(
      attrs
      |> Map.put("organization_id", organization.id)
      |> Map.put("party_type", entry_type)
    )
    |> Repo.insert()
  end

  def create_entry(entry_type, attrs) when entry_type in ["purchase", "sale"] do
    party = Repo.get!(Party, attrs["party_id"])
    currency = Repo.get!(Currency, attrs["currency_id"])
    vat_rate = Repo.get!(VatRate, attrs["vat_rate_id"])
    exchange_rate = exchange_rate_for(currency, attrs["exchange_rate"])
    exempt_amount = decimal_from_param(attrs["exempt_amount"] || "0")
    taxable_amount = decimal_from_param(attrs["taxable_amount"] || "0")
    payment = decimal_from_param(attrs["payment"] || "0")
    vat_amount = Decimal.mult(taxable_amount, vat_rate.rate)
    total = exempt_amount |> Decimal.add(taxable_amount) |> Decimal.add(vat_amount)

    attrs =
      attrs
      |> Map.put("entry_type", entry_type)
      |> Map.put("vat_rate", vat_rate.rate)
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

    if party.party_type == entry_type do
      %Entry{}
      |> Entry.changeset(attrs)
      |> Repo.insert()
    else
      {:error, :invalid_party_type}
    end
  end

  def vat_total(entry_type, month, year) when entry_type in ["purchase", "sale"] do
    organization = first_organization!()

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

  defp sum_entries(entries, field) do
    Enum.reduce(entries, Decimal.new("0"), fn entry, acc ->
      Decimal.add(acc, Map.fetch!(entry, field))
    end)
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
end
