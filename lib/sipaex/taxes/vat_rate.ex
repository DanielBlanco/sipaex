defmodule Sipaex.Taxes.VatRate do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "vat_rates" do
    field :country_code, :string
    field :name, :string
    field :rate, :decimal
    field :description, :string
    field :active, :boolean, default: true

    belongs_to :organization, Sipaex.Organizations.Organization

    timestamps(type: :utc_datetime)
  end

  def changeset(vat_rate, attrs) do
    vat_rate
    |> cast(attrs, [:organization_id, :country_code, :name, :rate, :description, :active])
    |> validate_required([:organization_id, :country_code, :name, :rate])
    |> update_change(:country_code, &String.upcase/1)
    |> validate_length(:country_code, is: 2)
    |> validate_number(:rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> unique_constraint([:organization_id, :country_code, :rate, :name])
  end
end
