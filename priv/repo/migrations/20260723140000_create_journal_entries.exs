defmodule Sipaex.Repo.Migrations.CreateJournalEntries do
  use Ecto.Migration

  def change do
    create table(:journal_entries, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :period_id,
          references(:accounting_periods, type: :uuid, on_delete: :restrict),
          null: false

      add :entry_date, :date, null: false
      add :entry_type, :string, null: false
      add :status, :string, null: false, default: "posted"
      add :source_type, :string
      add :source_id, :uuid
      add :description, :string, null: false
      add :posted_at, :utc_datetime

      add :posted_by_user_id,
          references(:users, type: :uuid, on_delete: :nilify_all)

      add :reversed_entry_id,
          references(:journal_entries, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:journal_entries, [:organization_id, :entry_date])
    create index(:journal_entries, [:organization_id, :period_id])
    create index(:journal_entries, [:organization_id, :source_type, :source_id])
    create index(:journal_entries, [:reversed_entry_id])

    create unique_index(:journal_entries, [:id, :organization_id],
             name: :journal_entries_id_organization_id_index
           )

    create unique_index(:journal_entries, [:organization_id, :source_type, :source_id],
             name: :journal_entries_unique_source_index,
             where: "source_type IS NOT NULL AND source_id IS NOT NULL"
           )

    create constraint(:journal_entries, :journal_entries_type_check,
             check: "entry_type IN ('operational', 'adjustment', 'closing', 'reversal')"
           )

    create constraint(:journal_entries, :journal_entries_status_check,
             check: "status IN ('draft', 'posted', 'reversed')"
           )

    execute("""
    ALTER TABLE journal_entries
    ADD CONSTRAINT journal_entries_period_organization_fk
    FOREIGN KEY (period_id, organization_id)
    REFERENCES accounting_periods (id, organization_id)
    """)

    create table(:journal_lines, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :journal_entry_id,
          references(:journal_entries, type: :uuid, on_delete: :delete_all),
          null: false

      add :line_no, :integer, null: false
      add :account_code, :string, null: false
      add :account_name, :string, null: false
      add :description, :string
      add :debit_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :credit_usd, :decimal, precision: 20, scale: 10, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:journal_lines, [:organization_id, :account_code])
    create index(:journal_lines, [:journal_entry_id])
    create unique_index(:journal_lines, [:journal_entry_id, :line_no])

    create constraint(:journal_lines, :journal_lines_amount_direction_check,
             check:
               "debit_usd >= 0 AND credit_usd >= 0 AND (debit_usd > 0 OR credit_usd > 0) AND NOT (debit_usd > 0 AND credit_usd > 0)"
           )

    execute("""
    ALTER TABLE journal_lines
    ADD CONSTRAINT journal_lines_entry_organization_fk
    FOREIGN KEY (journal_entry_id, organization_id)
    REFERENCES journal_entries (id, organization_id)
    """)
  end
end
