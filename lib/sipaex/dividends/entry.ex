defmodule Sipaex.Dividends.Entry do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dividend_entries" do
    field :entry_date, :date
    field :declaration_amount_usd, :decimal
    field :total_share_capital_usd, :decimal
    field :shareholder_capital_usd, :decimal
    field :participation_percent, :decimal
    field :shareholder_dividend_usd, :decimal
    field :payment_usd, :decimal
    field :payable_usd, :decimal
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
      :declaration_amount_usd,
      :total_share_capital_usd,
      :shareholder_capital_usd,
      :participation_percent,
      :shareholder_dividend_usd,
      :payment_usd,
      :payable_usd,
      :voucher,
      :concept
    ])
    |> validate_required([
      :beneficiary_id,
      :entry_date,
      :declaration_amount_usd,
      :total_share_capital_usd,
      :shareholder_capital_usd,
      :participation_percent,
      :shareholder_dividend_usd,
      :payment_usd,
      :payable_usd,
      :concept
    ])
    |> validate_number(:declaration_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:total_share_capital_usd, greater_than: 0)
    |> validate_number(:shareholder_capital_usd, greater_than_or_equal_to: 0)
    |> validate_number(:participation_percent, greater_than_or_equal_to: 0)
    |> validate_number(:shareholder_dividend_usd, greater_than_or_equal_to: 0)
    |> validate_number(:payment_usd, greater_than_or_equal_to: 0)
  end
end
