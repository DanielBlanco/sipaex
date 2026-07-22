defmodule Sipaex.Bank do
  @moduledoc """
  Bank summary view data.

  This module collects values that eventually come from multiple ERP modules.
  Missing modules intentionally return zero until their workflows exist.
  """

  import Ecto.Query

  alias Sipaex.Bank.PettyCashTransaction
  alias Sipaex.Common.Currencies
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Dividends
  alias Sipaex.Expenses
  alias Sipaex.Ledger
  alias Sipaex.Ledger.ExchangeDifference
  alias Sipaex.Ledger.Transaction
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo
  alias Sipaex.Taxes

  def summary do
    currency_settings = Currencies.currency_settings()
    organization = first_organization!()

    ledger_rows = ledger_summary_rows(organization, currency_settings)
    rows = static_rows(ledger_rows)
    income_total = sum_rows(rows, :income)
    expense_total = sum_rows(rows, :expense)

    %{
      organization: organization,
      currency_settings: currency_settings,
      rows: rows,
      income_total: income_total,
      expense_total: expense_total,
      balance: Decimal.sub(income_total, expense_total),
      petty_cash: petty_cash_summary(organization, currency_settings),
      petty_cash_transactions: list_petty_cash(organization.id),
      petty_cash_currencies: petty_cash_currencies(currency_settings)
    }
  end

  def create_petty_cash(attrs) do
    organization = first_organization!()
    currency = Repo.get!(Currency, attrs["currency_id"])
    exchange_rate = exchange_rate_for(currency)
    amount = decimal_from_param(attrs["amount"])
    amount_usd = amount_to_usd(amount, currency, exchange_rate)

    attrs =
      attrs
      |> Map.put("organization_id", organization.id)
      |> Map.put("exchange_rate", exchange_rate)
      |> Map.put("amount_usd", amount_usd)

    %PettyCashTransaction{}
    |> PettyCashTransaction.changeset(attrs)
    |> Repo.insert()
  end

  def delete_petty_cash(id) do
    PettyCashTransaction
    |> Repo.get!(id)
    |> Repo.delete()
  end

  def list_petty_cash(organization_id) do
    PettyCashTransaction
    |> where([transaction], transaction.organization_id == ^organization_id)
    |> order_by([transaction], desc: transaction.inserted_at)
    |> preload(:currency)
    |> limit(20)
    |> Repo.all()
  end

  def display_amount(amount, summary) do
    Ledger.display_native_amount(amount, summary.currency_settings.organization.base_currency)
  end

  def display_petty_cash_amount(%PettyCashTransaction{} = transaction) do
    Ledger.display_native_amount(transaction.amount, transaction.currency)
  end

  def petty_cash_type_options do
    [{"Depósito", "deposit"}, {"Retiro", "withdrawal"}]
  end

  def petty_cash_type_label("deposit"), do: "Depósito"
  def petty_cash_type_label("withdrawal"), do: "Retiro"
  def petty_cash_type_label(type), do: type

  def petty_cash_deposit?(%PettyCashTransaction{transaction_type: "deposit"}), do: true
  def petty_cash_deposit?(%PettyCashTransaction{}), do: false

  defp ledger_summary_rows(organization, currency_settings) do
    credit_notes =
      organization
      |> sum_transactions("credit_note")
      |> reporting_amount(currency_settings)

    debit_notes =
      organization
      |> sum_transactions("debit_note")
      |> reporting_amount(currency_settings)

    exchange_difference = sum_exchange_differences(organization, currency_settings)
    expense_totals = Expenses.summary_totals()
    tax_totals = Taxes.summary_totals()

    %{
      credit_notes: credit_notes,
      debit_notes: debit_notes,
      exchange_difference: exchange_difference,
      dividend_payments: Dividends.summary_totals().payments,
      administrative_expenses: expense_totals.administrative_payments,
      sales_expenses: expense_totals.sales_payments,
      financial_expenses: expense_totals.financial_expense_payments,
      principal_payments: expense_totals.principal_payments,
      financial_loans: expense_totals.financial_loans,
      income_tax_payments: tax_totals.income_tax_payments,
      vat_payments: tax_totals.vat_payments
    }
  end

  defp static_rows(ledger_rows) do
    [
      row("EGRESOS POR CUENTAS POR PAGAR COMPRAS"),
      row("INGRESOS POR CUENTAS POR COBRAR VENTAS CORRIENTES"),
      row("EGRESOS POR PAGO COMISIONES SOBRE VENTAS"),
      row(
        "EGRESOS POR GASTOS ADMINISTRATIVOS",
        Decimal.new("0"),
        ledger_rows.administrative_expenses
      ),
      row("EGRESOS POR GASTOS DE VENTA", Decimal.new("0"), ledger_rows.sales_expenses),
      row("INGRESOS POR PRÉSTAMOS (DOC X PAGAR)", ledger_rows.financial_loans, Decimal.new("0")),
      row(
        "EGRESOS POR ABONOS A PRÉSTAMOS (DOC X PAGAR)",
        Decimal.new("0"),
        ledger_rows.principal_payments
      ),
      row(
        "EGRESOS POR PAGO GASTOS FINANCIEROS",
        Decimal.new("0"),
        ledger_rows.financial_expenses
      ),
      row(
        "EGRESOS POR PAGO IMPUESTOS DE RENTA",
        Decimal.new("0"),
        ledger_rows.income_tax_payments
      ),
      row(
        "EGRESOS POR PAGO IMPUESTOS DE VENTA - IVA -",
        Decimal.new("0"),
        ledger_rows.vat_payments
      ),
      row("EGRESOS POR EDIFICIOS POR PAGAR"),
      row("EGRESOS POR EQUIPO DE CÓMPUTO POR PAGAR"),
      row("EGRESOS POR MAQUINARIA POR PAGAR"),
      row("EGRESOS POR MOBILIARIO POR PAGAR"),
      row("EGRESOS POR COMPRA TERRENOS"),
      row("EGRESOS POR VEHÍCULOS POR PAGAR"),
      row("INGRESOS POR EDIFICIOS POR COBRAR"),
      row("INGRESOS POR EQUIPO DE CÓMPUTO POR COBRAR"),
      row("INGRESOS POR MAQUINARIA POR COBRAR"),
      row("INGRESOS POR MOBILIARIO POR COBRAR"),
      row("INGRESOS POR TERRENOS POR COBRAR"),
      row("INGRESOS POR VEHÍCULOS POR COBRAR"),
      row("INGRESOS POR CUENTAS POR COBRAR ACCIONISTAS"),
      row("EGRESOS POR DEDUCCIONES AL SALARIO"),
      row("EGRESOS POR SUELDOS"),
      row("EGRESOS POR CARGAS SOCIALES SOBRE SUELDOS"),
      row("AGUINALDOS"),
      row("EGRESOS POR INCAPACIDADES"),
      row("INGRESOS POR NOTA DE CRÉDITO DE BANCOS", ledger_rows.credit_notes, Decimal.new("0")),
      row("EGRESOS POR NOTA DE DÉBITO DE BANCOS", Decimal.new("0"), ledger_rows.debit_notes),
      row("EGRESOS POR PAGO DE DIVIDENDOS", Decimal.new("0"), ledger_rows.dividend_payments),
      signed_row("DIFERENCIAL CAMBIARIO", ledger_rows.exchange_difference)
    ]
  end

  defp petty_cash_summary(organization, currency_settings) do
    transactions =
      PettyCashTransaction
      |> where([transaction], transaction.organization_id == ^organization.id)
      |> preload(:currency)
      |> Repo.all()

    deposits = sum_petty_cash(transactions, "deposit", currency_settings)
    withdrawals = sum_petty_cash(transactions, "withdrawal", currency_settings)

    %{
      balance: Decimal.sub(deposits, withdrawals),
      deposits: deposits,
      withdrawals: withdrawals
    }
  end

  defp sum_petty_cash(transactions, transaction_type, currency_settings) do
    transactions
    |> Enum.filter(&(&1.transaction_type == transaction_type))
    |> Enum.reduce(Decimal.new("0"), fn transaction, acc ->
      Decimal.add(acc, reporting_amount(transaction.amount_usd, currency_settings))
    end)
  end

  defp petty_cash_currencies(currency_settings) do
    Enum.map(currency_settings.organization_currencies, & &1.currency)
  end

  defp row(concept, income \\ Decimal.new("0"), expense \\ Decimal.new("0")) do
    %{
      concept: concept,
      income: income,
      expense: expense,
      balance: Decimal.sub(income, expense)
    }
  end

  defp signed_row(concept, amount) do
    if Decimal.compare(amount, Decimal.new("0")) == :lt do
      row(concept, Decimal.new("0"), Decimal.abs(amount))
    else
      row(concept, amount, Decimal.new("0"))
    end
  end

  defp sum_rows(rows, field) do
    Enum.reduce(rows, Decimal.new("0"), fn row, acc ->
      Decimal.add(acc, Map.fetch!(row, field))
    end)
  end

  defp reporting_amount(amount_usd, currency_settings) do
    currency = currency_settings.organization.base_currency

    if currency.code == Currencies.storage_currency_code() do
      amount_usd
    else
      rate = Map.fetch!(currency_settings.latest_rates, currency.id)
      Decimal.mult(amount_usd, rate.rate)
    end
  end

  defp sum_transactions(organization, movement_type) do
    Transaction
    |> join(:inner, [transaction], bank_account in assoc(transaction, :bank_account))
    |> where([transaction, bank_account], bank_account.organization_id == ^organization.id)
    |> where([transaction, _bank_account], transaction.movement_type == ^movement_type)
    |> Repo.all()
    |> Enum.reduce(Decimal.new("0"), fn transaction, acc ->
      Decimal.add(acc, transaction.amount_usd)
    end)
  end

  defp sum_exchange_differences(organization, currency_settings) do
    ExchangeDifference
    |> join(
      :inner,
      [exchange_difference],
      bank_account in assoc(exchange_difference, :bank_account)
    )
    |> where(
      [_exchange_difference, bank_account],
      bank_account.organization_id == ^organization.id
    )
    |> preload([exchange_difference, bank_account], bank_account: {bank_account, :currency})
    |> Repo.all()
    |> Enum.reduce(Decimal.new("0"), fn exchange_difference, acc ->
      Decimal.add(
        acc,
        native_to_reporting_amount(
          exchange_difference.result_amount,
          exchange_difference.bank_account.currency,
          currency_settings
        )
      )
    end)
  end

  defp native_to_reporting_amount(amount, source_currency, currency_settings) do
    reporting_currency = currency_settings.organization.base_currency

    amount_usd =
      if source_currency.code == Currencies.storage_currency_code() do
        amount
      else
        source_rate = Map.fetch!(currency_settings.latest_rates, source_currency.id)
        Decimal.div(amount, source_rate.rate)
      end

    if reporting_currency.code == Currencies.storage_currency_code() do
      amount_usd
    else
      reporting_rate = Map.fetch!(currency_settings.latest_rates, reporting_currency.id)
      Decimal.mult(amount_usd, reporting_rate.rate)
    end
  end

  defp first_organization! do
    Organization
    |> order_by([organization], asc: organization.inserted_at)
    |> preload(:base_currency)
    |> Repo.one!()
  end

  defp exchange_rate_for(%Currency{code: "USD"}), do: Decimal.new("1")

  defp exchange_rate_for(%Currency{} = currency) do
    ExchangeRate
    |> where([exchange_rate], exchange_rate.quote_currency_id == ^currency.id)
    |> where([exchange_rate], exchange_rate.scope == "GLOBAL")
    |> order_by([exchange_rate], desc: exchange_rate.as_of)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> Decimal.new("1")
      exchange_rate -> exchange_rate.rate
    end
  end

  defp amount_to_usd(amount, %Currency{code: "USD"}, _exchange_rate), do: amount
  defp amount_to_usd(amount, _currency, exchange_rate), do: Decimal.div(amount, exchange_rate)

  defp decimal_from_param(%Decimal{} = value), do: value
  defp decimal_from_param(value) when is_integer(value), do: Decimal.new(value)
  defp decimal_from_param(value) when is_binary(value), do: Decimal.new(value)
end
