defmodule Sipaex.Repo.Migrations.IncreaseCanonicalUsdPrecision do
  use Ecto.Migration

  def up do
    alter table(:ledger_transactions) do
      modify :amount_usd, :decimal, precision: 20, scale: 10, null: false
    end

    alter table(:petty_cash_transactions) do
      modify :amount_usd, :decimal, precision: 20, scale: 10, null: false
    end

    execute "UPDATE ledger_transactions SET amount_usd = amount / exchange_rate"
    execute "UPDATE petty_cash_transactions SET amount_usd = amount / exchange_rate"
  end

  def down do
    alter table(:ledger_transactions) do
      modify :amount_usd, :decimal, precision: 18, scale: 2, null: false
    end

    alter table(:petty_cash_transactions) do
      modify :amount_usd, :decimal, precision: 18, scale: 2, null: false
    end
  end
end
