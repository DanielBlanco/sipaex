defmodule Sipaex.Expenses.Entry do
  use Ecto.Schema

  import Ecto.Changeset

  @categories ~w(administrative sales)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "expense_entries" do
    field :category, :string
    field :entry_date, :date
    field :invoice_number, :string
    field :exempt_amount_usd, :decimal
    field :taxable_amount_usd, :decimal
    field :tax_rate, :decimal
    field :tax_amount_usd, :decimal
    field :credit_note_usd, :decimal
    field :debit_note_usd, :decimal
    field :total_usd, :decimal
    field :payment_usd, :decimal
    field :payable_usd, :decimal
    field :exchange_rate, :decimal
    field :voucher, :string
    field :concept, :string

    belongs_to :provider, Sipaex.Expenses.Provider
    belongs_to :currency, Sipaex.Common.Currency

    timestamps(type: :utc_datetime)
  end

  def categories, do: @categories

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :provider_id,
      :currency_id,
      :category,
      :entry_date,
      :invoice_number,
      :exempt_amount_usd,
      :taxable_amount_usd,
      :tax_rate,
      :tax_amount_usd,
      :credit_note_usd,
      :debit_note_usd,
      :total_usd,
      :payment_usd,
      :payable_usd,
      :exchange_rate,
      :voucher,
      :concept
    ])
    |> validate_required([
      :provider_id,
      :currency_id,
      :category,
      :entry_date,
      :exempt_amount_usd,
      :taxable_amount_usd,
      :tax_rate,
      :tax_amount_usd,
      :credit_note_usd,
      :debit_note_usd,
      :total_usd,
      :payment_usd,
      :payable_usd,
      :exchange_rate,
      :concept
    ])
    |> validate_inclusion(:category, @categories)
    |> validate_number(:exempt_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:taxable_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:tax_rate, greater_than_or_equal_to: 0)
    |> validate_number(:tax_amount_usd, greater_than_or_equal_to: 0)
    |> validate_number(:credit_note_usd, greater_than_or_equal_to: 0)
    |> validate_number(:debit_note_usd, greater_than_or_equal_to: 0)
    |> validate_number(:total_usd, greater_than_or_equal_to: 0)
    |> validate_number(:payment_usd, greater_than_or_equal_to: 0)
    |> validate_number(:payable_usd, greater_than_or_equal_to: 0)
    |> validate_number(:exchange_rate, greater_than: 0)
  end
end
