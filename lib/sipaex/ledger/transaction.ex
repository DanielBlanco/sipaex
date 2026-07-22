defmodule Sipaex.Ledger.Transaction do
  use Ecto.Schema

  import Ecto.Changeset

  @movement_types ~w(
    deposit_or_transfer_received
    check_or_transfer_issued
    credit_note
    debit_note
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ledger_transactions" do
    field :movement_type, :string
    field :transaction_date, :date
    field :amount, :decimal
    field :exchange_rate, :decimal
    field :amount_usd, :decimal
    field :voucher, :string
    field :concept, :string

    belongs_to :bank_account, Sipaex.Ledger.BankAccount
    belongs_to :currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def movement_types, do: @movement_types

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :bank_account_id,
      :currency_id,
      :movement_type,
      :transaction_date,
      :amount,
      :exchange_rate,
      :amount_usd,
      :voucher,
      :concept
    ])
    |> validate_required([
      :bank_account_id,
      :currency_id,
      :movement_type,
      :transaction_date,
      :amount,
      :exchange_rate,
      :amount_usd,
      :concept
    ])
    |> validate_inclusion(:movement_type, @movement_types)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:exchange_rate, greater_than: 0)
    |> validate_number(:amount_usd, greater_than: 0)
  end
end
