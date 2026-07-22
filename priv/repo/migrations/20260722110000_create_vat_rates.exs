defmodule Sipaex.Repo.Migrations.CreateVatRates do
  use Ecto.Migration

  def change do
    create table(:vat_rates, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :country_code, :string, null: false
      add :name, :string, null: false
      add :rate, :decimal, precision: 8, scale: 4, null: false
      add :description, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:vat_rates, [:organization_id])
    create index(:vat_rates, [:country_code])
    create unique_index(:vat_rates, [:organization_id, :country_code, :rate, :name])
  end
end
