defmodule Sipaex.AccountingJournalTest do
  use Sipaex.DataCase

  alias Sipaex.Accounting
  alias Sipaex.Accounting.JournalEntry
  alias Sipaex.Common.Currency
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo

  describe "journal entries" do
    test "creates a balanced journal entry inside an open period" do
      %{organization: organization} = seed_open_period("Empresa Uno", "3101000001")

      assert {:ok, entry} =
               Accounting.create_journal_entry(
                 organization,
                 %{
                   entry_date: ~D[2026-01-15],
                   entry_type: "operational",
                   description: "Compra de inventario"
                 },
                 [
                   %{account_code: "1-01-01", account_name: "Inventario", debit_usd: "125.50"},
                   %{
                     account_code: "2-01-01",
                     account_name: "Cuentas por pagar",
                     credit_usd: "125.50"
                   }
                 ]
               )

      assert entry.organization_id == organization.id
      assert entry.period_id
      assert entry.status == "posted"
      assert length(entry.lines) == 2
      assert Enum.all?(entry.lines, &(&1.organization_id == organization.id))
    end

    test "rejects unbalanced journal entries" do
      %{organization: organization} = seed_open_period("Empresa Uno", "3101000001")

      assert {:error, :journal_entry_not_balanced} =
               Accounting.create_journal_entry(
                 organization,
                 %{
                   entry_date: ~D[2026-01-15],
                   entry_type: "operational",
                   description: "Asiento descuadrado"
                 },
                 [
                   %{account_code: "1-01-01", account_name: "Banco", debit_usd: "100.00"},
                   %{account_code: "4-01-01", account_name: "Ingresos", credit_usd: "99.99"}
                 ]
               )

      assert Repo.aggregate(JournalEntry, :count) == 0
    end

    test "requires an accounting period for the entry date" do
      usd = seed_currency()
      organization = seed_organization("Empresa Uno", "3101000001", usd)

      assert {:error, :accounting_period_required} =
               Accounting.create_journal_entry(
                 organization,
                 %{
                   entry_date: ~D[2026-01-15],
                   entry_type: "operational",
                   description: "Sin periodo"
                 },
                 [
                   %{account_code: "1-01-01", account_name: "Banco", debit_usd: "100.00"},
                   %{account_code: "4-01-01", account_name: "Ingresos", credit_usd: "100.00"}
                 ]
               )
    end

    test "rejects journal entries inside a closed period" do
      %{organization: organization, period: period} =
        seed_open_period("Empresa Uno", "3101000001")

      assert {:ok, _period} = Accounting.close_period(organization, period.id)

      assert {:error, :accounting_period_closed} =
               Accounting.create_journal_entry(
                 organization,
                 %{
                   entry_date: ~D[2026-01-15],
                   entry_type: "operational",
                   description: "Periodo cerrado"
                 },
                 [
                   %{account_code: "1-01-01", account_name: "Banco", debit_usd: "100.00"},
                   %{account_code: "4-01-01", account_name: "Ingresos", credit_usd: "100.00"}
                 ]
               )
    end

    test "lists and summarizes only entries for the active organization" do
      %{organization: first_organization} = seed_open_period("Empresa Uno", "3101000001", "USD")
      %{organization: second_organization} = seed_open_period("Empresa Dos", "3101000002", "EUR")

      assert {:ok, _entry} =
               Accounting.create_journal_entry(
                 first_organization,
                 %{
                   entry_date: ~D[2026-01-15],
                   entry_type: "operational",
                   description: "Venta empresa uno"
                 },
                 [
                   %{account_code: "1-01-01", account_name: "Banco", debit_usd: "100.00"},
                   %{account_code: "4-01-01", account_name: "Ingresos", credit_usd: "100.00"}
                 ]
               )

      assert {:ok, _entry} =
               Accounting.create_journal_entry(
                 second_organization,
                 %{
                   entry_date: ~D[2026-01-15],
                   entry_type: "operational",
                   description: "Venta empresa dos"
                 },
                 [
                   %{account_code: "1-01-01", account_name: "Banco", debit_usd: "300.00"},
                   %{account_code: "4-01-01", account_name: "Ingresos", credit_usd: "300.00"}
                 ]
               )

      assert [%JournalEntry{organization_id: first_org_id}] =
               Accounting.list_journal_entries(first_organization)

      assert first_org_id == first_organization.id

      assert [
               %{account_code: "1-01-01", debit_usd: debit},
               %{account_code: "4-01-01", credit_usd: credit}
             ] = Accounting.trial_balance(first_organization, ~D[2026-01-01], ~D[2026-01-31])

      assert Decimal.equal?(debit, Decimal.new("100.00"))
      assert Decimal.equal?(credit, Decimal.new("100.00"))
    end
  end

  defp seed_open_period(name, tax_id, currency_code \\ "USD") do
    usd = seed_currency(currency_code)
    organization = seed_organization(name, tax_id, usd)

    {:ok, fiscal_year} =
      Accounting.create_fiscal_year(organization, %{
        name: "FY2026",
        starts_on: ~D[2026-01-01],
        ends_on: ~D[2026-12-31]
      })

    {:ok, period} =
      Accounting.create_period(organization, %{
        fiscal_year_id: fiscal_year.id,
        name: "Enero 2026",
        period_type: "monthly",
        starts_on: ~D[2026-01-01],
        ends_on: ~D[2026-01-31]
      })

    %{organization: organization, period: period}
  end

  defp seed_currency(code \\ "USD") do
    %Currency{}
    |> Currency.changeset(%{
      code: code,
      name: "US Dollar",
      symbol: "$",
      decimal_places: 2,
      activated_at: DateTime.utc_now(:second)
    })
    |> Repo.insert!()
  end

  defp seed_organization(name, tax_id, currency) do
    %Organization{}
    |> Organization.changeset(%{
      name: name,
      legal_name: "#{name} Sociedad Anónima",
      tax_id: tax_id,
      base_currency_id: currency.id,
      activated_at: DateTime.utc_now(:second)
    })
    |> Repo.insert!()
  end
end
