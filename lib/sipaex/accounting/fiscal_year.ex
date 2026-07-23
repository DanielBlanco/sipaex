defmodule Sipaex.Accounting.FiscalYear do
  use Ecto.Schema

  import Ecto.Changeset

  @statuses ~w(open closing closed locked)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "accounting_fiscal_years" do
    field :name, :string
    field :starts_on, :date
    field :ends_on, :date
    field :status, :string, default: "open"

    belongs_to :organization, Sipaex.Organizations.Organization

    has_many :periods, Sipaex.Accounting.Period

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(fiscal_year, attrs) do
    fiscal_year
    |> cast(attrs, [:organization_id, :name, :starts_on, :ends_on, :status])
    |> validate_required([:organization_id, :name, :starts_on, :ends_on, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_date_range()
    |> unique_constraint([:organization_id, :name])
    |> check_constraint(:starts_on, name: :accounting_fiscal_years_valid_date_range)
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
