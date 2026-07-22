defmodule Sipaex.Taxes.IncomeTaxEntry do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "income_tax_entries" do
    field :entry_date, :date
    field :fiscal_period, :string
    field :tax_amount_usd, :decimal
    field :payment_usd, :decimal
    field :payable_usd, :decimal
    field :exchange_rate, :decimal
    field :voucher, :string
    field :concept, :string

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :organization_id,
      :currency_id,
      :entry_date,
      :fiscal_period,
      :tax_amount_usd,
      :payment_usd,
      :payable_usd,
      :exchange_rate,
      :voucher,
      :concept
    ])
    |> validate_required([
      :organization_id,
      :currency_id,
      :entry_date,
      :fiscal_period,
      :tax_amount_usd,
      :payment_usd,
      :payable_usd,
      :exchange_rate,
      :concept
    ])
    |> validate_number(:tax_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:payment_usd, greater_than_or_equal_to: 0)
    |> validate_number(:exchange_rate, greater_than: 0)
  end
end
