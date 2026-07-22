defmodule Sipaex.Dividends.Beneficiary do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dividend_beneficiaries" do
    field :name, :string
    field :identification, :string
    field :email, :string
    field :phone, :string
    field :address, :string
    field :active, :boolean, default: true

    belongs_to :organization, Sipaex.Organizations.Organization
    has_many :entries, Sipaex.Dividends.Entry
    has_many :capital_entries, Sipaex.Dividends.CapitalEntry

    timestamps(type: :utc_datetime)
  end

  def changeset(beneficiary, attrs) do
    beneficiary
    |> cast(attrs, [:organization_id, :name, :identification, :email, :phone, :address, :active])
    |> validate_required([:organization_id, :name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "debe tener formato de correo")
  end
end
