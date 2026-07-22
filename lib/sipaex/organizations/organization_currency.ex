defmodule Sipaex.Organizations.OrganizationCurrency do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "organization_currencies" do
    field :base, :boolean, default: false
    field :activated_at, :utc_datetime

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def changeset(organization_currency, attrs) do
    organization_currency
    |> cast(attrs, [:organization_id, :currency_id, :base, :activated_at])
    |> validate_required([:organization_id, :currency_id, :base])
    |> unique_constraint([:organization_id, :currency_id])
  end
end
