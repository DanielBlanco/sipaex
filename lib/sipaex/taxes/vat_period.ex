defmodule Sipaex.Taxes.VatPeriod do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "vat_periods" do
    field :period_month, :integer
    field :period_year, :integer
    field :debit_sales_usd, :decimal
    field :credit_purchases_usd, :decimal
    field :credit_expenses_usd, :decimal
    field :net_vat_usd, :decimal
    field :payment_usd, :decimal
    field :payable_usd, :decimal
    field :exchange_rate, :decimal
    field :voucher, :string
    field :concept, :string

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def changeset(period, attrs) do
    period
    |> cast(attrs, [
      :organization_id,
      :currency_id,
      :period_month,
      :period_year,
      :debit_sales_usd,
      :credit_purchases_usd,
      :credit_expenses_usd,
      :net_vat_usd,
      :payment_usd,
      :payable_usd,
      :exchange_rate,
      :voucher,
      :concept
    ])
    |> validate_required([
      :organization_id,
      :currency_id,
      :period_month,
      :period_year,
      :debit_sales_usd,
      :credit_purchases_usd,
      :credit_expenses_usd,
      :net_vat_usd,
      :payment_usd,
      :payable_usd,
      :exchange_rate,
      :concept
    ])
    |> validate_number(:period_month,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 12
    )
    |> validate_number(:period_year, greater_than_or_equal_to: 1900)
    |> validate_number(:debit_sales_usd, greater_than_or_equal_to: 0)
    |> validate_number(:credit_purchases_usd, greater_than_or_equal_to: 0)
    |> validate_number(:credit_expenses_usd, greater_than_or_equal_to: 0)
    |> validate_number(:payment_usd, greater_than_or_equal_to: 0)
    |> validate_number(:exchange_rate, greater_than: 0)
    |> unique_constraint([:organization_id, :period_year, :period_month])
  end
end
