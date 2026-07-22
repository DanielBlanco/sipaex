defmodule SipaexWeb.PageController do
  use SipaexWeb, :controller

  import Ecto.Query

  alias Sipaex.Accounts.User
  alias Sipaex.Bank
  alias Sipaex.Common.Currencies
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Ledger
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

  def ledger(conn, params) do
    render_ledger(conn, params["tab"])
  end

  def bank(conn, _params) do
    render_bank(conn)
  end

  def create_petty_cash(conn, %{"petty_cash" => petty_cash_params}) do
    case Bank.create_petty_cash(petty_cash_params) do
      {:ok, _transaction} ->
        conn
        |> put_flash(:info, "Entrada de caja chica registrada correctamente.")
        |> redirect(to: ~p"/bank")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos de caja chica.")
        |> redirect(to: ~p"/bank")
    end
  end

  def delete_petty_cash(conn, %{"id" => id}) do
    case Bank.delete_petty_cash(id) do
      {:ok, _transaction} ->
        conn
        |> put_flash(:info, "Entrada de caja chica eliminada.")
        |> redirect(to: ~p"/bank")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "No fue posible eliminar la entrada de caja chica.")
        |> redirect(to: ~p"/bank")
    end
  end

  def create_ledger_account(conn, %{"bank_account" => bank_account_params}) do
    case Ledger.create_bank_account(bank_account_params) do
      {:ok, _bank_account} ->
        conn
        |> put_flash(:info, "Cuenta bancaria creada correctamente.")
        |> redirect(to: ~p"/ledger?tab=accounts")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos de la cuenta bancaria.")
        |> redirect(to: ~p"/ledger?tab=accounts")
    end
  end

  def create_ledger_transaction(conn, %{"ledger_transaction" => transaction_params}) do
    case Ledger.create_transaction(transaction_params) do
      {:ok, _transaction} ->
        conn
        |> put_flash(:info, "Movimiento registrado correctamente.")
        |> redirect(to: ~p"/ledger?tab=transactions")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del movimiento.")
        |> redirect(to: ~p"/ledger?tab=transactions")
    end
  end

  def create_ledger_exchange_difference(conn, %{
        "exchange_difference" => exchange_difference_params
      }) do
    case Ledger.create_exchange_difference(exchange_difference_params) do
      {:ok, _exchange_difference} ->
        conn
        |> put_flash(:info, "Diferencial cambiario registrado correctamente.")
        |> redirect(to: ~p"/ledger?tab=exchange-differences")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del diferencial cambiario.")
        |> redirect(to: ~p"/ledger?tab=exchange-differences")
    end
  end

  def currencies(conn, _params) do
    render_currencies(conn)
  end

  def create_currency(conn, %{"currency" => currency_params}) do
    case Currencies.create_currency(currency_params) do
      {:ok, %{currency: currency}} ->
        conn
        |> put_flash(:info, "Moneda #{currency.code} agregada correctamente.")
        |> redirect(to: ~p"/currencies")

      {:error, _step, _changeset, _changes_so_far} ->
        conn
        |> put_flash(:error, "Revise los datos de la moneda y el tipo de cambio.")
        |> redirect(to: ~p"/currencies")
    end
  end

  def set_default_currency(conn, %{"organization_currency" => %{"currency_id" => currency_id}}) do
    case Currencies.set_default_currency(currency_id) do
      {:ok, _result} ->
        conn
        |> put_flash(:info, "Moneda predeterminada actualizada.")
        |> redirect(to: ~p"/currencies")

      {:error, _step, _reason, _changes_so_far} ->
        conn
        |> put_flash(:error, "No fue posible actualizar la moneda predeterminada.")
        |> redirect(to: ~p"/currencies")
    end
  end

  def delete_currency(conn, %{"currency_id" => currency_id}) do
    case Currencies.remove_currency(currency_id) do
      {:ok, _result} ->
        conn
        |> put_flash(:info, "Moneda removida de la organización.")
        |> redirect(to: ~p"/currencies")

      {:error, :storage_currency_required} ->
        conn
        |> put_flash(:error, "USD es obligatorio y no se puede remover.")
        |> redirect(to: ~p"/currencies")

      {:error, _step, _reason, _changes_so_far} ->
        conn
        |> put_flash(:error, "No fue posible remover la moneda.")
        |> redirect(to: ~p"/currencies")
    end
  end

  defp render_currencies(conn) do
    settings = Currencies.currency_settings()

    currency_form =
      Phoenix.Component.to_form(
        %{"code" => "", "name" => "", "symbol" => "", "decimal_places" => "2", "rate" => ""},
        as: :currency
      )

    default_form =
      Phoenix.Component.to_form(
        %{"currency_id" => settings.organization && settings.organization.base_currency_id},
        as: :organization_currency
      )

    render(conn, :currencies,
      settings: settings,
      currency_form: currency_form,
      default_form: default_form
    )
  end

  defp render_bank(conn) do
    summary = Bank.summary()
    default_currency = List.first(summary.petty_cash_currencies)

    petty_cash_form =
      Phoenix.Component.to_form(
        %{
          "details" => "",
          "amount" => "",
          "currency_id" => default_currency && default_currency.id,
          "transaction_type" => "withdrawal"
        },
        as: :petty_cash
      )

    render(conn, :bank, summary: summary, petty_cash_form: petty_cash_form)
  end

  defp render_ledger(conn, active_tab) do
    settings = Ledger.ledger_settings()
    active_tab = active_ledger_tab(active_tab)

    bank_account_form =
      Phoenix.Component.to_form(
        %{
          "name" => "",
          "current_account_number" => "",
          "customer_account_number" => "",
          "iban" => "",
          "currency_id" => settings.currency_settings.storage_currency.id
        },
        as: :bank_account
      )

    default_bank_account = List.first(settings.bank_accounts)

    default_exchange_rate =
      if default_bank_account do
        default_bank_account
        |> Ledger.default_exchange_rate_for_bank_account()
        |> then(&if(&1, do: Decimal.to_string(&1, :normal), else: ""))
      else
        ""
      end

    transaction_form =
      Phoenix.Component.to_form(
        %{
          "bank_account_id" => default_bank_account && default_bank_account.id,
          "movement_type" => "deposit_or_transfer_received",
          "transaction_date" => Date.to_iso8601(Date.utc_today()),
          "amount" => "",
          "exchange_rate" => default_exchange_rate,
          "voucher" => "",
          "concept" => ""
        },
        as: :ledger_transaction
      )

    exchange_difference_form =
      Phoenix.Component.to_form(
        %{
          "bank_account_id" => default_bank_account && default_bank_account.id,
          "transaction_date" => Date.to_iso8601(Date.utc_today()),
          "foreign_amount" => "",
          "purchase_exchange_rate" => default_exchange_rate,
          "sale_exchange_rate" => "",
          "voucher" => "",
          "concept" => ""
        },
        as: :exchange_difference
      )

    render(conn, :ledger,
      settings: settings,
      bank_account_form: bank_account_form,
      transaction_form: transaction_form,
      exchange_difference_form: exchange_difference_form,
      active_ledger_tab: active_tab
    )
  end

  defp active_ledger_tab(tab)
       when tab in ["dashboard", "transactions", "accounts", "exchange-differences"],
       do: tab

  defp active_ledger_tab(_tab), do: "dashboard"
end
