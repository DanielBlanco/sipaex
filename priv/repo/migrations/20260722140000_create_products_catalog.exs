defmodule Sipaex.Repo.Migrations.CreateProductsCatalog do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :organization_id,
          references(:organizations, type: :uuid, on_delete: :delete_all),
          null: false

      add :code, :string, null: false
      add :name, :string, null: false
      add :product_type, :string, null: false
      add :unit, :string, null: false, default: "unidad"
      add :description, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:organization_id])
    create index(:products, [:product_type])
    create unique_index(:products, [:organization_id, :code])

    alter table(:commerce_entry_lines) do
      add :product_id, references(:products, type: :uuid, on_delete: :nilify_all)
    end

    create index(:commerce_entry_lines, [:product_id])
  end
end
