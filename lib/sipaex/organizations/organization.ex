defmodule Sipaex.Organizations.Organization do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "organizations" do
    field :name, :string
    field :legal_name, :string
    field :tax_id, :string
    field :activated_at, :utc_datetime

    belongs_to :base_currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :legal_name, :tax_id, :base_currency_id, :activated_at])
    |> validate_required([:name, :legal_name, :tax_id, :base_currency_id])
    |> unique_constraint(:tax_id)
  end
end
