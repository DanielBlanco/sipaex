defmodule Sipaex.Dividends.CapitalEntry do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "shareholder_capital_entries" do
    field :entry_date, :date
    field :share_type, :string
    field :share_value_usd, :decimal
    field :quantity, :integer
    field :capital_usd, :decimal
    field :payment_usd, :decimal
    field :receivable_usd, :decimal
    field :voucher, :string
    field :concept, :string

    belongs_to :beneficiary, Sipaex.Dividends.Beneficiary

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :beneficiary_id,
      :entry_date,
      :share_type,
      :share_value_usd,
      :quantity,
      :capital_usd,
      :payment_usd,
      :receivable_usd,
      :voucher,
      :concept
    ])
    |> validate_required([
      :beneficiary_id,
      :entry_date,
      :share_type,
      :share_value_usd,
      :quantity,
      :capital_usd,
      :payment_usd,
      :receivable_usd,
      :concept
    ])
    |> validate_number(:share_value_usd, greater_than: 0)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:capital_usd, greater_than: 0)
    |> validate_number(:payment_usd, greater_than_or_equal_to: 0)
  end
end
