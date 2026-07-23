defmodule Sipaex.Accounts do
  @moduledoc """
  User account helpers.

  Authentication is intentionally minimal for the spike. Passwords currently
  use the same SHA-256 hash as the seed data; this should be replaced before
  production.
  """

  import Ecto.Query

  alias Sipaex.Accounts.User
  alias Sipaex.Repo

  def authenticate_user(email, password) do
    password_hash = hash_password(password)

    User
    |> where([user], user.email == ^String.downcase(String.trim(email || "")))
    |> where([user], user.password_hash == ^password_hash)
    |> where([user], not is_nil(user.organization_id))
    |> preload(:organization)
    |> Repo.one()
    |> case do
      %User{} = user -> {:ok, user}
      nil -> {:error, :invalid_credentials}
    end
  end

  def get_user_with_organization(id) do
    User
    |> where([user], user.id == ^id)
    |> where([user], not is_nil(user.organization_id))
    |> preload(organization: :base_currency)
    |> Repo.one()
  end

  def hash_password(password) do
    :sha256
    |> :crypto.hash(password || "")
    |> Base.encode16(case: :lower)
  end
end
