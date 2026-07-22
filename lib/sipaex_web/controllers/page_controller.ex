defmodule SipaexWeb.PageController do
  use SipaexWeb, :controller

  import Ecto.Query

  alias Sipaex.Accounts.User
  alias Sipaex.Bank
  alias Sipaex.Commerce
  alias Sipaex.Common.Currencies
  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Dividends
  alias Sipaex.Expenses
  alias Sipaex.Ledger
  alias Sipaex.Organizations.Organization
  alias Sipaex.Organizations.OrganizationCurrency
  alias Sipaex.Repo
  alias Sipaex.Taxes

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

  def dividends(conn, params) do
    render_dividends(conn, params["tab"])
  end

  def expenses(conn, params) do
    render_expenses(conn, params["tab"])
  end

  def taxes(conn, params) do
    render_taxes(conn, params["tab"])
  end

  def purchases(conn, params) do
    render_commerce(conn, "purchase", params["tab"])
  end

  def sales(conn, params) do
    render_commerce(conn, "sale", params["tab"])
  end

  def create_purchase_party(conn, %{"party" => party_params}) do
    create_commerce_party(conn, "purchase", party_params)
  end

  def create_sale_party(conn, %{"party" => party_params}) do
    create_commerce_party(conn, "sale", party_params)
  end

  def create_purchase_entry(conn, %{"commerce_entry" => entry_params}) do
    create_commerce_entry(conn, "purchase", entry_params)
  end

  def create_sale_entry(conn, %{"commerce_entry" => entry_params}) do
    create_commerce_entry(conn, "sale", entry_params)
  end

  def create_income_tax_entry(conn, %{"income_tax_entry" => entry_params}) do
    case Taxes.create_income_tax_entry(entry_params) do
      {:ok, _entry} ->
        conn
        |> put_flash(:info, "Impuesto de renta registrado correctamente.")
        |> redirect(to: ~p"/taxes?tab=income")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del impuesto de renta.")
        |> redirect(to: ~p"/taxes?tab=income")
    end
  end

  defp create_commerce_party(conn, entry_type, party_params) do
    case Commerce.create_party(entry_type, party_params) do
      {:ok, party} ->
        conn
        |> put_flash(
          :info,
          "#{Commerce.party_label(entry_type)} #{party.name} creado correctamente."
        )
        |> redirect(to: "#{Commerce.panel_path(entry_type)}?tab=parties")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos.")
        |> redirect(to: "#{Commerce.panel_path(entry_type)}?tab=parties")
    end
  end

  defp create_commerce_entry(conn, entry_type, entry_params) do
    case Commerce.create_entry(entry_type, entry_params) do
      {:ok, _entry} ->
        conn
        |> put_flash(:info, "#{Commerce.module_title(entry_type)} registrado correctamente.")
        |> redirect(to: "#{Commerce.panel_path(entry_type)}?tab=entries")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Revise los datos del documento.")
        |> redirect(to: "#{Commerce.panel_path(entry_type)}?tab=entries")
    end
  end

  def create_vat_period(conn, %{"vat_period" => period_params}) do
    case Taxes.create_vat_period(period_params) do
      {:ok, _period} ->
        conn
        |> put_flash(:info, "IVA registrado correctamente.")
        |> redirect(to: ~p"/taxes?tab=vat")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del IVA.")
        |> redirect(to: ~p"/taxes?tab=vat")
    end
  end

  def create_vat_rate(conn, %{"vat_rate" => rate_params}) do
    case Taxes.create_vat_rate(rate_params) do
      {:ok, _rate} ->
        conn
        |> put_flash(:info, "Tarifa IVA agregada correctamente.")
        |> redirect(to: ~p"/taxes?tab=vat-rates")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos de la tarifa IVA.")
        |> redirect(to: ~p"/taxes?tab=vat-rates")
    end
  end

  def toggle_vat_rate(conn, %{"id" => id}) do
    case Taxes.toggle_vat_rate(id) do
      {:ok, rate} ->
        conn
        |> put_flash(:info, "Tarifa IVA #{if(rate.active, do: "activada", else: "desactivada")}.")
        |> redirect(to: ~p"/taxes?tab=vat-rates")

      {:error, :exempt_vat_required} ->
        conn
        |> put_flash(:error, "La tarifa exenta 0% es obligatoria.")
        |> redirect(to: ~p"/taxes?tab=vat-rates")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "No fue posible actualizar la tarifa IVA.")
        |> redirect(to: ~p"/taxes?tab=vat-rates")
    end
  end

  def create_expense_provider(conn, %{"provider" => provider_params}) do
    case Expenses.create_provider(provider_params) do
      {:ok, provider} ->
        conn
        |> put_flash(:info, "Proveedor #{provider.name} creado correctamente.")
        |> redirect(to: ~p"/expenses?tab=providers")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del proveedor.")
        |> redirect(to: ~p"/expenses?tab=providers")
    end
  end

  def create_expense_entry(conn, %{"expense_entry" => entry_params}) do
    case Expenses.create_entry(entry_params) do
      {:ok, _entry} ->
        conn
        |> put_flash(:info, "Gasto registrado correctamente.")
        |> redirect(to: ~p"/expenses?tab=entries")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del gasto.")
        |> redirect(to: ~p"/expenses?tab=entries")
    end
  end

  def create_financial_expense_entry(conn, %{"financial_entry" => entry_params}) do
    case Expenses.create_financial_entry(entry_params) do
      {:ok, _entry} ->
        conn
        |> put_flash(:info, "Gasto financiero registrado correctamente.")
        |> redirect(to: ~p"/expenses?tab=financial")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del gasto financiero.")
        |> redirect(to: ~p"/expenses?tab=financial")
    end
  end

  def create_dividend_beneficiary(conn, %{"beneficiary" => beneficiary_params}) do
    case Dividends.create_beneficiary(beneficiary_params) do
      {:ok, _beneficiary} ->
        conn
        |> put_flash(:info, "Beneficiario de dividendos creado correctamente.")
        |> redirect(to: ~p"/dividends?tab=beneficiaries")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del beneficiario.")
        |> redirect(to: ~p"/dividends?tab=beneficiaries")
    end
  end

  def create_shareholder_capital_entry(conn, %{"capital_entry" => capital_entry_params}) do
    case Dividends.create_capital_entry(capital_entry_params) do
      {:ok, _entry} ->
        conn
        |> put_flash(:info, "Capital accionario registrado correctamente.")
        |> redirect(to: ~p"/dividends?tab=capital")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del capital accionario.")
        |> redirect(to: ~p"/dividends?tab=capital")
    end
  end

  def create_dividend_entry(conn, %{"dividend_entry" => entry_params}) do
    case Dividends.create_entry(entry_params) do
      {:ok, _entry} ->
        conn
        |> put_flash(:info, "Movimiento de dividendos registrado correctamente.")
        |> redirect(to: ~p"/dividends?tab=entries")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Revise los datos del movimiento de dividendos.")
        |> redirect(to: ~p"/dividends?tab=entries")
    end
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

  defp render_commerce(conn, entry_type, active_tab) do
    settings = Commerce.settings(entry_type)
    active_tab = active_commerce_tab(active_tab)
    default_party = List.first(settings.parties)
    default_currency = List.first(settings.currencies)
    default_vat_rate = List.first(settings.vat_rates)

    default_exchange_rate =
      if default_currency do
        default_currency
        |> Commerce.default_exchange_rate_for_currency()
        |> then(&if(&1, do: Decimal.to_string(&1, :normal), else: ""))
      else
        ""
      end

    party_form =
      Phoenix.Component.to_form(
        %{"name" => "", "identification" => "", "email" => "", "phone" => ""},
        as: :party
      )

    entry_form =
      Phoenix.Component.to_form(
        %{
          "party_id" => default_party && default_party.id,
          "currency_id" => default_currency && default_currency.id,
          "vat_rate_id" => default_vat_rate && default_vat_rate.id,
          "entry_date" => Date.to_iso8601(Date.utc_today()),
          "document_number" => "",
          "exempt_amount" => "0",
          "taxable_amount" => "",
          "payment" => "0",
          "exchange_rate" => default_exchange_rate,
          "concept" => ""
        },
        as: :commerce_entry
      )

    render(conn, :commerce,
      settings: settings,
      party_form: party_form,
      entry_form: entry_form,
      active_commerce_tab: active_tab
    )
  end

  defp render_expenses(conn, active_tab) do
    settings = Expenses.settings()
    active_tab = active_expenses_tab(active_tab)
    default_provider = List.first(settings.providers)

    default_ordinary_provider =
      List.first(settings.administrative_providers) || List.first(settings.sales_providers)

    default_financial_provider = List.first(settings.financial_providers)
    default_currency = List.first(settings.currencies)

    default_exchange_rate =
      if default_currency do
        default_currency
        |> Expenses.default_exchange_rate_for_currency()
        |> then(&if(&1, do: Decimal.to_string(&1, :normal), else: ""))
      else
        ""
      end

    provider_form =
      Phoenix.Component.to_form(
        %{
          "category" => "administrative",
          "name" => "",
          "identification" => "",
          "email" => "",
          "phone" => "",
          "address" => "",
          "contact" => "",
          "payment_terms_days" => "30",
          "operation_number" => "",
          "loan_concept" => "",
          "interest_rate" => "",
          "term_months" => ""
        },
        as: :provider
      )

    entry_form =
      Phoenix.Component.to_form(
        %{
          "provider_id" => default_ordinary_provider && default_ordinary_provider.id,
          "currency_id" => default_currency && default_currency.id,
          "entry_date" => Date.to_iso8601(Date.utc_today()),
          "invoice_number" => "",
          "exempt_amount" => "0",
          "taxable_amount" => "",
          "tax_rate" => "0.13",
          "credit_note" => "0",
          "debit_note" => "0",
          "payment" => "0",
          "exchange_rate" => default_exchange_rate,
          "voucher" => "",
          "concept" => ""
        },
        as: :expense_entry
      )

    financial_entry_form =
      Phoenix.Component.to_form(
        %{
          "provider_id" => default_financial_provider && default_financial_provider.id,
          "currency_id" => default_currency && default_currency.id,
          "entry_date" => Date.to_iso8601(Date.utc_today()),
          "loan_amount" => "0",
          "principal_payment" => "0",
          "financial_expense" => "",
          "credit_note" => "0",
          "debit_note" => "0",
          "financial_expense_payment" => "0",
          "exchange_rate" => default_exchange_rate,
          "voucher" => "",
          "concept" => ""
        },
        as: :financial_entry
      )

    render(conn, :expenses,
      settings: settings,
      provider_form: provider_form,
      entry_form: entry_form,
      financial_entry_form: financial_entry_form,
      default_provider: default_provider,
      active_expenses_tab: active_tab
    )
  end

  defp render_taxes(conn, active_tab) do
    settings = Taxes.settings()
    active_tab = active_taxes_tab(active_tab)
    default_currency = List.first(settings.currencies)
    today = Date.utc_today()
    vat_source_totals = Taxes.vat_source_totals(today.month, today.year)

    default_exchange_rate =
      if default_currency do
        default_currency
        |> Taxes.default_exchange_rate_for_currency()
        |> then(&if(&1, do: Decimal.to_string(&1, :normal), else: ""))
      else
        ""
      end

    income_tax_form =
      Phoenix.Component.to_form(
        %{
          "currency_id" => default_currency && default_currency.id,
          "entry_date" => Date.to_iso8601(Date.utc_today()),
          "fiscal_period" => Integer.to_string(Date.utc_today().year),
          "tax_amount" => "",
          "payment" => "0",
          "exchange_rate" => default_exchange_rate,
          "voucher" => "",
          "concept" => "Impuesto de renta"
        },
        as: :income_tax_entry
      )

    vat_period_form =
      Phoenix.Component.to_form(
        %{
          "currency_id" => default_currency && default_currency.id,
          "period_month" => Integer.to_string(today.month),
          "period_year" => Integer.to_string(today.year),
          "payment" => "0",
          "exchange_rate" => default_exchange_rate,
          "voucher" => "",
          "concept" => "Declaración IVA"
        },
        as: :vat_period
      )

    vat_rate_form =
      Phoenix.Component.to_form(
        %{
          "rate" => "",
          "description" => ""
        },
        as: :vat_rate
      )

    render(conn, :taxes,
      settings: settings,
      income_tax_form: income_tax_form,
      vat_period_form: vat_period_form,
      vat_rate_form: vat_rate_form,
      vat_source_totals: vat_source_totals,
      active_taxes_tab: active_tab
    )
  end

  defp render_dividends(conn, active_tab) do
    settings = Dividends.settings()
    active_tab = active_dividends_tab(active_tab)
    default_beneficiary = List.first(settings.beneficiaries)

    beneficiary_form =
      Phoenix.Component.to_form(
        %{
          "name" => "",
          "identification" => "",
          "email" => "",
          "phone" => "",
          "address" => ""
        },
        as: :beneficiary
      )

    entry_form =
      Phoenix.Component.to_form(
        %{
          "beneficiary_id" => default_beneficiary && default_beneficiary.id,
          "entry_date" => Date.to_iso8601(Date.utc_today()),
          "declaration_amount_usd" => "",
          "payment_usd" => "0",
          "voucher" => "",
          "concept" => "Declaratoria de dividendos"
        },
        as: :dividend_entry
      )

    capital_entry_form =
      Phoenix.Component.to_form(
        %{
          "beneficiary_id" => default_beneficiary && default_beneficiary.id,
          "entry_date" => Date.to_iso8601(Date.utc_today()),
          "share_type" => "ACCIONES COMUNES",
          "share_value_usd" => "",
          "quantity" => "",
          "payment_usd" => "0",
          "voucher" => "",
          "concept" => "Suscripción y pago de valores"
        },
        as: :capital_entry
      )

    render(conn, :dividends,
      settings: settings,
      beneficiary_form: beneficiary_form,
      capital_entry_form: capital_entry_form,
      entry_form: entry_form,
      active_dividends_tab: active_tab
    )
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

  defp active_dividends_tab(tab)
       when tab in ["wizard", "dashboard", "shareholders", "beneficiaries", "capital", "entries"],
       do: if(tab == "beneficiaries", do: "shareholders", else: tab)

  defp active_dividends_tab(_tab), do: "wizard"

  defp active_expenses_tab(tab) when tab in ["dashboard", "providers", "entries", "financial"],
    do: tab

  defp active_expenses_tab(_tab), do: "dashboard"

  defp active_commerce_tab(tab) when tab in ["dashboard", "parties", "entries"], do: tab

  defp active_commerce_tab(_tab), do: "dashboard"

  defp active_taxes_tab(tab) when tab in ["dashboard", "vat-rates", "income", "vat"], do: tab

  defp active_taxes_tab(_tab), do: "dashboard"
end
