defmodule Sipaex.Common.Currencies do
  @moduledoc """
  Currency configuration for SIPAE.

  Amounts are stored in USD as the canonical database currency. The organization
  default currency controls reporting and display conversion through USD-based
  exchange rates.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Organizations.Organization
  alias Sipaex.Organizations.OrganizationCurrency
  alias Sipaex.Repo

  @storage_currency_code "USD"

  def storage_currency_code, do: @storage_currency_code

  def currency_settings(organization \\ first_organization!()) do
    ensure_storage_currency!()

    organization = Repo.preload(organization, :base_currency)

    organization_currencies =
      OrganizationCurrency
      |> where([organization_currency], organization_currency.organization_id == ^organization.id)
      |> join(
        :inner,
        [organization_currency],
        currency in assoc(organization_currency, :currency)
      )
      |> preload([_organization_currency, currency], currency: currency)
      |> order_by([_organization_currency, currency], asc: currency.code)
      |> Repo.all()

    latest_rates =
      ExchangeRate
      |> where([exchange_rate], exchange_rate.scope == "GLOBAL")
      |> join(:inner, [exchange_rate], currency in assoc(exchange_rate, :quote_currency))
      |> distinct([exchange_rate, currency], currency.code)
      |> order_by([exchange_rate, currency], asc: currency.code, desc: exchange_rate.as_of)
      |> preload([_exchange_rate, currency], quote_currency: currency)
      |> Repo.all()
      |> Map.new(fn exchange_rate -> {exchange_rate.quote_currency_id, exchange_rate} end)

    %{
      organization: organization,
      storage_currency: Repo.get_by!(Currency, code: @storage_currency_code),
      organization_currencies: organization_currencies,
      latest_rates: latest_rates
    }
  end

  def currency_for_organization(currency_id, _organization) when currency_id in [nil, ""],
    do: nil

  def currency_for_organization(currency_id, organization) do
    Currency
    |> join(
      :inner,
      [currency],
      organization_currency in OrganizationCurrency,
      on: organization_currency.currency_id == currency.id
    )
    |> where([currency, organization_currency], currency.id == ^currency_id)
    |> where(
      [_currency, organization_currency],
      organization_currency.organization_id == ^organization.id
    )
    |> Repo.one()
  end

  def create_currency(attrs, organization \\ first_organization!()) do
    now = DateTime.utc_now(:second)
    code = attrs |> Map.get("code", "") |> String.upcase() |> String.trim()
    rate = Map.get(attrs, "rate")
    storage_currency = ensure_storage_currency!()

    attrs =
      attrs
      |> Map.put("code", code)
      |> Map.put("activated_at", now)

    Multi.new()
    |> Multi.insert(
      :currency,
      Currency.changeset(%Currency{}, attrs),
      on_conflict: {:replace, [:name, :symbol, :decimal_places, :activated_at, :updated_at]},
      conflict_target: :code
    )
    |> Multi.run(:organization_currency, fn repo, %{currency: currency} ->
      upsert_organization_currency(
        repo,
        organization,
        currency,
        code == @storage_currency_code,
        now
      )
    end)
    |> Multi.run(:exchange_rate, fn repo, %{currency: currency} ->
      upsert_exchange_rate(repo, storage_currency, currency, rate, now)
    end)
    |> Repo.transaction()
  end

  def set_default_currency(currency_id, organization \\ first_organization!()) do
    now = DateTime.utc_now(:second)

    if currency_for_organization(currency_id, organization) do
      Multi.new()
      |> Multi.update_all(
        :clear_default,
        from(organization_currency in OrganizationCurrency,
          where: organization_currency.organization_id == ^organization.id
        ),
        set: [base: false, updated_at: now]
      )
      |> Multi.update_all(
        :set_default,
        from(organization_currency in OrganizationCurrency,
          where:
            organization_currency.organization_id == ^organization.id and
              organization_currency.currency_id == ^currency_id
        ),
        set: [base: true, updated_at: now]
      )
      |> Multi.update(
        :organization,
        Organization.changeset(organization, %{base_currency_id: currency_id})
      )
      |> Repo.transaction()
    else
      {:error, :invalid_currency}
    end
  end

  def remove_currency(currency_id, organization \\ first_organization!()) do
    storage_currency = ensure_storage_currency!()
    now = DateTime.utc_now(:second)

    case currency_for_organization(currency_id, organization) do
      nil ->
        {:error, :invalid_currency}

      %{code: @storage_currency_code} ->
        {:error, :storage_currency_required}

      _currency ->
        Multi.new()
        |> maybe_restore_default_currency(organization, storage_currency, currency_id, now)
        |> Multi.delete_all(
          :organization_currency,
          from(organization_currency in OrganizationCurrency,
            where:
              organization_currency.organization_id == ^organization.id and
                organization_currency.currency_id == ^currency_id
          )
        )
        |> Repo.transaction()
    end
  end

  defp first_organization! do
    Organization
    |> order_by([organization], asc: organization.inserted_at)
    |> Repo.one!()
  end

  defp ensure_storage_currency! do
    now = DateTime.utc_now(:second)

    attrs = %{
      code: @storage_currency_code,
      name: "US Dollar",
      symbol: "$",
      decimal_places: 2,
      activated_at: now
    }

    %Currency{}
    |> Currency.changeset(attrs)
    |> Repo.insert!(
      on_conflict: {:replace, [:name, :symbol, :decimal_places, :activated_at, :updated_at]},
      conflict_target: :code
    )

    Repo.get_by!(Currency, code: @storage_currency_code)
  end

  defp maybe_restore_default_currency(
         multi,
         %{base_currency_id: currency_id} = organization,
         storage_currency,
         currency_id,
         now
       ) do
    multi
    |> Multi.update_all(
      :clear_default,
      from(organization_currency in OrganizationCurrency,
        where: organization_currency.organization_id == ^organization.id
      ),
      set: [base: false, updated_at: now]
    )
    |> Multi.update_all(
      :set_storage_default,
      from(organization_currency in OrganizationCurrency,
        where:
          organization_currency.organization_id == ^organization.id and
            organization_currency.currency_id == ^storage_currency.id
      ),
      set: [base: true, updated_at: now]
    )
    |> Multi.update(
      :organization,
      Organization.changeset(organization, %{base_currency_id: storage_currency.id})
    )
  end

  defp maybe_restore_default_currency(
         multi,
         _organization,
         _storage_currency,
         _currency_id,
         _now
       ),
       do: multi

  defp upsert_organization_currency(repo, organization, currency, base?, now) do
    %OrganizationCurrency{}
    |> OrganizationCurrency.changeset(%{
      organization_id: organization.id,
      currency_id: currency.id,
      base: base?,
      activated_at: now
    })
    |> repo.insert(
      on_conflict: {:replace, [:base, :activated_at, :updated_at]},
      conflict_target: [:organization_id, :currency_id]
    )
  end

  defp upsert_exchange_rate(
         _repo,
         _storage_currency,
         %{code: @storage_currency_code},
         _rate,
         _now
       ) do
    {:ok, nil}
  end

  defp upsert_exchange_rate(repo, storage_currency, currency, rate, now) do
    %ExchangeRate{}
    |> ExchangeRate.changeset(%{
      base_currency_id: storage_currency.id,
      quote_currency_id: currency.id,
      rate: rate,
      as_of: now,
      scope: "GLOBAL",
      source: "manual"
    })
    |> repo.insert()
  end
end
