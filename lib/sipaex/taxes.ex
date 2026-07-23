defmodule Sipaex.Taxes do
  @moduledoc """
  Income tax and VAT workflows.
  """

  import Ecto.Query

  alias Sipaex.Accounting
  alias Sipaex.Common.Currencies
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Commerce
  alias Sipaex.Expenses
  alias Sipaex.Ledger
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo
  alias Sipaex.Taxes.IncomeTaxEntry
  alias Sipaex.Taxes.VatPeriod
  alias Sipaex.Taxes.VatRate

  @default_vat_rates [
    {"CR", "Exento", "0", "Bienes y servicios exentos o no sujetos."},
    {"CR", "Reducido 1%", "0.01", "Tarifa reducida."},
    {"CR", "Reducido 2%", "0.02", "Tarifa reducida."},
    {"CR", "Reducido 4%", "0.04", "Tarifa reducida."},
    {"CR", "Reducido 8%", "0.08", "Tarifa reducida."},
    {"CR", "General 13%", "0.13", "Tarifa general de Costa Rica."}
  ]

  def settings(organization \\ first_organization!()) do
    organization = Repo.preload(organization, :base_currency)
    currency_settings = Currencies.currency_settings(organization)
    ensure_default_vat_rates!(organization)

    vat_rates =
      VatRate
      |> where([rate], rate.organization_id == ^organization.id)
      |> order_by([rate], asc: rate.country_code, asc: rate.rate, asc: rate.name)
      |> Repo.all()

    income_tax_entries =
      IncomeTaxEntry
      |> where([entry], entry.organization_id == ^organization.id)
      |> preload(:currency)
      |> order_by([entry], desc: entry.entry_date, desc: entry.inserted_at)
      |> Repo.all()

    vat_periods =
      VatPeriod
      |> where([period], period.organization_id == ^organization.id)
      |> preload(:currency)
      |> order_by([period], desc: period.period_year, desc: period.period_month)
      |> Repo.all()

    income_tax_totals = income_tax_totals(income_tax_entries)
    vat_totals = vat_totals(vat_periods)

    %{
      organization: organization,
      currency_settings: currency_settings,
      currencies: Enum.map(currency_settings.organization_currencies, & &1.currency),
      vat_rates: vat_rates,
      income_tax_entries: income_tax_entries,
      vat_periods: vat_periods,
      income_tax_totals: income_tax_totals,
      vat_totals: vat_totals,
      totals: totals(income_tax_totals, vat_totals),
      expense_tax_credit: Expenses.settings(organization).ordinary_totals.tax
    }
  end

  def create_vat_rate(attrs, organization \\ first_organization!()) do
    rate = percentage_to_rate(attrs["rate"])
    description = attrs["description"] || ""

    %VatRate{}
    |> VatRate.changeset(
      attrs
      |> Map.put("organization_id", organization.id)
      |> Map.put("country_code", "CR")
      |> Map.put("name", "IVA #{display_rate(rate)}")
      |> Map.put("rate", rate)
      |> Map.put("description", description)
    )
    |> Repo.insert()
  end

  def toggle_vat_rate(id, organization \\ first_organization!()) do
    VatRate
    |> where([rate], rate.id == ^id)
    |> where([rate], rate.organization_id == ^organization.id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :invalid_vat_rate}

      rate ->
        if exempt_vat_rate?(rate) and rate.active do
          {:error, :exempt_vat_required}
        else
          rate
          |> VatRate.changeset(%{active: !rate.active})
          |> Repo.update()
        end
    end
  end

  def create_income_tax_entry(attrs, organization \\ first_organization!()) do
    with %Currency{} = currency <-
           Currencies.currency_for_organization(attrs["currency_id"], organization),
         entry_date = date_from_param(attrs["entry_date"]),
         :ok <- Accounting.ensure_writable_period(organization, entry_date) do
      exchange_rate = exchange_rate_for(currency, attrs["exchange_rate"])
      tax_amount = decimal_from_param(attrs["tax_amount"])
      payment = decimal_from_param(attrs["payment"] || "0")

      attrs =
        attrs
        |> Map.put("organization_id", organization.id)
        |> Map.put("exchange_rate", exchange_rate)
        |> Map.put("tax_amount_usd", amount_to_usd(tax_amount, currency, exchange_rate))
        |> Map.put("payment_usd", amount_to_usd(payment, currency, exchange_rate))
        |> Map.put(
          "payable_usd",
          amount_to_usd(Decimal.sub(tax_amount, payment), currency, exchange_rate)
        )

      %IncomeTaxEntry{}
      |> IncomeTaxEntry.changeset(attrs)
      |> Repo.insert()
    else
      nil -> {:error, :invalid_currency}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_vat_period(attrs, organization \\ first_organization!()) do
    month = integer_from_param(attrs["period_month"])
    year = integer_from_param(attrs["period_year"])
    period_date = Date.new!(year, month, 1)

    with %Currency{} = currency <-
           Currencies.currency_for_organization(attrs["currency_id"], organization),
         :ok <- Accounting.ensure_writable_period(organization, period_date) do
      exchange_rate = exchange_rate_for(currency, attrs["exchange_rate"])
      source_totals = vat_source_totals(month, year, organization)
      payment = decimal_from_param(attrs["payment"] || "0")

      net_vat =
        source_totals.debit_sales
        |> Decimal.sub(source_totals.credit_purchases)
        |> Decimal.sub(source_totals.credit_expenses)

      attrs =
        attrs
        |> Map.put("organization_id", organization.id)
        |> Map.put("period_month", month)
        |> Map.put("period_year", year)
        |> Map.put("exchange_rate", exchange_rate)
        |> Map.put("debit_sales_usd", source_totals.debit_sales)
        |> Map.put("credit_purchases_usd", source_totals.credit_purchases)
        |> Map.put("credit_expenses_usd", source_totals.credit_expenses)
        |> Map.put("net_vat_usd", net_vat)
        |> Map.put("payment_usd", amount_to_usd(payment, currency, exchange_rate))
        |> Map.put(
          "payable_usd",
          Decimal.sub(net_vat, amount_to_usd(payment, currency, exchange_rate))
        )

      %VatPeriod{}
      |> VatPeriod.changeset(attrs)
      |> Repo.insert()
    else
      nil -> {:error, :invalid_currency}
      {:error, reason} -> {:error, reason}
    end
  end

  def summary_totals(organization \\ first_organization!()) do
    settings(organization).totals
  end

  def vat_source_totals(month, year, organization \\ first_organization!()) do
    %{
      debit_sales: Commerce.vat_total("sale", month, year, organization),
      credit_purchases: Commerce.vat_total("purchase", month, year, organization),
      credit_expenses: Expenses.vat_total(month, year, organization)
    }
  end

  def month_options do
    [
      {"Enero", "1"},
      {"Febrero", "2"},
      {"Marzo", "3"},
      {"Abril", "4"},
      {"Mayo", "5"},
      {"Junio", "6"},
      {"Julio", "7"},
      {"Agosto", "8"},
      {"Setiembre", "9"},
      {"Octubre", "10"},
      {"Noviembre", "11"},
      {"Diciembre", "12"}
    ]
  end

  def month_name(1), do: "Enero"
  def month_name(2), do: "Febrero"
  def month_name(3), do: "Marzo"
  def month_name(4), do: "Abril"
  def month_name(5), do: "Mayo"
  def month_name(6), do: "Junio"
  def month_name(7), do: "Julio"
  def month_name(8), do: "Agosto"
  def month_name(9), do: "Setiembre"
  def month_name(10), do: "Octubre"
  def month_name(11), do: "Noviembre"
  def month_name(12), do: "Diciembre"
  def month_name(month), do: month

  def vat_rate_options do
    settings()
    |> Map.fetch!(:vat_rates)
    |> Enum.filter(& &1.active)
    |> Enum.map(&{"#{&1.name} (#{display_rate(&1.rate)})", Decimal.to_string(&1.rate, :normal)})
  end

  def display_rate(rate) do
    rate
    |> Decimal.mult(Decimal.new("100"))
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> Kernel.<>("%")
  end

  def exempt_vat_rate?(%VatRate{} = rate), do: Decimal.equal?(rate.rate, Decimal.new("0"))

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

  defp income_tax_totals(entries) do
    tax = sum_entries(entries, :tax_amount_usd)
    payments = sum_entries(entries, :payment_usd)

    %{
      tax: tax,
      payments: payments,
      payable: Decimal.sub(tax, payments)
    }
  end

  defp vat_totals(periods) do
    vat = sum_entries(periods, :net_vat_usd)
    payments = sum_entries(periods, :payment_usd)

    %{
      debit_sales: sum_entries(periods, :debit_sales_usd),
      credit_purchases: sum_entries(periods, :credit_purchases_usd),
      credit_expenses: sum_entries(periods, :credit_expenses_usd),
      vat: vat,
      payments: payments,
      payable: Decimal.sub(vat, payments)
    }
  end

  defp totals(income_tax_totals, vat_totals) do
    %{
      income_tax_payments: income_tax_totals.payments,
      vat_payments: vat_totals.payments
    }
  end

  def ensure_default_vat_rates!(organization) do
    for {country_code, name, rate, description} <- @default_vat_rates do
      %VatRate{}
      |> VatRate.changeset(%{
        organization_id: organization.id,
        country_code: country_code,
        name: name,
        rate: Decimal.new(rate),
        description: description,
        active: true
      })
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: [:organization_id, :country_code, :rate, :name]
      )
    end
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

  defp percentage_to_rate(value) do
    value
    |> decimal_from_param()
    |> Decimal.div(Decimal.new("100"))
  end

  defp integer_from_param(value) when is_integer(value), do: value
  defp integer_from_param(value) when is_binary(value), do: String.to_integer(value)

  defp date_from_param(%Date{} = value), do: value
  defp date_from_param(value) when is_binary(value), do: Date.from_iso8601!(value)
end
