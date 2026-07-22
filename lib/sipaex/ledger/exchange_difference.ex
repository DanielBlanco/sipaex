defmodule Sipaex.Ledger.ExchangeDifference do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ledger_exchange_differences" do
    field :transaction_date, :date
    field :foreign_amount, :decimal
    field :purchase_exchange_rate, :decimal
    field :sale_exchange_rate, :decimal
    field :result_amount, :decimal
    field :voucher, :string
    field :concept, :string

    belongs_to :bank_account, Sipaex.Ledger.BankAccount
    belongs_to :currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def changeset(exchange_difference, attrs) do
    exchange_difference
    |> cast(attrs, [
      :bank_account_id,
      :currency_id,
      :transaction_date,
      :foreign_amount,
      :purchase_exchange_rate,
      :sale_exchange_rate,
      :result_amount,
      :voucher,
      :concept
    ])
    |> validate_required([
      :bank_account_id,
      :currency_id,
      :transaction_date,
      :foreign_amount,
      :purchase_exchange_rate,
      :sale_exchange_rate,
      :result_amount,
      :concept
    ])
    |> validate_number(:foreign_amount, greater_than: 0)
    |> validate_number(:purchase_exchange_rate, greater_than: 0)
    |> validate_number(:sale_exchange_rate, greater_than: 0)
  end
end
