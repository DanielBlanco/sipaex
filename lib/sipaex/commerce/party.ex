defmodule Sipaex.Commerce.Party do
  use Ecto.Schema

  import Ecto.Changeset

  @party_types ~w(purchase sale)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "commerce_parties" do
    field :party_type, :string
    field :name, :string
    field :identification, :string
    field :email, :string
    field :phone, :string
    field :active, :boolean, default: true

    belongs_to :organization, Sipaex.Organizations.Organization
    has_many :entries, Sipaex.Commerce.Entry

    timestamps(type: :utc_datetime)
  end

  def changeset(party, attrs) do
    party
    |> cast(attrs, [
      :organization_id,
      :party_type,
      :name,
      :identification,
      :email,
      :phone,
      :active
    ])
    |> validate_required([:organization_id, :party_type, :name])
    |> validate_inclusion(:party_type, @party_types)
    |> unique_constraint([:organization_id, :party_type, :identification])
  end
end
