defmodule Sipaex.Accounting.PeriodEvent do
  use Ecto.Schema

  import Ecto.Changeset

  @event_types ~w(opened closing_started closed locked reopened)
  @statuses ~w(open closing closed locked)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "accounting_period_events" do
    field :event_type, :string
    field :from_status, :string
    field :to_status, :string
    field :reason, :string

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :period, Sipaex.Accounting.Period
    belongs_to :user, Sipaex.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def event_types, do: @event_types

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :organization_id,
      :period_id,
      :event_type,
      :from_status,
      :to_status,
      :user_id,
      :reason
    ])
    |> validate_required([:organization_id, :period_id, :event_type, :to_status])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_inclusion(:to_status, @statuses)
    |> validate_from_status()
    |> foreign_key_constraint(:period_id,
      name: :accounting_period_events_period_organization_fk
    )
  end

  defp validate_from_status(changeset) do
    case get_field(changeset, :from_status) do
      nil -> changeset
      _status -> validate_inclusion(changeset, :from_status, @statuses)
    end
  end
end
