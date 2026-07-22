defmodule Sipaex.Repo.Migrations.CreateLedgerFoundation do
  use Ecto.Migration

  def change do
    create table(:ledger_bank_accounts, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id,
          references(:common_currencies, type: :uuid, on_delete: :restrict),
          null: false

      add :name, :string, null: false
      add :current_account_number, :string
      add :customer_account_number, :string
      add :iban, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:ledger_bank_accounts, [:organization_id])
    create index(:ledger_bank_accounts, [:currency_id])
    create unique_index(:ledger_bank_accounts, [:organization_id, :iban])

    create table(:ledger_transactions, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :bank_account_id,
          references(:ledger_bank_accounts, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id,
          references(:common_currencies, type: :uuid, on_delete: :restrict),
          null: false

      add :movement_type, :string, null: false
      add :transaction_date, :date, null: false
      add :amount, :decimal, precision: 18, scale: 2, null: false
      add :exchange_rate, :decimal, precision: 18, scale: 8, null: false
      add :amount_usd, :decimal, precision: 18, scale: 2, null: false
      add :voucher, :string
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ledger_transactions, [:bank_account_id])
    create index(:ledger_transactions, [:currency_id])
    create index(:ledger_transactions, [:movement_type])
    create index(:ledger_transactions, [:transaction_date])
  end
end
