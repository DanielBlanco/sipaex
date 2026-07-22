defmodule SipaexWeb.PageController do
  use SipaexWeb, :controller

  import Ecto.Query

  alias Sipaex.Accounts.User
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Organizations.Organization
  alias Sipaex.Organizations.OrganizationCurrency
  alias Sipaex.Repo

  def home(conn, _params) do
    render(conn, :home, form: Phoenix.Component.to_form(%{}, as: :session))
  end

  def dashboard(conn, _params) do
    organization =
      Organization
      |> order_by([organization], asc: organization.inserted_at)
      |> preload(:base_currency)
      |> Repo.one()

    exchange_rates =
      ExchangeRate
      |> where([exchange_rate], exchange_rate.scope == "GLOBAL")
      |> order_by([exchange_rate], desc: exchange_rate.as_of)
      |> preload([:base_currency, :quote_currency])
      |> limit(4)
      |> Repo.all()

    dashboard = %{
      organization: organization,
      currencies_count: Repo.aggregate(Currency, :count),
      organization_currencies_count: Repo.aggregate(OrganizationCurrency, :count),
      exchange_rates_count: Repo.aggregate(ExchangeRate, :count),
      users_count: Repo.aggregate(User, :count),
      exchange_rates: exchange_rates
    }

    render(conn, :dashboard, dashboard: dashboard)
  end
end
