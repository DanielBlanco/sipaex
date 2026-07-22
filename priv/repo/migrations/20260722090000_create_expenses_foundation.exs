defmodule Sipaex.Repo.Migrations.CreateExpensesFoundation do
  use Ecto.Migration

  def change do
    create table(:expense_providers, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :category, :string, null: false
      add :name, :string, null: false
      add :identification, :string
      add :email, :string
      add :phone, :string
      add :address, :string
      add :contact, :string
      add :payment_terms_days, :integer
      add :operation_number, :string
      add :loan_concept, :string
      add :interest_rate, :decimal, precision: 12, scale: 8
      add :term_months, :integer
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:expense_providers, [:organization_id])
    create index(:expense_providers, [:category])
    create unique_index(:expense_providers, [:organization_id, :category, :identification])

    create table(:expense_entries, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :provider_id,
          references(:expense_providers, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id, references(:common_currencies, type: :uuid, on_delete: :restrict),
        null: false

      add :category, :string, null: false
      add :entry_date, :date, null: false
      add :invoice_number, :string
      add :exempt_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :taxable_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :tax_rate, :decimal, precision: 8, scale: 4, null: false, default: 0
      add :tax_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :credit_note_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :debit_note_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :total_usd, :decimal, precision: 20, scale: 10, null: false
      add :payment_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :payable_usd, :decimal, precision: 20, scale: 10, null: false
      add :exchange_rate, :decimal, precision: 20, scale: 10, null: false
      add :voucher, :string
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:expense_entries, [:provider_id])
    create index(:expense_entries, [:category])
    create index(:expense_entries, [:entry_date])

    create table(:financial_expense_entries, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :provider_id,
          references(:expense_providers, type: :uuid, on_delete: :delete_all),
          null: false

      add :currency_id, references(:common_currencies, type: :uuid, on_delete: :restrict),
        null: false

      add :entry_date, :date, null: false
      add :loan_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :principal_payment_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :financial_expense_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :credit_note_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :debit_note_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :net_financial_expense_usd, :decimal, precision: 20, scale: 10, null: false

      add :financial_expense_payment_usd, :decimal,
        precision: 20,
        scale: 10,
        null: false,
        default: 0

      add :loan_payable_usd, :decimal, precision: 20, scale: 10, null: false
      add :financial_expense_payable_usd, :decimal, precision: 20, scale: 10, null: false
      add :exchange_rate, :decimal, precision: 20, scale: 10, null: false
      add :voucher, :string
      add :concept, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:financial_expense_entries, [:provider_id])
    create index(:financial_expense_entries, [:entry_date])
  end
end
