defmodule Sipaex.Repo.Migrations.CreateTaxesFoundation do
  use Ecto.Migration

  def change do
    create table(:income_tax_entries, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id, references(:common_currencies, type: :uuid, on_delete: :restrict),
        null: false

      add :entry_date, :date, null: false
      add :fiscal_period, :string, null: false
      add :tax_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :payment_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :payable_usd, :decimal, precision: 20, scale: 10, null: false
      add :exchange_rate, :decimal, precision: 20, scale: 10, null: false
      add :voucher, :string
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:income_tax_entries, [:organization_id])
    create index(:income_tax_entries, [:entry_date])

    create table(:vat_periods, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id, references(:common_currencies, type: :uuid, on_delete: :restrict),
        null: false

      add :period_month, :integer, null: false
      add :period_year, :integer, null: false
      add :debit_sales_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :credit_purchases_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :credit_expenses_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :net_vat_usd, :decimal, precision: 20, scale: 10, null: false
      add :payment_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :payable_usd, :decimal, precision: 20, scale: 10, null: false
      add :exchange_rate, :decimal, precision: 20, scale: 10, null: false
      add :voucher, :string
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:vat_periods, [:organization_id])
    create unique_index(:vat_periods, [:organization_id, :period_year, :period_month])
  end
end
