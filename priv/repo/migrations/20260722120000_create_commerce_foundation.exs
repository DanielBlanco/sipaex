defmodule Sipaex.Repo.Migrations.CreateCommerceFoundation do
  use Ecto.Migration

  def change do
    create table(:commerce_parties, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :party_type, :string, null: false
      add :name, :string, null: false
      add :identification, :string
      add :email, :string
      add :phone, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:commerce_parties, [:organization_id])
    create index(:commerce_parties, [:party_type])
    create unique_index(:commerce_parties, [:organization_id, :party_type, :identification])

    create table(:commerce_entries, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :party_id, references(:commerce_parties, type: :uuid, on_delete: :delete_all),
        null: false

      add :currency_id, references(:common_currencies, type: :uuid, on_delete: :restrict),
        null: false

      add :vat_rate_id, references(:vat_rates, type: :uuid, on_delete: :restrict), null: false

      add :entry_type, :string, null: false
      add :entry_date, :date, null: false
      add :document_number, :string
      add :exempt_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :taxable_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :vat_rate, :decimal, precision: 8, scale: 4, null: false
      add :vat_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :total_usd, :decimal, precision: 20, scale: 10, null: false
      add :payment_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :balance_usd, :decimal, precision: 20, scale: 10, null: false
      add :exchange_rate, :decimal, precision: 20, scale: 10, null: false
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:commerce_entries, [:party_id])
    create index(:commerce_entries, [:entry_type])
    create index(:commerce_entries, [:entry_date])
  end
end
