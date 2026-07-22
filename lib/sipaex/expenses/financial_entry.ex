defmodule Sipaex.Expenses.FinancialEntry do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "financial_expense_entries" do
    field :entry_date, :date
    field :loan_amount_usd, :decimal
    field :principal_payment_usd, :decimal
    field :financial_expense_usd, :decimal
    field :credit_note_usd, :decimal
    field :debit_note_usd, :decimal
    field :net_financial_expense_usd, :decimal
    field :financial_expense_payment_usd, :decimal
    field :loan_payable_usd, :decimal
    field :financial_expense_payable_usd, :decimal
    field :exchange_rate, :decimal
    field :voucher, :string
    field :concept, :string

    belongs_to :provider, Sipaex.Expenses.Provider
    belongs_to :currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :provider_id,
      :currency_id,
      :entry_date,
      :loan_amount_usd,
      :principal_payment_usd,
      :financial_expense_usd,
      :credit_note_usd,
      :debit_note_usd,
      :net_financial_expense_usd,
      :financial_expense_payment_usd,
      :loan_payable_usd,
      :financial_expense_payable_usd,
      :exchange_rate,
      :voucher,
      :concept
    ])
    |> validate_required([
      :provider_id,
      :currency_id,
      :entry_date,
      :loan_amount_usd,
      :principal_payment_usd,
      :financial_expense_usd,
      :credit_note_usd,
      :debit_note_usd,
      :net_financial_expense_usd,
      :financial_expense_payment_usd,
      :loan_payable_usd,
      :financial_expense_payable_usd,
      :exchange_rate,
      :concept
    ])
    |> validate_number(:loan_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:principal_payment_usd, greater_than_or_equal_to: 0)
    |> validate_number(:financial_expense_usd, greater_than_or_equal_to: 0)
    |> validate_number(:credit_note_usd, greater_than_or_equal_to: 0)
    |> validate_number(:debit_note_usd, greater_than_or_equal_to: 0)
    |> validate_number(:net_financial_expense_usd, greater_than_or_equal_to: 0)
    |> validate_number(:financial_expense_payment_usd, greater_than_or_equal_to: 0)
    |> validate_number(:loan_payable_usd, greater_than_or_equal_to: 0)
    |> validate_number(:financial_expense_payable_usd, greater_than_or_equal_to: 0)
    |> validate_number(:exchange_rate, greater_than: 0)
  end
end
