defmodule Sipaex.Accounting.JournalEntry do
  use Ecto.Schema

  import Ecto.Changeset

  @entry_types ~w(operational adjustment closing reversal)
  @statuses ~w(draft posted reversed)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "journal_entries" do
    field :entry_date, :date
    field :entry_type, :string
    field :status, :string, default: "posted"
    field :source_type, :string
    field :source_id, :binary_id
    field :description, :string
    field :posted_at, :utc_datetime

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :period, Sipaex.Accounting.Period
    belongs_to :posted_by_user, Sipaex.Accounts.User
    belongs_to :reversed_entry, __MODULE__

    has_many :lines, Sipaex.Accounting.JournalLine

    timestamps(type: :utc_datetime)
  end

  def entry_types, do: @entry_types
  def statuses, do: @statuses

  def changeset(journal_entry, attrs) do
    journal_entry
    |> cast(attrs, [
      :organization_id,
      :period_id,
      :entry_date,
      :entry_type,
      :status,
      :source_type,
      :source_id,
      :description,
      :posted_at,
      :posted_by_user_id,
      :reversed_entry_id
    ])
    |> validate_required([
      :organization_id,
      :period_id,
      :entry_date,
      :entry_type,
      :status,
      :description
    ])
    |> validate_inclusion(:entry_type, @entry_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:period_id, name: :journal_entries_period_organization_fk)
    |> unique_constraint([:organization_id, :source_type, :source_id],
      name: :journal_entries_unique_source_index
    )
    |> check_constraint(:entry_type, name: :journal_entries_type_check)
    |> check_constraint(:status, name: :journal_entries_status_check)
  end
end
