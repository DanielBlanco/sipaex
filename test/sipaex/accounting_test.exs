defmodule Sipaex.AccountingTest do
  use Sipaex.DataCase

  alias Sipaex.Accounting
  alias Sipaex.Accounting.PeriodEvent
  alias Sipaex.Common.Currency
  alias Sipaex.Organizations.Organization
  alias Sipaex.Repo

  describe "accounting periods" do
    test "allows equal date ranges in different organizations" do
      usd = seed_currency()
      first_organization = seed_organization("Empresa Uno", "3101000001", usd)
      second_organization = seed_organization("Empresa Dos", "3101000002", usd)

      {:ok, first_fiscal_year} =
        Accounting.create_fiscal_year(first_organization, %{
          name: "FY2026",
          starts_on: ~D[2026-01-01],
          ends_on: ~D[2026-12-31]
        })

      {:ok, second_fiscal_year} =
        Accounting.create_fiscal_year(second_organization, %{
          name: "FY2026",
          starts_on: ~D[2026-01-01],
          ends_on: ~D[2026-12-31]
        })

      assert {:ok, _period} =
               Accounting.create_period(first_organization, %{
                 fiscal_year_id: first_fiscal_year.id,
                 name: "Enero 2026",
                 period_type: "monthly",
                 starts_on: ~D[2026-01-01],
                 ends_on: ~D[2026-01-31]
               })

      assert {:ok, _period} =
               Accounting.create_period(second_organization, %{
                 fiscal_year_id: second_fiscal_year.id,
                 name: "Enero 2026",
                 period_type: "monthly",
                 starts_on: ~D[2026-01-01],
                 ends_on: ~D[2026-01-31]
               })
    end

    test "rejects overlapping periods inside the same organization" do
      %{organization: organization, fiscal_year: fiscal_year} = seed_calendar()

      assert {:ok, _period} =
               Accounting.create_period(organization, %{
                 fiscal_year_id: fiscal_year.id,
                 name: "Enero 2026",
                 period_type: "monthly",
                 starts_on: ~D[2026-01-01],
                 ends_on: ~D[2026-01-31]
               })

      assert {:error, changeset} =
               Accounting.create_period(organization, %{
                 fiscal_year_id: fiscal_year.id,
                 name: "Enero parcial",
                 period_type: "monthly",
                 starts_on: ~D[2026-01-15],
                 ends_on: ~D[2026-02-15]
               })

      assert %{starts_on: [_message]} = errors_on(changeset)
    end

    test "finds the period containing an effective date" do
      %{organization: organization, fiscal_year: fiscal_year} = seed_calendar()

      {:ok, period} =
        Accounting.create_period(organization, %{
          fiscal_year_id: fiscal_year.id,
          name: "Febrero 2026",
          period_type: "monthly",
          starts_on: ~D[2026-02-01],
          ends_on: ~D[2026-02-28]
        })

      assert Accounting.period_for_date(organization, ~D[2026-02-14]).id == period.id
      assert Accounting.period_for_date(organization, ~D[2026-03-01]) == nil
      assert Accounting.period_open_for_date?(organization, ~D[2026-02-14])
    end

    test "status changes create auditable events" do
      %{organization: organization, fiscal_year: fiscal_year} = seed_calendar()

      {:ok, period} =
        Accounting.create_period(organization, %{
          fiscal_year_id: fiscal_year.id,
          name: "Marzo 2026",
          period_type: "monthly",
          starts_on: ~D[2026-03-01],
          ends_on: ~D[2026-03-31]
        })

      assert {:ok, closed_period} =
               Accounting.close_period(organization, period.id, reason: "Cierre mensual")

      assert closed_period.status == "closed"
      assert closed_period.closed_at

      events =
        PeriodEvent
        |> where([event], event.period_id == ^period.id)
        |> order_by([event], asc: event.inserted_at)
        |> Repo.all()

      assert Enum.map(events, & &1.event_type) == ["opened", "closed"]
      assert List.last(events).from_status == "open"
      assert List.last(events).to_status == "closed"
      assert List.last(events).reason == "Cierre mensual"
    end
  end

  defp seed_calendar do
    usd = seed_currency()
    organization = seed_organization("Empresa Uno", "3101000001", usd)

    {:ok, fiscal_year} =
      Accounting.create_fiscal_year(organization, %{
        name: "FY2026",
        starts_on: ~D[2026-01-01],
        ends_on: ~D[2026-12-31]
      })

    %{organization: organization, fiscal_year: fiscal_year}
  end

  defp seed_currency do
    %Currency{}
    |> Currency.changeset(%{
      code: "USD",
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
