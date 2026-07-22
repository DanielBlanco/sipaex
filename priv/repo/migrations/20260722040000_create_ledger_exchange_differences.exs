defmodule Sipaex.Repo.Migrations.CreateLedgerExchangeDifferences do
  use Ecto.Migration

  def change do
    create table(:ledger_exchange_differences, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :bank_account_id,
          references(:ledger_bank_accounts, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id,
          references(:common_currencies, type: :uuid, on_delete: :restrict),
          null: false

      add :transaction_date, :date, null: false
      add :foreign_amount, :decimal, precision: 18, scale: 2, null: false
      add :purchase_exchange_rate, :decimal, precision: 18, scale: 8, null: false
      add :sale_exchange_rate, :decimal, precision: 18, scale: 8, null: false
      add :result_amount, :decimal, precision: 18, scale: 2, null: false
      add :voucher, :string
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ledger_exchange_differences, [:bank_account_id])
    create index(:ledger_exchange_differences, [:currency_id])
    create index(:ledger_exchange_differences, [:transaction_date])
  end
end
