defmodule Sipaex.Expenses.Provider do
  use Ecto.Schema

  import Ecto.Changeset

  @categories ~w(administrative sales financial)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "expense_providers" do
    field :category, :string
    field :name, :string
    field :identification, :string
    field :email, :string
    field :phone, :string
    field :address, :string
    field :contact, :string
    field :payment_terms_days, :integer
    field :operation_number, :string
    field :loan_concept, :string
    field :interest_rate, :decimal
    field :term_months, :integer
    field :active, :boolean, default: true

    belongs_to :organization, Sipaex.Organizations.Organization
    has_many :expense_entries, Sipaex.Expenses.Entry
    has_many :financial_entries, Sipaex.Expenses.FinancialEntry

    timestamps(type: :utc_datetime)
  end

  def categories, do: @categories

  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [
      :organization_id,
      :category,
      :name,
      :identification,
      :email,
      :phone,
      :address,
      :contact,
      :payment_terms_days,
      :operation_number,
      :loan_concept,
      :interest_rate,
      :term_months,
      :active
    ])
    |> validate_required([:organization_id, :category, :name])
    |> validate_inclusion(:category, @categories)
    |> validate_number(:payment_terms_days, greater_than_or_equal_to: 0)
    |> validate_number(:interest_rate, greater_than_or_equal_to: 0)
    |> validate_number(:term_months, greater_than: 0)
    |> unique_constraint([:organization_id, :category, :identification])
  end
end
