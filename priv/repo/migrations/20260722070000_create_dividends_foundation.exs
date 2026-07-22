defmodule Sipaex.Repo.Migrations.CreateDividendsFoundation do
  use Ecto.Migration

  def change do
    create table(:dividend_beneficiaries, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :identification, :string
      add :email, :string
      add :phone, :string
      add :address, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:dividend_beneficiaries, [:organization_id])
    create unique_index(:dividend_beneficiaries, [:organization_id, :identification])

    create table(:dividend_entries, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :beneficiary_id,
          references(:dividend_beneficiaries, type: :uuid, on_delete: :delete_all),
          null: false

      add :entry_date, :date, null: false
      add :declaration_amount_usd, :decimal, precision: 20, scale: 10, null: false
      add :total_share_capital_usd, :decimal, precision: 20, scale: 10, null: false
      add :shareholder_capital_usd, :decimal, precision: 20, scale: 10, null: false
      add :participation_percent, :decimal, precision: 18, scale: 8, null: false
      add :shareholder_dividend_usd, :decimal, precision: 20, scale: 10, null: false
      add :payment_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :payable_usd, :decimal, precision: 20, scale: 10, null: false
      add :voucher, :string
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:dividend_entries, [:beneficiary_id])
    create index(:dividend_entries, [:entry_date])
  end
end
