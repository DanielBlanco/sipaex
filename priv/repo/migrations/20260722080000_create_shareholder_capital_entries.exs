defmodule Sipaex.Repo.Migrations.CreateShareholderCapitalEntries do
  use Ecto.Migration

  def change do
    create table(:shareholder_capital_entries, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :beneficiary_id,
          references(:dividend_beneficiaries, type: :uuid, on_delete: :delete_all),
          null: false

      add :entry_date, :date, null: false
      add :share_type, :string, null: false
      add :share_value_usd, :decimal, precision: 20, scale: 10, null: false
      add :quantity, :integer, null: false
      add :capital_usd, :decimal, precision: 20, scale: 10, null: false
      add :payment_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :receivable_usd, :decimal, precision: 20, scale: 10, null: false
      add :voucher, :string
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:shareholder_capital_entries, [:beneficiary_id])
    create index(:shareholder_capital_entries, [:entry_date])
  end
end
