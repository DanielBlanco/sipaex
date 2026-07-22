defmodule Sipaex.Ledger.BankAccount do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ledger_bank_accounts" do
    field :name, :string
    field :current_account_number, :string
    field :customer_account_number, :string
    field :iban, :string
    field :active, :boolean, default: true

    belongs_to :organization, Sipaex.Organizations.Organization
    belongs_to :currency, Sipaex.Common.Currency

    has_many :transactions, Sipaex.Ledger.Transaction

    timestamps(type: :utc_datetime)
  end

  def changeset(bank_account, attrs) do
    bank_account
    |> cast(attrs, [
      :organization_id,
      :currency_id,
      :name,
      :current_account_number,
      :customer_account_number,
      :iban,
      :active
    ])
    |> validate_required([:organization_id, :currency_id, :name])
    |> unique_constraint([:organization_id, :iban])
  end
end
