defmodule Sipaex.Commerce.Entry do
  use Ecto.Schema

  import Ecto.Changeset

  @entry_types ~w(purchase sale)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "commerce_entries" do
    field :entry_type, :string
    field :entry_date, :date
    field :document_number, :string
    field :exempt_amount_usd, :decimal
    field :taxable_amount_usd, :decimal
    field :vat_rate, :decimal
    field :vat_amount_usd, :decimal
    field :total_usd, :decimal
    field :payment_usd, :decimal
    field :balance_usd, :decimal
    field :exchange_rate, :decimal
    field :concept, :string

    belongs_to :party, Sipaex.Commerce.Party
    belongs_to :currency, Sipaex.Common.Currency
    belongs_to :vat_rate_config, Sipaex.Taxes.VatRate, foreign_key: :vat_rate_id

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :party_id,
      :currency_id,
      :vat_rate_id,
      :entry_type,
      :entry_date,
      :document_number,
      :exempt_amount_usd,
      :taxable_amount_usd,
      :vat_rate,
      :vat_amount_usd,
      :total_usd,
      :payment_usd,
      :balance_usd,
      :exchange_rate,
      :concept
    ])
    |> validate_required([
      :party_id,
      :currency_id,
      :vat_rate_id,
      :entry_type,
      :entry_date,
      :exempt_amount_usd,
      :taxable_amount_usd,
      :vat_rate,
      :vat_amount_usd,
      :total_usd,
      :payment_usd,
      :balance_usd,
      :exchange_rate,
      :concept
    ])
    |> validate_inclusion(:entry_type, @entry_types)
    |> validate_number(:exempt_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:taxable_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:vat_rate, greater_than_or_equal_to: 0)
    |> validate_number(:vat_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:total_usd, greater_than_or_equal_to: 0)
    |> validate_number(:payment_usd, greater_than_or_equal_to: 0)
    |> validate_number(:exchange_rate, greater_than: 0)
  end
end
