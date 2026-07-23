defmodule Sipaex.Repo.Migrations.CreateAccountingPeriods do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS btree_gist", "DROP EXTENSION IF EXISTS btree_gist")

    create table(:accounting_fiscal_years, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :starts_on, :date, null: false
      add :ends_on, :date, null: false
      add :status, :string, null: false, default: "open"

      timestamps(type: :utc_datetime)
    end

    create index(:accounting_fiscal_years, [:organization_id])
    create unique_index(:accounting_fiscal_years, [:organization_id, :name])

    create constraint(:accounting_fiscal_years, :accounting_fiscal_years_valid_date_range,
             check: "starts_on <= ends_on"
           )

    create constraint(:accounting_fiscal_years, :accounting_fiscal_years_status_check,
             check: "status IN ('open', 'closing', 'closed', 'locked')"
           )

    create table(:accounting_periods, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :fiscal_year_id,
          references(:accounting_fiscal_years, type: :uuid, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :period_type, :string, null: false
      add :status, :string, null: false, default: "open"
      add :starts_on, :date, null: false
      add :ends_on, :date, null: false
      add :closed_at, :utc_datetime

      add :closed_by_user_id,
          references(:users, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:accounting_periods, [:organization_id, :starts_on, :ends_on])
    create index(:accounting_periods, [:organization_id, :status])
    create index(:accounting_periods, [:fiscal_year_id])
    create unique_index(:accounting_periods, [:organization_id, :name])

    create unique_index(:accounting_periods, [:id, :organization_id],
             name: :accounting_periods_id_organization_id_index
           )

    create unique_index(:accounting_fiscal_years, [:id, :organization_id],
             name: :accounting_fiscal_years_id_organization_id_index
           )

    create constraint(:accounting_periods, :accounting_periods_valid_date_range,
             check: "starts_on <= ends_on"
           )

    create constraint(:accounting_periods, :accounting_periods_type_check,
             check: "period_type IN ('monthly', 'annual', 'adjustment', 'closing')"
           )

    create constraint(:accounting_periods, :accounting_periods_status_check,
             check: "status IN ('open', 'closing', 'closed', 'locked')"
           )

    execute("""
    ALTER TABLE accounting_periods
    ADD CONSTRAINT accounting_periods_fiscal_year_organization_fk
    FOREIGN KEY (fiscal_year_id, organization_id)
    REFERENCES accounting_fiscal_years (id, organization_id)
    """)

    execute("""
    ALTER TABLE accounting_periods
    ADD CONSTRAINT accounting_periods_no_overlap
    EXCLUDE USING gist (
      organization_id WITH =,
      daterange(starts_on, ends_on, '[]') WITH &&
    )
    """)

    create table(:accounting_period_events, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :period_id,
          references(:accounting_periods, type: :uuid, on_delete: :delete_all),
          null: false

      add :event_type, :string, null: false
      add :from_status, :string
      add :to_status, :string, null: false

      add :user_id,
          references(:users, type: :uuid, on_delete: :nilify_all)

      add :reason, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:accounting_period_events, [:organization_id, :inserted_at])
    create index(:accounting_period_events, [:period_id])

    create constraint(:accounting_period_events, :accounting_period_events_type_check,
             check: "event_type IN ('opened', 'closing_started', 'closed', 'locked', 'reopened')"
           )

    create constraint(:accounting_period_events, :accounting_period_events_to_status_check,
             check: "to_status IN ('open', 'closing', 'closed', 'locked')"
           )

    create constraint(:accounting_period_events, :accounting_period_events_from_status_check,
             check:
               "from_status IS NULL OR from_status IN ('open', 'closing', 'closed', 'locked')"
           )

    execute("""
    ALTER TABLE accounting_period_events
    ADD CONSTRAINT accounting_period_events_period_organization_fk
    FOREIGN KEY (period_id, organization_id)
    REFERENCES accounting_periods (id, organization_id)
    """)
  end
end
