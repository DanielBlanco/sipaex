defmodule Sipaex.Repo.Migrations.AddStringEnumCheckConstraints do
  use Ecto.Migration

  def change do
    create constraint(:ledger_transactions, :ledger_transactions_movement_type_check,
             check:
               "movement_type IN ('deposit_or_transfer_received', 'check_or_transfer_issued', 'credit_note', 'debit_note')"
           )

    create constraint(:expense_providers, :expense_providers_category_check,
             check: "category IN ('administrative', 'sales', 'financial')"
           )

    create constraint(:expense_entries, :expense_entries_category_check,
             check: "category IN ('administrative', 'sales')"
           )

    create constraint(:commerce_parties, :commerce_parties_party_type_check,
             check: "party_type IN ('purchase', 'sale')"
           )

    create constraint(:commerce_entries, :commerce_entries_entry_type_check,
             check: "entry_type IN ('purchase', 'sale')"
           )

    create constraint(:products, :products_product_type_check,
             check:
               "product_type IN ('raw_material', 'finished_good', 'resale_good', 'service', 'supply', 'packaging')"
           )

    create constraint(:petty_cash_transactions, :petty_cash_transactions_transaction_type_check,
             check: "transaction_type IN ('deposit', 'withdrawal')"
           )
  end
end
