alias Sipaex.Accounts.User
alias Sipaex.Common.Currency
alias Sipaex.Common.ExchangeRate
alias Sipaex.Organizations.Organization
alias Sipaex.Organizations.OrganizationCurrency
alias Sipaex.Repo

import Ecto.Query

now = DateTime.utc_now(:second)
exchange_rate_as_of = ~U[2026-07-22 00:00:00Z]

currencies_to_seed = [
  %{code: "USD", name: "US Dollar", symbol: "$", decimal_places: 2},
  %{code: "EUR", name: "Euro", symbol: "€", decimal_places: 2},
  %{code: "CRC", name: "Costa Rican Colón", symbol: "₡", decimal_places: 2},
  %{code: "GBP", name: "British Pound", symbol: "£", decimal_places: 2},
  %{code: "JPY", name: "Japanese Yen", symbol: "¥", decimal_places: 0}
]

for attrs <- currencies_to_seed do
  attrs = Map.put(attrs, :activated_at, now)

  %Currency{}
  |> Currency.changeset(attrs)
  |> Repo.insert!(
    on_conflict: {:replace, [:name, :symbol, :decimal_places, :activated_at, :updated_at]},
    conflict_target: :code
  )

  Mix.shell().info("Seeded currency: #{attrs.code} (#{attrs.name})")
end

active_currencies =
  Currency
  |> where([currency], not is_nil(currency.activated_at))
  |> order_by([currency], currency.code)
  |> Repo.all()

Mix.shell().info("Found #{length(active_currencies)} active currencies")

usd_currency = Repo.get_by!(Currency, code: "USD")

organization_attrs = %{
  name: "Distribuidora Blanco S.A.",
  legal_name: "Distribuidora Blanco Sociedad Anónima",
  tax_id: "3101234567",
  base_currency_id: usd_currency.id,
  activated_at: now
}

organization =
  case Repo.get_by(Organization, tax_id: organization_attrs.tax_id) do
    nil ->
      %Organization{}
      |> Organization.changeset(organization_attrs)
      |> Repo.insert!()

    organization ->
      organization
      |> Organization.changeset(organization_attrs)
      |> Repo.update!()
  end

Mix.shell().info("Seeded organization: #{organization.name} (#{organization.tax_id})")

for currency <- active_currencies do
  attrs = %{
    organization_id: organization.id,
    currency_id: currency.id,
    base: currency.id == usd_currency.id,
    activated_at: now
  }

  %OrganizationCurrency{}
  |> OrganizationCurrency.changeset(attrs)
  |> Repo.insert!(
    on_conflict: {:replace, [:base, :activated_at, :updated_at]},
    conflict_target: [:organization_id, :currency_id]
  )

  Mix.shell().info("Linked currency #{currency.code} to organization (base: #{attrs.base})")
end

exchange_rates = [
  {"CRC", Decimal.new("491.92")},
  {"JPY", Decimal.new("156.75")},
  {"EUR", Decimal.new("0.85")},
  {"GBP", Decimal.new("0.73")}
]

{stale_rate_count, _} =
  ExchangeRate
  |> where(
    [exchange_rate],
    exchange_rate.scope == "GLOBAL" and exchange_rate.source == "seed" and
      exchange_rate.as_of != ^exchange_rate_as_of
  )
  |> Repo.delete_all()

if stale_rate_count > 0 do
  Mix.shell().info("Removed #{stale_rate_count} stale seed exchange rates")
end

for {quote_code, rate} <- exchange_rates do
  quote_currency = Repo.get_by!(Currency, code: quote_code)

  attrs = %{
    base_currency_id: usd_currency.id,
    quote_currency_id: quote_currency.id,
    rate: rate,
    as_of: exchange_rate_as_of,
    scope: "GLOBAL",
    source: "seed"
  }

  %ExchangeRate{}
  |> ExchangeRate.changeset(attrs)
  |> Repo.insert!(
    on_conflict: :nothing,
    conflict_target: [:base_currency_id, :quote_currency_id, :as_of, :scope]
  )

  Mix.shell().info("Seeded GLOBAL exchange rate: USD -> #{quote_code} = #{rate}")
end

password_hash =
  :sha256
  |> :crypto.hash("Sorata8!")
  |> Base.encode16(case: :lower)

user_attrs = %{
  username: "daniel",
  name: "Daniel Blanco",
  email: "daniel.blancorojas@gmail.com",
  password_hash: password_hash,
  role: "admin",
  organization_id: organization.id,
  activated_at: now
}

user =
  case Repo.get_by(User, email: user_attrs.email) do
    nil ->
      %User{}
      |> User.changeset(user_attrs)
      |> Repo.insert!()

    user ->
      user
      |> User.changeset(user_attrs)
      |> Repo.update!()
  end

Mix.shell().info("Seeded user: #{user.username} (#{user.email})")
Mix.shell().info("All seeds created/updated successfully")
