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
    |> update_change(:code, &String.upcase/1)
    |> validate_format(:code, ~r/^[A-Z]{3}$/)
    |> validate_number(:decimal_places, greater_than_or_equal_to: 0, less_than_or_equal_to: 8)
    |> unique_constraint(:code)
  end
end
