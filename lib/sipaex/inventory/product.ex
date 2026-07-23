defmodule Sipaex.Inventory.Product do
  use Ecto.Schema

  import Ecto.Changeset

  @product_types ~w(raw_material finished_good resale_good service supply packaging)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :code, :string
    field :name, :string
    field :product_type, :string
    field :unit, :string, default: "unidad"
    field :description, :string
    field :active, :boolean, default: true

    belongs_to :organization, Sipaex.Organizations.Organization

    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :organization_id,
      :code,
      :name,
      :product_type,
      :unit,
      :description,
      :active
    ])
    |> update_change(:code, &normalize_code/1)
    |> validate_required([:organization_id, :code, :name, :product_type, :unit])
    |> validate_inclusion(:product_type, @product_types)
    |> unique_constraint([:organization_id, :code])
  end

  def product_types, do: @product_types

  defp normalize_code(nil), do: nil
  defp normalize_code(code), do: code |> String.trim() |> String.upcase()
end
