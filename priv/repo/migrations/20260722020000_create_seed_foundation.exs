defmodule Sipaex.Repo.Migrations.CreateSeedFoundation do
  use Ecto.Migration

  def change do
    create table(:common_currencies, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :symbol, :string, null: false
      add :decimal_places, :smallint, null: false
      add :activated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:common_currencies, [:code])

    create table(:organizations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :legal_name, :string, null: false
      add :tax_id, :string, null: false

      add :base_currency_id,
          references(:common_currencies, type: :uuid, on_delete: :restrict),
          null: false

      add :activated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:tax_id])
    create index(:organizations, [:base_currency_id])

    create table(:organization_currencies, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id,
          references(:common_currencies, type: :uuid, on_delete: :restrict),
          null: false

      add :base, :boolean, null: false, default: false
      add :activated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organization_currencies, [:organization_id, :currency_id])
    create index(:organization_currencies, [:currency_id])

    create table(:common_exchange_rates, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :base_currency_id,
          references(:common_currencies, type: :uuid, on_delete: :restrict),
          null: false

      add :quote_currency_id,
          references(:common_currencies, type: :uuid, on_delete: :restrict),
          null: false

      add :rate, :decimal, precision: 18, scale: 8, null: false
      add :as_of, :utc_datetime, null: false
      add :scope, :string, null: false
      add :source, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :common_exchange_rates,
             [
               :base_currency_id,
               :quote_currency_id,
               :as_of,
               :scope
             ],
             name: :common_exchange_rates_currency_pair_as_of_scope_index
           )

    create index(:common_exchange_rates, [:quote_currency_id])

    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :username, :string, null: false
      add :name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :role, :string, null: false, default: "admin"

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :nilify_all)

      add :activated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
    create index(:users, [:organization_id])
  end
end
