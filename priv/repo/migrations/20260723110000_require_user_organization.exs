defmodule Sipaex.Repo.Migrations.RequireUserOrganization do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :organization_id, :uuid, null: false
    end
  end
end
