defmodule Sipaex.Repo.Migrations.CreateCommerceEntryLines do
  use Ecto.Migration

  def change do
    create table(:commerce_entry_lines, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :entry_id, references(:commerce_entries, type: :uuid, on_delete: :delete_all),
        null: false

      add :description, :string, null: false
      add :quantity, :decimal, precision: 20, scale: 6, null: false, default: 1
      add :unit_price, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :vat_rate_id, references(:vat_rates, type: :uuid, on_delete: :restrict), null: false
      add :vat_rate, :decimal, precision: 8, scale: 4, null: false
      add :exempt_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :taxable_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :vat_amount_usd, :decimal, precision: 20, scale: 10, null: false, default: 0
      add :total_usd, :decimal, precision: 20, scale: 10, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:commerce_entry_lines, [:entry_id])
    create index(:commerce_entry_lines, [:vat_rate_id])
  end
end
