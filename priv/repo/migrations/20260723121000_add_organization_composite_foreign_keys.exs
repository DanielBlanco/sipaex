defmodule Sipaex.Repo.Migrations.AddOrganizationCompositeForeignKeys do
  use Ecto.Migration

  def up do
    create unique_index(:ledger_bank_accounts, [:id, :organization_id],
             name: :ledger_bank_accounts_id_organization_id_index
           )

    create unique_index(:expense_providers, [:id, :organization_id],
             name: :expense_providers_id_organization_id_index
           )

    create unique_index(:dividend_beneficiaries, [:id, :organization_id],
             name: :dividend_beneficiaries_id_organization_id_index
           )

    create unique_index(:commerce_parties, [:id, :organization_id],
             name: :commerce_parties_id_organization_id_index
           )

    create unique_index(:commerce_entries, [:id, :organization_id],
             name: :commerce_entries_id_organization_id_index
           )

    create unique_index(:vat_rates, [:id, :organization_id],
             name: :vat_rates_id_organization_id_index
           )

    create unique_index(:products, [:id, :organization_id],
             name: :products_id_organization_id_index
           )

    add_composite_fk(
      :ledger_transactions,
      :ledger_transactions_bank_account_organization_fk,
      [:bank_account_id, :organization_id],
      :ledger_bank_accounts,
      [:id, :organization_id]
    )

    add_composite_fk(
      :ledger_transactions,
      :ledger_transactions_currency_organization_fk,
      [:organization_id, :currency_id],
      :organization_currencies,
      [:organization_id, :currency_id]
    )

    add_composite_fk(
      :ledger_exchange_differences,
      :ledger_exchange_differences_bank_account_organization_fk,
      [:bank_account_id, :organization_id],
      :ledger_bank_accounts,
      [:id, :organization_id]
    )

    add_composite_fk(
      :ledger_exchange_differences,
      :ledger_exchange_differences_currency_organization_fk,
      [:organization_id, :currency_id],
      :organization_currencies,
      [:organization_id, :currency_id]
    )

    add_composite_fk(
      :expense_entries,
      :expense_entries_provider_organization_fk,
      [:provider_id, :organization_id],
      :expense_providers,
      [:id, :organization_id]
    )

    add_composite_fk(
      :expense_entries,
      :expense_entries_currency_organization_fk,
      [:organization_id, :currency_id],
      :organization_currencies,
      [:organization_id, :currency_id]
    )

    add_composite_fk(
      :financial_expense_entries,
      :financial_expense_entries_provider_organization_fk,
      [:provider_id, :organization_id],
      :expense_providers,
      [:id, :organization_id]
    )

    add_composite_fk(
      :financial_expense_entries,
      :financial_expense_entries_currency_organization_fk,
      [:organization_id, :currency_id],
      :organization_currencies,
      [:organization_id, :currency_id]
    )

    add_composite_fk(
      :dividend_entries,
      :dividend_entries_beneficiary_organization_fk,
      [:beneficiary_id, :organization_id],
      :dividend_beneficiaries,
      [:id, :organization_id]
    )

    add_composite_fk(
      :shareholder_capital_entries,
      :shareholder_capital_entries_beneficiary_organization_fk,
      [:beneficiary_id, :organization_id],
      :dividend_beneficiaries,
      [:id, :organization_id]
    )

    add_composite_fk(
      :commerce_entries,
      :commerce_entries_party_organization_fk,
      [:party_id, :organization_id],
      :commerce_parties,
      [:id, :organization_id]
    )

    add_composite_fk(
      :commerce_entries,
      :commerce_entries_currency_organization_fk,
      [:organization_id, :currency_id],
      :organization_currencies,
      [:organization_id, :currency_id]
    )

    add_composite_fk(
      :commerce_entries,
      :commerce_entries_vat_rate_organization_fk,
      [:vat_rate_id, :organization_id],
      :vat_rates,
      [:id, :organization_id]
    )

    add_composite_fk(
      :commerce_entry_lines,
      :commerce_entry_lines_entry_organization_fk,
      [:entry_id, :organization_id],
      :commerce_entries,
      [:id, :organization_id]
    )

    add_composite_fk(
      :commerce_entry_lines,
      :commerce_entry_lines_product_organization_fk,
      [:product_id, :organization_id],
      :products,
      [:id, :organization_id]
    )

    add_composite_fk(
      :commerce_entry_lines,
      :commerce_entry_lines_vat_rate_organization_fk,
      [:vat_rate_id, :organization_id],
      :vat_rates,
      [:id, :organization_id]
    )
  end

  def down do
    drop_constraint(:commerce_entry_lines, :commerce_entry_lines_vat_rate_organization_fk)
    drop_constraint(:commerce_entry_lines, :commerce_entry_lines_product_organization_fk)
    drop_constraint(:commerce_entry_lines, :commerce_entry_lines_entry_organization_fk)
    drop_constraint(:commerce_entries, :commerce_entries_vat_rate_organization_fk)
    drop_constraint(:commerce_entries, :commerce_entries_currency_organization_fk)
    drop_constraint(:commerce_entries, :commerce_entries_party_organization_fk)

    drop_constraint(
      :shareholder_capital_entries,
      :shareholder_capital_entries_beneficiary_organization_fk
    )

    drop_constraint(:dividend_entries, :dividend_entries_beneficiary_organization_fk)

    drop_constraint(
      :financial_expense_entries,
      :financial_expense_entries_currency_organization_fk
    )

    drop_constraint(
      :financial_expense_entries,
      :financial_expense_entries_provider_organization_fk
    )

    drop_constraint(:expense_entries, :expense_entries_currency_organization_fk)
    drop_constraint(:expense_entries, :expense_entries_provider_organization_fk)

    drop_constraint(
      :ledger_exchange_differences,
      :ledger_exchange_differences_currency_organization_fk
    )

    drop_constraint(
      :ledger_exchange_differences,
      :ledger_exchange_differences_bank_account_organization_fk
    )

    drop_constraint(:ledger_transactions, :ledger_transactions_currency_organization_fk)
    drop_constraint(:ledger_transactions, :ledger_transactions_bank_account_organization_fk)

    drop unique_index(:products, [:id, :organization_id],
           name: :products_id_organization_id_index
         )

    drop unique_index(:vat_rates, [:id, :organization_id],
           name: :vat_rates_id_organization_id_index
         )

    drop unique_index(:commerce_entries, [:id, :organization_id],
           name: :commerce_entries_id_organization_id_index
         )

    drop unique_index(:commerce_parties, [:id, :organization_id],
           name: :commerce_parties_id_organization_id_index
         )

    drop unique_index(:dividend_beneficiaries, [:id, :organization_id],
           name: :dividend_beneficiaries_id_organization_id_index
         )

    drop unique_index(:expense_providers, [:id, :organization_id],
           name: :expense_providers_id_organization_id_index
         )

    drop unique_index(:ledger_bank_accounts, [:id, :organization_id],
           name: :ledger_bank_accounts_id_organization_id_index
         )
  end

  defp add_composite_fk(table, name, columns, reference_table, reference_columns) do
    execute("""
    ALTER TABLE #{table}
    ADD CONSTRAINT #{name}
    FOREIGN KEY (#{Enum.join(columns, ", ")})
    REFERENCES #{reference_table} (#{Enum.join(reference_columns, ", ")})
    """)
  end

  defp drop_constraint(table, name) do
    execute("ALTER TABLE #{table} DROP CONSTRAINT #{name}")
  end
end
