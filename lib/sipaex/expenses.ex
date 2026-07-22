defmodule Sipaex.Expenses do
  @moduledoc """
  Expense workflows for administrative, sales, and financial expenses.
  """

  import Ecto.Query

  alias Sipaex.Common.Currencies
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Expenses.Entry
  alias Sipaex.Expenses.FinancialEntry
  alias Sipaex.Expenses.Provider
  alias Sipaex.Ledger
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo

  @ordinary_categories ~w(administrative sales)
  @tax_rate_options [
    {"0%", "0"},
    {"1%", "0.01"},
    {"2%", "0.02"},
    {"4%", "0.04"},
    {"8%", "0.08"},
    {"13%", "0.13"}
  ]

  def settings do
    organization = first_organization!()
    currency_settings = Currencies.currency_settings()

    providers =
      Provider
      |> where([provider], provider.organization_id == ^organization.id)
      |> order_by([provider], asc: provider.category, asc: provider.name)
      |> Repo.all()

    entries =
      Entry
      |> join(:inner, [entry], provider in assoc(entry, :provider))
      |> where([_entry, provider], provider.organization_id == ^organization.id)
      |> preload([entry, provider], [:currency, provider: provider])
      |> order_by([entry], desc: entry.entry_date, desc: entry.inserted_at)
      |> Repo.all()

    financial_entries =
      FinancialEntry
      |> join(:inner, [entry], provider in assoc(entry, :provider))
      |> where([_entry, provider], provider.organization_id == ^organization.id)
      |> preload([entry, provider], [:currency, provider: provider])
      |> order_by([entry], desc: entry.entry_date, desc: entry.inserted_at)
      |> Repo.all()

    ordinary_rows = ordinary_rows(providers, entries)
    financial_rows = financial_rows(providers, financial_entries)
    ordinary_totals = ordinary_totals(ordinary_rows)
    financial_totals = financial_totals(financial_rows)

    %{
      organization: organization,
      currency_settings: currency_settings,
      providers: providers,
      administrative_providers: providers_for(providers, "administrative"),
      sales_providers: providers_for(providers, "sales"),
      financial_providers: providers_for(providers, "financial"),
      entries: entries,
      financial_entries: financial_entries,
      ordinary_rows: ordinary_rows,
      financial_rows: financial_rows,
      ordinary_totals: ordinary_totals,
      financial_totals: financial_totals,
      totals: totals(ordinary_totals, financial_totals),
      currencies: Enum.map(currency_settings.organization_currencies, & &1.currency)
    }
  end

  def create_provider(attrs) do
    organization = first_organization!()

    %Provider{}
    |> Provider.changeset(Map.put(attrs, "organization_id", organization.id))
    |> Repo.insert()
  end

  def create_entry(attrs) do
    provider = Repo.get!(Provider, attrs["provider_id"])
    currency = Repo.get!(Currency, attrs["currency_id"])
    exchange_rate = exchange_rate_for(currency, attrs["exchange_rate"])

    exempt_amount = decimal_from_param(attrs["exempt_amount"])
    taxable_amount = decimal_from_param(attrs["taxable_amount"])
    tax_rate = decimal_from_param(attrs["tax_rate"] || "0")
    credit_note = decimal_from_param(attrs["credit_note"] || "0")
    debit_note = decimal_from_param(attrs["debit_note"] || "0")
    payment = decimal_from_param(attrs["payment"] || "0")
    tax_amount = Decimal.mult(taxable_amount, tax_rate)

    total =
      exempt_amount
      |> Decimal.add(taxable_amount)
      |> Decimal.add(tax_amount)
      |> Decimal.sub(credit_note)
      |> Decimal.add(debit_note)

    attrs =
      attrs
      |> Map.put("category", provider.category)
      |> Map.put("exchange_rate", exchange_rate)
      |> Map.put("exempt_amount_usd", amount_to_usd(exempt_amount, currency, exchange_rate))
      |> Map.put("taxable_amount_usd", amount_to_usd(taxable_amount, currency, exchange_rate))
      |> Map.put("tax_rate", tax_rate)
      |> Map.put("tax_amount_usd", amount_to_usd(tax_amount, currency, exchange_rate))
      |> Map.put("credit_note_usd", amount_to_usd(credit_note, currency, exchange_rate))
      |> Map.put("debit_note_usd", amount_to_usd(debit_note, currency, exchange_rate))
      |> Map.put("total_usd", amount_to_usd(total, currency, exchange_rate))
      |> Map.put("payment_usd", amount_to_usd(payment, currency, exchange_rate))
      |> Map.put(
        "payable_usd",
        amount_to_usd(Decimal.sub(total, payment), currency, exchange_rate)
      )

    %Entry{}
    |> Entry.changeset(attrs)
    |> Repo.insert()
  end

  def create_financial_entry(attrs) do
    currency = Repo.get!(Currency, attrs["currency_id"])
    exchange_rate = exchange_rate_for(currency, attrs["exchange_rate"])

    loan_amount = decimal_from_param(attrs["loan_amount"] || "0")
    principal_payment = decimal_from_param(attrs["principal_payment"] || "0")
    financial_expense = decimal_from_param(attrs["financial_expense"] || "0")
    credit_note = decimal_from_param(attrs["credit_note"] || "0")
    debit_note = decimal_from_param(attrs["debit_note"] || "0")
    financial_expense_payment = decimal_from_param(attrs["financial_expense_payment"] || "0")

    net_financial_expense =
      financial_expense
      |> Decimal.sub(credit_note)
      |> Decimal.add(debit_note)

    attrs =
      attrs
      |> Map.put("exchange_rate", exchange_rate)
      |> Map.put("loan_amount_usd", amount_to_usd(loan_amount, currency, exchange_rate))
      |> Map.put(
        "principal_payment_usd",
        amount_to_usd(principal_payment, currency, exchange_rate)
      )
      |> Map.put(
        "financial_expense_usd",
        amount_to_usd(financial_expense, currency, exchange_rate)
      )
      |> Map.put("credit_note_usd", amount_to_usd(credit_note, currency, exchange_rate))
      |> Map.put("debit_note_usd", amount_to_usd(debit_note, currency, exchange_rate))
      |> Map.put(
        "net_financial_expense_usd",
        amount_to_usd(net_financial_expense, currency, exchange_rate)
      )
      |> Map.put(
        "financial_expense_payment_usd",
        amount_to_usd(financial_expense_payment, currency, exchange_rate)
      )
      |> Map.put(
        "loan_payable_usd",
        amount_to_usd(Decimal.sub(loan_amount, principal_payment), currency, exchange_rate)
      )
      |> Map.put(
        "financial_expense_payable_usd",
        amount_to_usd(
          Decimal.sub(net_financial_expense, financial_expense_payment),
          currency,
          exchange_rate
        )
      )

    %FinancialEntry{}
    |> FinancialEntry.changeset(attrs)
    |> Repo.insert()
  end

  def summary_totals do
    settings().totals
  end

  def vat_total(month, year) do
    organization = first_organization!()

    Entry
    |> join(:inner, [entry], provider in assoc(entry, :provider))
    |> where([_entry, provider], provider.organization_id == ^organization.id)
    |> where(
      [entry, _provider],
      fragment("EXTRACT(MONTH FROM ?)::int", entry.entry_date) == ^month
    )
    |> where([entry, _provider], fragment("EXTRACT(YEAR FROM ?)::int", entry.entry_date) == ^year)
    |> Repo.all()
    |> Enum.reduce(Decimal.new("0"), fn entry, acc ->
      Decimal.add(acc, entry.tax_amount_usd)
    end)
  end

  def provider_category_options do
    [
      {"Administrativos", "administrative"},
      {"Ventas", "sales"},
      {"Financieros", "financial"}
    ]
  end

  def entry_category_label("administrative"), do: "Administrativo"
  def entry_category_label("sales"), do: "Ventas"
  def entry_category_label("financial"), do: "Financiero"
  def entry_category_label(category), do: category

  def tax_rate_options, do: @tax_rate_options

  def display_amount(amount, settings) do
    Ledger.display_amount(amount, settings.currency_settings)
  end

  def display_native_amount(amount_usd, entry, _settings) do
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

  defp ordinary_rows(providers, entries) do
    providers
    |> Enum.filter(&(&1.category in @ordinary_categories))
    |> Enum.map(fn provider ->
      provider_entries = Enum.filter(entries, &(&1.provider_id == provider.id))

      %{
        provider: provider,
        exempt: sum_entries(provider_entries, :exempt_amount_usd),
        taxable: sum_entries(provider_entries, :taxable_amount_usd),
        tax: sum_entries(provider_entries, :tax_amount_usd),
        total: sum_entries(provider_entries, :total_usd),
        payments: sum_entries(provider_entries, :payment_usd),
        payable: sum_entries(provider_entries, :payable_usd),
        credit_notes: sum_entries(provider_entries, :credit_note_usd),
        debit_notes: sum_entries(provider_entries, :debit_note_usd)
      }
    end)
  end

  defp financial_rows(providers, entries) do
    providers
    |> Enum.filter(&(&1.category == "financial"))
    |> Enum.map(fn provider ->
      provider_entries = Enum.filter(entries, &(&1.provider_id == provider.id))
      loans = sum_entries(provider_entries, :loan_amount_usd)
      principal_payments = sum_entries(provider_entries, :principal_payment_usd)
      net_financial_expenses = sum_entries(provider_entries, :net_financial_expense_usd)
      financial_expense_payments = sum_entries(provider_entries, :financial_expense_payment_usd)

      %{
        provider: provider,
        loans: loans,
        principal_payments: principal_payments,
        loan_payable: Decimal.sub(loans, principal_payments),
        financial_expenses: net_financial_expenses,
        financial_expense_payments: financial_expense_payments,
        financial_expense_payable: Decimal.sub(net_financial_expenses, financial_expense_payments)
      }
    end)
  end

  defp ordinary_totals(rows) do
    %{
      exempt: sum_rows(rows, :exempt),
      taxable: sum_rows(rows, :taxable),
      tax: sum_rows(rows, :tax),
      total: sum_rows(rows, :total),
      payments: sum_rows(rows, :payments),
      payable: sum_rows(rows, :payable),
      administrative_payments: sum_category(rows, "administrative", :payments),
      sales_payments: sum_category(rows, "sales", :payments)
    }
  end

  defp financial_totals(rows) do
    %{
      loans: sum_rows(rows, :loans),
      principal_payments: sum_rows(rows, :principal_payments),
      loan_payable: sum_rows(rows, :loan_payable),
      financial_expenses: sum_rows(rows, :financial_expenses),
      financial_expense_payments: sum_rows(rows, :financial_expense_payments),
      financial_expense_payable: sum_rows(rows, :financial_expense_payable)
    }
  end

  defp totals(ordinary_totals, financial_totals) do
    %{
      administrative_payments: ordinary_totals.administrative_payments,
      sales_payments: ordinary_totals.sales_payments,
      financial_expense_payments: financial_totals.financial_expense_payments,
      principal_payments: financial_totals.principal_payments,
      financial_loans: financial_totals.loans
    }
  end

  defp providers_for(providers, category), do: Enum.filter(providers, &(&1.category == category))

  defp sum_entries(entries, field) do
    Enum.reduce(entries, Decimal.new("0"), fn entry, acc ->
      Decimal.add(acc, Map.fetch!(entry, field))
    end)
  end

  defp sum_rows(rows, field) do
    Enum.reduce(rows, Decimal.new("0"), fn row, acc ->
      Decimal.add(acc, Map.fetch!(row, field))
    end)
  end

  defp sum_category(rows, category, field) do
    rows
    |> Enum.filter(&(&1.provider.category == category))
    |> sum_rows(field)
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
