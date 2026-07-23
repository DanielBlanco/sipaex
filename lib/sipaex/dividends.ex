defmodule Sipaex.Dividends do
  @moduledoc """
  Shareholder capital and dividend distribution workflows.
  """

  import Ecto.Query

  alias Sipaex.Accounting
  alias Sipaex.Common.Currencies
  alias Sipaex.Dividends.Beneficiary
  alias Sipaex.Dividends.CapitalEntry
  alias Sipaex.Dividends.Entry
  alias Sipaex.Ledger
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo

  def settings(organization \\ first_organization!()) do
    organization = Repo.preload(organization, :base_currency)
    currency_settings = Currencies.currency_settings(organization)

    shareholders =
      Beneficiary
      |> where([shareholder], shareholder.organization_id == ^organization.id)
      |> order_by([shareholder], asc: shareholder.name)
      |> Repo.all()

    capital_entries =
      CapitalEntry
      |> join(:inner, [entry], shareholder in assoc(entry, :beneficiary))
      |> where([_entry, shareholder], shareholder.organization_id == ^organization.id)
      |> preload(:beneficiary)
      |> order_by([entry], desc: entry.entry_date, desc: entry.inserted_at)
      |> Repo.all()

    dividend_entries =
      Entry
      |> join(:inner, [entry], shareholder in assoc(entry, :beneficiary))
      |> where([_entry, shareholder], shareholder.organization_id == ^organization.id)
      |> preload(:beneficiary)
      |> order_by([entry], desc: entry.entry_date, desc: entry.inserted_at)
      |> Repo.all()

    capital_rows = capital_rows(shareholders, capital_entries)
    capital_totals = capital_totals(capital_rows)
    dividend_rows = dividend_rows(shareholders, dividend_entries)
    dividend_totals = dividend_totals(dividend_rows)

    %{
      organization: organization,
      currency_settings: currency_settings,
      shareholders: shareholders,
      beneficiaries: shareholders,
      capital_entries: capital_entries,
      entries: dividend_entries,
      capital_rows: capital_rows,
      capital_totals: capital_totals,
      mayor_rows: dividend_rows,
      totals: dividend_totals
    }
  end

  def create_beneficiary(attrs, organization \\ first_organization!()) do
    %Beneficiary{}
    |> Beneficiary.changeset(Map.put(attrs, "organization_id", organization.id))
    |> Repo.insert()
  end

  def create_capital_entry(attrs, organization \\ first_organization!()) do
    with %Beneficiary{} <- get_beneficiary_for_organization(attrs["beneficiary_id"], organization),
         entry_date = date_from_param(attrs["entry_date"]),
         :ok <- Accounting.ensure_writable_period(organization, entry_date) do
      share_value = decimal_from_param(attrs["share_value_usd"])
      quantity = integer_from_param(attrs["quantity"])
      payment = decimal_from_param(attrs["payment_usd"] || "0")
      capital = Decimal.mult(share_value, Decimal.new(quantity))

      attrs =
        attrs
        |> Map.put("organization_id", organization.id)
        |> Map.put("quantity", quantity)
        |> Map.put("capital_usd", capital)
        |> Map.put("payment_usd", payment)
        |> Map.put("receivable_usd", Decimal.sub(capital, payment))

      %CapitalEntry{}
      |> CapitalEntry.changeset(attrs)
      |> Repo.insert()
    else
      nil -> {:error, :invalid_beneficiary}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_entry(attrs, organization \\ first_organization!()) do
    with %Beneficiary{} <- get_beneficiary_for_organization(attrs["beneficiary_id"], organization),
         entry_date = date_from_param(attrs["entry_date"]),
         :ok <- Accounting.ensure_writable_period(organization, entry_date) do
      declaration_amount = decimal_from_param(attrs["declaration_amount_usd"])
      payment = decimal_from_param(attrs["payment_usd"] || "0")
      shareholder_id = attrs["beneficiary_id"]
      settings = settings(organization)
      shareholder_capital = shareholder_capital(settings.capital_rows, shareholder_id)
      total_share_capital = settings.capital_totals.capital

      participation_percent =
        if Decimal.compare(total_share_capital, Decimal.new("0")) == :eq do
          Decimal.new("0")
        else
          Decimal.div(shareholder_capital, total_share_capital)
        end

      shareholder_dividend = Decimal.mult(declaration_amount, participation_percent)

      attrs =
        attrs
        |> Map.put("organization_id", organization.id)
        |> Map.put("total_share_capital_usd", total_share_capital)
        |> Map.put("shareholder_capital_usd", shareholder_capital)
        |> Map.put("participation_percent", participation_percent)
        |> Map.put("shareholder_dividend_usd", shareholder_dividend)
        |> Map.put("payment_usd", payment)
        |> Map.put("payable_usd", Decimal.sub(shareholder_dividend, payment))

      %Entry{}
      |> Entry.changeset(attrs)
      |> Repo.insert()
    else
      nil -> {:error, :invalid_beneficiary}
      {:error, reason} -> {:error, reason}
    end
  end

  def summary_totals(organization \\ first_organization!()) do
    settings(organization).totals
  end

  def display_amount(amount, settings) do
    Ledger.display_amount(amount, settings.currency_settings)
  end

  def display_percent(decimal) do
    decimal
    |> Decimal.mult(Decimal.new("100"))
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> Kernel.<>("%")
  end

  defp capital_rows(shareholders, capital_entries) do
    Enum.map(shareholders, fn shareholder ->
      entries = Enum.filter(capital_entries, &(&1.beneficiary_id == shareholder.id))
      capital = sum_entries(entries, :capital_usd)
      payments = sum_entries(entries, :payment_usd)

      %{
        shareholder: shareholder,
        capital: capital,
        payments: payments,
        receivable: Decimal.sub(capital, payments)
      }
    end)
  end

  defp capital_totals(rows) do
    capital = sum_rows(rows, :capital)
    payments = sum_rows(rows, :payments)

    %{
      capital: capital,
      payments: payments,
      receivable: Decimal.sub(capital, payments)
    }
  end

  defp dividend_rows(shareholders, entries) do
    Enum.map(shareholders, fn shareholder ->
      shareholder_entries = Enum.filter(entries, &(&1.beneficiary_id == shareholder.id))
      dividends = sum_entries(shareholder_entries, :shareholder_dividend_usd)
      payments = sum_entries(shareholder_entries, :payment_usd)

      %{
        beneficiary: shareholder,
        dividends: dividends,
        payments: payments,
        payable: Decimal.sub(dividends, payments)
      }
    end)
  end

  defp dividend_totals(rows) do
    dividends = sum_rows(rows, :dividends)
    payments = sum_rows(rows, :payments)

    %{
      dividends: dividends,
      payments: payments,
      payable: Decimal.sub(dividends, payments)
    }
  end

  defp shareholder_capital(rows, shareholder_id) do
    rows
    |> Enum.find(%{capital: Decimal.new("0")}, &(&1.shareholder.id == shareholder_id))
    |> Map.fetch!(:capital)
  end

  defp sum_entries(entries, field) do
    Enum.reduce(entries, Decimal.new("0"), fn entry, acc ->
      Decimal.add(acc, Map.fetch!(entry, field))
    end)
  end

  defp sum_rows(rows, field) do
    Enum.reduce(rows, Decimal.new("0"), fn row, acc ->
      Decimal.add(acc, Map.fetch!(row, field))
    end)
  end

  defp first_organization! do
    Organization
    |> order_by([organization], asc: organization.inserted_at)
    |> preload(:base_currency)
    |> Repo.one!()
  end

  defp get_beneficiary_for_organization(id, organization) do
    Beneficiary
    |> where([beneficiary], beneficiary.id == ^id)
    |> where([beneficiary], beneficiary.organization_id == ^organization.id)
    |> Repo.one()
  end

  defp decimal_from_param(%Decimal{} = value), do: value
  defp decimal_from_param(nil), do: Decimal.new("0")
  defp decimal_from_param(value) when is_integer(value), do: Decimal.new(value)
  defp decimal_from_param(value) when is_binary(value), do: Decimal.new(value)

  defp integer_from_param(value) when is_integer(value), do: value
  defp integer_from_param(value) when is_binary(value), do: String.to_integer(value)

  defp date_from_param(%Date{} = value), do: value
  defp date_from_param(value) when is_binary(value), do: Date.from_iso8601!(value)
end
