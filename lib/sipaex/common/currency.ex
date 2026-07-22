defmodule Sipaex.Common.Currency do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "common_currencies" do
    field :code, :string
    field :name, :string
    field :symbol, :string
    field :decimal_places, :integer
    field :activated_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(currency, attrs) do
    currency
    |> cast(attrs, [:code, :name, :symbol, :decimal_places, :activated_at])
    |> validate_required([:code, :name, :symbol, :decimal_places])
    |> unique_constraint(:code)
  end
end
