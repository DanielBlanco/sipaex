defmodule Sipaex.Repo.Migrations.CreatePettyCashTransactions do
  use Ecto.Migration

  def change do
    create table(:petty_cash_transactions, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id,
          references(:common_currencies, type: :uuid, on_delete: :restrict),
          null: false

      add :details, :string, null: false
      add :amount, :decimal, precision: 18, scale: 2, null: false
      add :exchange_rate, :decimal, precision: 18, scale: 8, null: false
      add :amount_usd, :decimal, precision: 18, scale: 2, null: false
      add :transaction_type, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:petty_cash_transactions, [:organization_id])
    create index(:petty_cash_transactions, [:currency_id])
    create index(:petty_cash_transactions, [:transaction_type])
  end
end
