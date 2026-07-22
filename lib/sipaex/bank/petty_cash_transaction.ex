defmodule Sipaex.Bank.PettyCashTransaction do
  use Ecto.Schema

  import Ecto.Changeset

  @transaction_types ~w(deposit withdrawal)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "petty_cash_transactions" do
    field :details, :string
    field :amount, :decimal
    field :exchange_rate, :decimal
    field :amount_usd, :decimal
    field :transaction_type, :string

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def transaction_types, do: @transaction_types

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :organization_id,
      :currency_id,
      :details,
      :amount,
      :exchange_rate,
      :amount_usd,
      :transaction_type
    ])
    |> validate_required([
      :organization_id,
      :currency_id,
      :details,
      :amount,
      :exchange_rate,
      :amount_usd,
      :transaction_type
    ])
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:exchange_rate, greater_than: 0)
    |> validate_number(:amount_usd, greater_than: 0)
    |> validate_inclusion(:transaction_type, @transaction_types)
  end
end
