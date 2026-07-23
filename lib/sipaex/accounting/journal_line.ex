defmodule Sipaex.Accounting.JournalLine do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "journal_lines" do
    field :line_no, :integer
    field :account_code, :string
    field :account_name, :string
    field :description, :string
    field :debit_usd, :decimal, default: Decimal.new(0)
    field :credit_usd, :decimal, default: Decimal.new(0)

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :journal_entry, Sipaex.Accounting.JournalEntry

    timestamps(type: :utc_datetime)
  end

  def changeset(journal_line, attrs) do
    journal_line
    |> cast(attrs, [
      :organization_id,
      :journal_entry_id,
      :line_no,
      :account_code,
      :account_name,
      :description,
      :debit_usd,
      :credit_usd
    ])
    |> validate_required([
      :organization_id,
      :journal_entry_id,
      :line_no,
      :account_code,
      :account_name,
      :debit_usd,
      :credit_usd
    ])
    |> validate_number(:line_no, greater_than: 0)
    |> validate_number(:debit_usd, greater_than_or_equal_to: 0)
    |> validate_number(:credit_usd, greater_than_or_equal_to: 0)
    |> validate_amount_direction()
    |> foreign_key_constraint(:journal_entry_id, name: :journal_lines_entry_organization_fk)
    |> unique_constraint([:journal_entry_id, :line_no])
    |> check_constraint(:debit_usd, name: :journal_lines_amount_direction_check)
  end

  defp validate_amount_direction(changeset) do
    debit = get_field(changeset, :debit_usd) || Decimal.new(0)
    credit = get_field(changeset, :credit_usd) || Decimal.new(0)

    cond do
      Decimal.compare(debit, 0) == :gt and Decimal.compare(credit, 0) == :gt ->
        add_error(changeset, :credit_usd, "cannot be set when debit is present")

      Decimal.compare(debit, 0) != :gt and Decimal.compare(credit, 0) != :gt ->
        add_error(changeset, :debit_usd, "or credit must be greater than zero")

      true ->
        changeset
    end
  end
end
