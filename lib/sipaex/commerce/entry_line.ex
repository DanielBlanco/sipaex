defmodule Sipaex.Commerce.EntryLine do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "commerce_entry_lines" do
    field :description, :string
    field :quantity, :decimal
    field :unit_price, :decimal
    field :vat_rate, :decimal
    field :exempt_amount_usd, :decimal
    field :taxable_amount_usd, :decimal
    field :vat_amount_usd, :decimal
    field :total_usd, :decimal

    belongs_to :entry, Sipaex.Commerce.Entry
    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :product, Sipaex.Inventory.Product
    belongs_to :vat_rate_config, Sipaex.Taxes.VatRate, foreign_key: :vat_rate_id

    timestamps(type: :utc_datetime)
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [
      :entry_id,
      :organization_id,
      :product_id,
      :vat_rate_id,
      :description,
      :quantity,
      :unit_price,
      :vat_rate,
      :exempt_amount_usd,
      :taxable_amount_usd,
      :vat_amount_usd,
      :total_usd
    ])
    |> validate_required([
      :entry_id,
      :organization_id,
      :vat_rate_id,
      :description,
      :quantity,
      :unit_price,
      :vat_rate,
      :exempt_amount_usd,
      :taxable_amount_usd,
      :vat_amount_usd,
      :total_usd
    ])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> validate_number(:vat_rate, greater_than_or_equal_to: 0)
    |> validate_number(:exempt_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:taxable_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:vat_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:total_usd, greater_than_or_equal_to: 0)
  end
end
