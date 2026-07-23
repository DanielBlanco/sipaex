defmodule Sipaex.Ledger do
  @moduledoc """
  Current-account ledger workflows.

  Ledger entries keep the source amount/currency for audit, while `amount_usd`
  is the canonical stored amount used by derived balances.
  """

  import Ecto.Query

  alias Sipaex.Accounting
  alias Sipaex.Common.Currencies
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Ledger.BankAccount
  alias Sipaex.Ledger.ExchangeDifference
  alias Sipaex.Ledger.Transaction
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo

  @incoming_types ~w(deposit_or_transfer_received credit_note)

  def ledger_settings(organization \\ first_organization!()) do
    currency_settings = Currencies.currency_settings(organization)
    organization = Repo.preload(organization, :base_currency)

    bank_accounts =
      BankAccount
      |> where([bank_account], bank_account.organization_id == ^organization.id)
      |> preload(:currency)
      |> order_by([bank_account], asc: bank_account.name)
      |> Repo.all()

    transactions =
      Transaction
      |> join(:inner, [transaction], bank_account in assoc(transaction, :bank_account))
      |> where([_transaction, bank_account], bank_account.organization_id == ^organization.id)
      |> preload([transaction, bank_account], [:currency, bank_account: {bank_account, :currency}])
      |> order_by([transaction],
        desc: transaction.transaction_date,
        desc: transaction.inserted_at
      )
      |> limit(25)
      |> Repo.all()

    exchange_differences =
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
      |> preload([exchange_difference, bank_account], [
        :currency,
        bank_account: {bank_account, :currency}
      ])
      |> order_by([exchange_difference],
        desc: exchange_difference.transaction_date,
        desc: exchange_difference.inserted_at
      )
      |> Repo.all()

    %{
      currency_settings: currency_settings,
      organization: organization,
      bank_accounts: bank_accounts,
      transactions: transactions,
      exchange_differences: exchange_differences,
      bank_account_balances: bank_account_balances(bank_accounts),
      bank_account_native_balances: bank_account_native_balances(bank_accounts),
      bank_major_rows: bank_major_rows(bank_accounts, exchange_differences),
      total_balance_usd: total_balance_usd(bank_accounts)
    }
  end

  def create_bank_account(attrs, organization \\ first_organization!()) do
    with %Currency{} <- Currencies.currency_for_organization(attrs["currency_id"], organization) do
      %BankAccount{}
      |> BankAccount.changeset(Map.put(attrs, "organization_id", organization.id))
      |> Repo.insert()
    else
      nil -> {:error, :invalid_currency}
    end
  end

  def create_transaction(attrs, organization \\ first_organization!()) do
    with %BankAccount{} = bank_account <-
           get_bank_account_for_organization(attrs["bank_account_id"], organization),
         transaction_date = date_from_param(attrs["transaction_date"]),
         :ok <- Accounting.ensure_writable_period(organization, transaction_date) do
      currency = bank_account.currency
      exchange_rate = exchange_rate_for(currency, attrs["exchange_rate"])
      amount = decimal_from_param(attrs["amount"])
      amount_usd = amount_to_usd(amount, currency, exchange_rate)

      attrs =
        attrs
        |> Map.put("organization_id", organization.id)
        |> Map.put("currency_id", currency.id)
        |> Map.put("exchange_rate", exchange_rate)
        |> Map.put("amount_usd", amount_usd)

      %Transaction{}
      |> Transaction.changeset(attrs)
      |> Repo.insert()
    else
      nil -> {:error, :invalid_bank_account}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_exchange_difference(attrs, organization \\ first_organization!()) do
    with %BankAccount{} = bank_account <-
           get_bank_account_for_organization(attrs["bank_account_id"], organization),
         transaction_date = date_from_param(attrs["transaction_date"]),
         :ok <- Accounting.ensure_writable_period(organization, transaction_date) do
      foreign_amount = decimal_from_param(attrs["foreign_amount"])
      purchase_exchange_rate = decimal_from_param(attrs["purchase_exchange_rate"])
      sale_exchange_rate = decimal_from_param(attrs["sale_exchange_rate"])

      attrs =
        attrs
        |> Map.put("organization_id", organization.id)
        |> Map.put("currency_id", bank_account.currency_id)
        |> Map.put(
          "result_amount",
          exchange_difference_result(foreign_amount, purchase_exchange_rate, sale_exchange_rate)
        )

      %ExchangeDifference{}
      |> ExchangeDifference.changeset(attrs)
      |> Repo.insert()
    else
      nil -> {:error, :invalid_bank_account}
      {:error, reason} -> {:error, reason}
    end
  end

  def movement_type_options do
    [
      {"Depósito o transferencia recibida", "deposit_or_transfer_received"},
      {"Cheque o transferencia emitida", "check_or_transfer_issued"},
      {"Nota de crédito", "credit_note"},
      {"Nota de débito", "debit_note"}
    ]
  end

  def default_exchange_rate_for_bank_account(%BankAccount{} = bank_account) do
    bank_account
    |> Repo.preload(:currency)
    |> Map.fetch!(:currency)
    |> default_exchange_rate_for_currency()
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

  def movement_label("deposit_or_transfer_received"), do: "Depósito / transferencia recibida"
  def movement_label("check_or_transfer_issued"), do: "Cheque / transferencia emitida"
  def movement_label("credit_note"), do: "Nota de crédito"
  def movement_label("debit_note"), do: "Nota de débito"
  def movement_label(type), do: type

  def signed_amount_usd(%Transaction{} = transaction) do
    if incoming?(transaction.movement_type) do
      transaction.amount_usd
    else
      Decimal.mult(transaction.amount_usd, Decimal.new("-1"))
    end
  end

  def signed_amount(%Transaction{} = transaction) do
    if incoming?(transaction.movement_type) do
      transaction.amount
    else
      Decimal.mult(transaction.amount, Decimal.new("-1"))
    end
  end

  def display_amount(amount_usd, currency_settings) do
    currency = currency_settings.organization.base_currency

    amount =
      if currency.code == Currencies.storage_currency_code() do
        amount_usd
      else
        rate = Map.fetch!(currency_settings.latest_rates, currency.id)
        Decimal.mult(amount_usd, rate.rate)
      end

    "#{currency.symbol} #{Decimal.to_string(Decimal.round(amount, currency.decimal_places), :normal)}"
  end

  def display_native_amount(amount, %Currency{} = currency) do
    "#{currency.symbol} #{Decimal.to_string(Decimal.round(amount, currency.decimal_places), :normal)}"
  end

  def adjusted_bank_major_balance(row) do
    row.bank_balance
    |> Decimal.add(row.credit_notes)
    |> Decimal.sub(row.debit_notes)
    |> Decimal.add(row.exchange_difference_result)
  end

  def exchange_difference_result(foreign_amount, purchase_exchange_rate, sale_exchange_rate) do
    foreign_amount
    |> Decimal.mult(sale_exchange_rate)
    |> Decimal.sub(Decimal.mult(foreign_amount, purchase_exchange_rate))
  end

  defp bank_account_balances(bank_accounts) do
    Map.new(bank_accounts, fn bank_account ->
      balance =
        Transaction
        |> where([transaction], transaction.bank_account_id == ^bank_account.id)
        |> Repo.all()
        |> Enum.reduce(Decimal.new("0"), fn transaction, acc ->
          Decimal.add(acc, signed_amount_usd(transaction))
        end)

      {bank_account.id, balance}
    end)
  end

  defp get_bank_account_for_organization(id, organization) do
    BankAccount
    |> where([bank_account], bank_account.id == ^id)
    |> where([bank_account], bank_account.organization_id == ^organization.id)
    |> preload(:currency)
    |> Repo.one()
  end

  defp bank_account_native_balances(bank_accounts) do
    Map.new(bank_accounts, fn bank_account ->
      balance =
        Transaction
        |> where([transaction], transaction.bank_account_id == ^bank_account.id)
        |> Repo.all()
        |> Enum.reduce(Decimal.new("0"), fn transaction, acc ->
          Decimal.add(acc, signed_amount(transaction))
        end)

      {bank_account.id, balance}
    end)
  end

  defp bank_major_rows(bank_accounts, exchange_differences) do
    Enum.map(bank_accounts, fn bank_account ->
      transactions =
        Transaction
        |> where([transaction], transaction.bank_account_id == ^bank_account.id)
        |> Repo.all()

      exchange_difference_result =
        exchange_differences
        |> Enum.filter(&(&1.bank_account_id == bank_account.id))
        |> Enum.reduce(Decimal.new("0"), fn exchange_difference, acc ->
          Decimal.add(acc, exchange_difference.result_amount)
        end)

      %{
        bank_account: bank_account,
        bank_balance:
          transactions
          |> Enum.filter(
            &(&1.movement_type in ["deposit_or_transfer_received", "check_or_transfer_issued"])
          )
          |> Enum.reduce(Decimal.new("0"), fn transaction, acc ->
            Decimal.add(acc, signed_amount(transaction))
          end),
        credit_notes: sum_transaction_amounts(transactions, "credit_note"),
        debit_notes: sum_transaction_amounts(transactions, "debit_note"),
        exchange_difference_result: exchange_difference_result
      }
    end)
  end

  defp sum_transaction_amounts(transactions, movement_type) do
    transactions
    |> Enum.filter(&(&1.movement_type == movement_type))
    |> Enum.reduce(Decimal.new("0"), fn transaction, acc ->
      Decimal.add(acc, transaction.amount)
    end)
  end

  defp total_balance_usd(bank_accounts) do
    bank_accounts
    |> bank_account_balances()
    |> Map.values()
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
  end

  defp incoming?(movement_type), do: movement_type in @incoming_types

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
  defp decimal_from_param(value) when is_integer(value), do: Decimal.new(value)
  defp decimal_from_param(value) when is_binary(value), do: Decimal.new(value)

  defp date_from_param(%Date{} = value), do: value
  defp date_from_param(value) when is_binary(value), do: Date.from_iso8601!(value)
end
