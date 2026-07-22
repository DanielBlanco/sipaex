defmodule Sipaex.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :name, :string
    field :email, :string
    field :password_hash, :string
    field :role, :string, default: "admin"
    field :activated_at, :utc_datetime

    belongs_to :organization, Sipaex.Organizations.Organization

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :name,
      :email,
      :password_hash,
      :role,
      :organization_id,
      :activated_at
    ])
    |> validate_required([:username, :name, :email, :password_hash, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end
end
