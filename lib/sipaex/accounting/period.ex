defmodule Sipaex.Accounting.Period do
  use Ecto.Schema

  import Ecto.Changeset

  @period_types ~w(monthly annual adjustment closing)
  @statuses ~w(open closing closed locked)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "accounting_periods" do
    field :name, :string
    field :period_type, :string
    field :status, :string, default: "open"
    field :starts_on, :date
    field :ends_on, :date
    field :closed_at, :utc_datetime

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :fiscal_year, Sipaex.Accounting.FiscalYear
    belongs_to :closed_by_user, Sipaex.Accounts.User

    has_many :events, Sipaex.Accounting.PeriodEvent

    timestamps(type: :utc_datetime)
  end

  def period_types, do: @period_types
  def statuses, do: @statuses

  def changeset(period, attrs) do
    period
    |> cast(attrs, [
      :organization_id,
      :fiscal_year_id,
      :name,
      :period_type,
      :status,
      :starts_on,
      :ends_on,
      :closed_at,
      :closed_by_user_id
    ])
    |> validate_required([
      :organization_id,
      :fiscal_year_id,
      :name,
      :period_type,
      :status,
      :starts_on,
      :ends_on
    ])
    |> validate_inclusion(:period_type, @period_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_date_range()
    |> unique_constraint([:organization_id, :name])
    |> check_constraint(:starts_on, name: :accounting_periods_valid_date_range)
    |> check_constraint(:period_type, name: :accounting_periods_type_check)
    |> check_constraint(:status, name: :accounting_periods_status_check)
    |> exclusion_constraint(:starts_on, name: :accounting_periods_no_overlap)
    |> foreign_key_constraint(:fiscal_year_id,
      name: :accounting_periods_fiscal_year_organization_fk
    )
  end

  defp validate_date_range(changeset) do
    starts_on = get_field(changeset, :starts_on)
    ends_on = get_field(changeset, :ends_on)

    if starts_on && ends_on && Date.compare(starts_on, ends_on) == :gt do
      add_error(changeset, :ends_on, "must be on or after starts_on")
    else
      changeset
    end
  end
end
