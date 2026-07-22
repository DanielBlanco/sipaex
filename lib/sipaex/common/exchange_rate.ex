defmodule Sipaex.Common.ExchangeRate do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "common_exchange_rates" do
    field :rate, :decimal
    field :as_of, :utc_datetime
    field :scope, :string
    field :source, :string

    belongs_to :base_currency, Sipaex.Common.Currency
    belongs_to :quote_currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def changeset(exchange_rate, attrs) do
    exchange_rate
    |> cast(attrs, [:base_currency_id, :quote_currency_id, :rate, :as_of, :scope, :source])
    |> validate_required([:base_currency_id, :quote_currency_id, :rate, :as_of, :scope, :source])
    |> validate_number(:rate, greater_than: 0)
    |> unique_constraint([:base_currency_id, :quote_currency_id, :as_of, :scope])
  end
end
