defmodule Sipaex.Repo.Migrations.AddOrganizationIdToTransactionTables do
  use Ecto.Migration

  @transaction_tables [
    :ledger_transactions,
    :ledger_exchange_differences,
    :expense_entries,
    :financial_expense_entries,
    :dividend_entries,
    :shareholder_capital_entries,
    :commerce_entries,
    :commerce_entry_lines
  ]

  def up do
    for table <- @transaction_tables do
      alter table(table) do
        add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all)
      end
    end

    execute("""
    UPDATE ledger_transactions AS transaction
    SET organization_id = bank_account.organization_id
    FROM ledger_bank_accounts AS bank_account
    WHERE transaction.bank_account_id = bank_account.id
    """)

    execute("""
    UPDATE ledger_exchange_differences AS exchange_difference
    SET organization_id = bank_account.organization_id
    FROM ledger_bank_accounts AS bank_account
    WHERE exchange_difference.bank_account_id = bank_account.id
    """)

    execute("""
    UPDATE expense_entries AS entry
    SET organization_id = provider.organization_id
    FROM expense_providers AS provider
    WHERE entry.provider_id = provider.id
    """)

    execute("""
    UPDATE financial_expense_entries AS entry
    SET organization_id = provider.organization_id
    FROM expense_providers AS provider
    WHERE entry.provider_id = provider.id
    """)

    execute("""
    UPDATE dividend_entries AS entry
    SET organization_id = beneficiary.organization_id
    FROM dividend_beneficiaries AS beneficiary
    WHERE entry.beneficiary_id = beneficiary.id
    """)

    execute("""
    UPDATE shareholder_capital_entries AS entry
    SET organization_id = beneficiary.organization_id
    FROM dividend_beneficiaries AS beneficiary
    WHERE entry.beneficiary_id = beneficiary.id
    """)

    execute("""
    UPDATE commerce_entries AS entry
    SET organization_id = party.organization_id
    FROM commerce_parties AS party
    WHERE entry.party_id = party.id
    """)

    execute("""
    UPDATE commerce_entry_lines AS line
    SET organization_id = entry.organization_id
    FROM commerce_entries AS entry
    WHERE line.entry_id = entry.id
    """)

    for table <- @transaction_tables do
      alter table(table) do
        modify :organization_id, :uuid, null: false
      end
    end

    create index(:ledger_transactions, [:organization_id, :transaction_date])
    create index(:ledger_transactions, [:organization_id, :movement_type])
    create index(:ledger_exchange_differences, [:organization_id, :transaction_date])
    create index(:expense_entries, [:organization_id, :entry_date])
    create index(:expense_entries, [:organization_id, :category])
    create index(:financial_expense_entries, [:organization_id, :entry_date])
    create index(:dividend_entries, [:organization_id, :entry_date])
    create index(:shareholder_capital_entries, [:organization_id, :entry_date])
    create index(:commerce_entries, [:organization_id, :entry_type, :entry_date])
    create index(:commerce_entries, [:organization_id, :document_number])
    create index(:commerce_entry_lines, [:organization_id])

    create unique_index(:organization_currencies, [:organization_id],
             where: "base",
             name: :organization_currencies_one_base_per_organization_index
           )
  end

  def down do
    drop_if_exists unique_index(:organization_currencies, [:organization_id],
                     name: :organization_currencies_one_base_per_organization_index
                   )

    drop index(:commerce_entry_lines, [:organization_id])
    drop index(:commerce_entries, [:organization_id, :document_number])
    drop index(:commerce_entries, [:organization_id, :entry_type, :entry_date])
    drop index(:shareholder_capital_entries, [:organization_id, :entry_date])
    drop index(:dividend_entries, [:organization_id, :entry_date])
    drop index(:financial_expense_entries, [:organization_id, :entry_date])
    drop index(:expense_entries, [:organization_id, :category])
    drop index(:expense_entries, [:organization_id, :entry_date])
    drop index(:ledger_exchange_differences, [:organization_id, :transaction_date])
    drop index(:ledger_transactions, [:organization_id, :movement_type])
    drop index(:ledger_transactions, [:organization_id, :transaction_date])

    for table <- Enum.reverse(@transaction_tables) do
      alter table(table) do
        remove :organization_id
      end
    end
  end
end
