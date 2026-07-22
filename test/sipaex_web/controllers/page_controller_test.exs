defmodule SipaexWeb.PageControllerTest do
  use SipaexWeb.ConnCase

  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Bank.PettyCashTransaction
  alias Sipaex.Ledger
  alias Sipaex.Ledger.BankAccount
  alias Sipaex.Ledger.ExchangeDifference
  alias Sipaex.Ledger.Transaction
  alias Sipaex.Organizations.Organization
  alias Sipaex.Organizations.OrganizationCurrency
  alias Sipaex.Repo

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(id="login-form")
    assert html =~ ~s(action="/dashboard")
    refute html =~ ~s(id="app-topnav")
    assert html =~ "Iniciar sesión"
    assert html =~ "Correo electrónico"
  end

  test "GET /dashboard", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")
    html = html_response(conn, 200)

    assert html =~ ~s(id="app-dashboard")
    assert html =~ ~s(id="app-topnav")
    assert html =~ ~s(id="dashboard-currencies-link")
    assert html =~ "Panel principal"
    assert html =~ "Ventas y compras"
    assert html =~ "Monedas"
    assert html =~ "Contabilidad y reportes"
    assert html =~ "Módulos listos para construir"
  end

  test "GET /currencies renders currency settings", %{conn: conn} do
    seed_currency_settings()

    conn = get(conn, ~p"/currencies")
    html = html_response(conn, 200)

    assert html =~ ~s(id="currencies-page")
    assert html =~ ~s(id="currency-form")
    assert html =~ ~s(id="default-currency-form")
    assert html =~ ~s(id="remove-currency-CRC")
    assert html =~ "USD / CRC"
    assert html =~ "Obligatoria"
  end

  test "GET /ledger renders ledger workflow", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    bank_account = seed_bank_account(crc)
    seed_transaction(bank_account)

    conn = get(conn, ~p"/ledger?tab=accounts")
    html = html_response(conn, 200)

    assert html =~ ~s(id="ledger-page")
    assert html =~ ~s(id="ledger-dashboard-tab")
    assert html =~ ~s(id="ledger-transactions-tab")
    assert html =~ ~s(id="ledger-accounts-tab")
    assert html =~ ~s(id="ledger-exchange-differences-tab")
    assert html =~ ~s(id="ledger-bank-account-form")
    assert html =~ ~s(id="ledger-transaction-form")
    assert html =~ ~s(id="ledger-exchange-difference-form")
    assert html =~ ~s(id="ledger-bank-major-table")
    assert html =~ ~s(id="ledger-exchange-differences-table")
    assert html =~ ~s(id="ledger-actions-menu")
    assert html =~ ~s(id="ledger-info-button")
    assert html =~ ~s(data-active-ledger-tab="accounts")
    assert html =~ ~s(class="btn btn-primary btn-sm btn-square tooltip tooltip-left")
    assert html =~ ~s(aria-label="Monedas y tipos de cambio")
    assert html =~ ~s(data-exchange-rate="491.92000000")
    assert html =~ "₡ 491.92"
    assert html =~ "Mayor bancos"
    assert html =~ "Saldo cuentas banco"
    assert html =~ "Diferencial cambiario"
    assert html =~ "Tipo cambio compra"
    assert html =~ "Tipo cambio venta"
    assert html =~ "Cuenta corriente"
  end

  test "GET /bank renders bank summary", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    bank_account = seed_bank_account(crc)
    seed_transaction(bank_account, "credit_note", "Nota de crédito bancaria")
    seed_exchange_difference(bank_account)

    conn = get(conn, ~p"/bank")
    html = html_response(conn, 200)

    assert html =~ ~s(id="bank-page")
    assert html =~ ~s(id="bank-summary-table")
    assert html =~ ~s(id="petty-cash-widget")
    assert html =~ ~s(id="petty-cash-form")
    assert html =~ ~s(id="petty-cash-transactions")
    assert html =~ ~s(id="bank-ledger-link")
    assert html =~ "Banco"
    assert html =~ "EGRESOS POR CUENTAS POR PAGAR COMPRAS"
    assert html =~ "INGRESOS POR NOTA DE CRÉDITO DE BANCOS"
    assert html =~ "DIFERENCIAL CAMBIARIO"
    assert html =~ "Caja chica"
    assert html =~ "Agregar"
  end

  test "POST /petty-cash creates a petty cash transaction", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()

    conn =
      post(conn, ~p"/petty-cash", %{
        "petty_cash" => %{
          "details" => "Compra de sellos",
          "amount" => "91920.00",
          "currency_id" => crc.id,
          "transaction_type" => "withdrawal"
        }
      })

    assert redirected_to(conn) == ~p"/bank"

    transaction = Repo.get_by!(PettyCashTransaction, details: "Compra de sellos")
    assert transaction.currency_id == crc.id
    assert Decimal.equal?(transaction.amount, Decimal.new("91920.00"))
    assert Decimal.equal?(transaction.amount_usd, Decimal.new("186.8596519759"))
  end

  test "DELETE /petty-cash/:id removes a petty cash transaction", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    transaction = seed_petty_cash(crc)

    conn = delete(conn, ~p"/petty-cash/#{transaction.id}")

    assert redirected_to(conn) == ~p"/bank"
    refute Repo.get(PettyCashTransaction, transaction.id)
  end

  test "GET /bank keeps petty cash native currency amounts exact", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    seed_petty_cash(crc, Decimal.new("91920.00"))

    conn = get(conn, ~p"/bank")
    html = html_response(conn, 200)

    assert html =~ "₡ 91920"
    refute html =~ "91920.17"
  end

  test "POST /ledger/accounts creates bank account", %{conn: conn} do
    %{usd: usd} = seed_currency_settings()

    conn =
      post(conn, ~p"/ledger/accounts", %{
        "bank_account" => %{
          "name" => "Banco Nacional",
          "current_account_number" => "111111111",
          "customer_account_number" => "222222222",
          "iban" => "CR123",
          "currency_id" => usd.id
        }
      })

    assert redirected_to(conn) == ~p"/ledger?tab=accounts"
    assert Repo.get_by!(BankAccount, name: "Banco Nacional").iban == "CR123"
  end

  test "POST /ledger/transactions creates canonical USD movement", %{conn: conn} do
    %{usd: usd, crc: crc} = seed_currency_settings()
    bank_account = seed_bank_account(crc)

    conn =
      post(conn, ~p"/ledger/transactions", %{
        "ledger_transaction" => %{
          "bank_account_id" => bank_account.id,
          "movement_type" => "deposit_or_transfer_received",
          "transaction_date" => "2026-07-22",
          "amount" => "491.92",
          "currency_id" => usd.id,
          "voucher" => "1",
          "concept" => "Depósito inicial"
        }
      })

    assert redirected_to(conn) == ~p"/ledger?tab=transactions"
    transaction = Repo.get_by!(Transaction, concept: "Depósito inicial")
    assert Decimal.equal?(transaction.amount_usd, Decimal.new("1"))
    assert transaction.currency_id == crc.id
  end

  test "exchange difference result is signed by purchase and sale rate" do
    assert Decimal.equal?(
             Ledger.exchange_difference_result(
               Decimal.new("100"),
               Decimal.new("500"),
               Decimal.new("510")
             ),
             Decimal.new("1000")
           )

    assert Decimal.equal?(
             Ledger.exchange_difference_result(
               Decimal.new("100"),
               Decimal.new("510"),
               Decimal.new("500")
             ),
             Decimal.new("-1000")
           )
  end

  test "POST /ledger/exchange-differences creates exchange result", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    bank_account = seed_bank_account(crc)

    conn =
      post(conn, ~p"/ledger/exchange-differences", %{
        "exchange_difference" => %{
          "bank_account_id" => bank_account.id,
          "transaction_date" => "2026-07-22",
          "foreign_amount" => "100",
          "purchase_exchange_rate" => "500",
          "sale_exchange_rate" => "510",
          "voucher" => "FX-1",
          "concept" => "Venta de dólares"
        }
      })

    assert redirected_to(conn) == ~p"/ledger?tab=exchange-differences"

    exchange_difference = Repo.get_by!(ExchangeDifference, concept: "Venta de dólares")
    assert exchange_difference.currency_id == crc.id
    assert Decimal.equal?(exchange_difference.result_amount, Decimal.new("1000"))
  end

  test "POST /currencies creates a currency and exchange rate", %{conn: conn} do
    seed_currency_settings()

    conn =
      post(conn, ~p"/currencies", %{
        "currency" => %{
          "code" => "eur",
          "name" => "Euro",
          "symbol" => "€",
          "decimal_places" => "2",
          "rate" => "0.85"
        }
      })

    assert redirected_to(conn) == ~p"/currencies"
    assert Repo.get_by!(Currency, code: "EUR")

    eur = Repo.get_by!(Currency, code: "EUR")

    assert Decimal.equal?(
             Repo.get_by!(ExchangeRate, quote_currency_id: eur.id).rate,
             Decimal.new("0.85")
           )
  end

  test "POST /currencies/default sets reporting currency", %{conn: conn} do
    %{crc: crc, organization: organization} = seed_currency_settings()

    conn =
      post(conn, ~p"/currencies/default", %{
        "organization_currency" => %{"currency_id" => crc.id}
      })

    assert redirected_to(conn) == ~p"/currencies"
    assert Repo.reload!(organization).base_currency_id == crc.id

    assert Repo.get_by!(OrganizationCurrency,
             organization_id: organization.id,
             currency_id: crc.id
           ).base
  end

  test "DELETE /currencies/:currency_id removes non-USD currency", %{conn: conn} do
    %{crc: crc, organization: organization} = seed_currency_settings()

    conn = delete(conn, ~p"/currencies/#{crc.id}")

    assert redirected_to(conn) == ~p"/currencies"
    assert Repo.reload!(organization).base_currency_id != crc.id

    refute Repo.get_by(OrganizationCurrency,
             organization_id: organization.id,
             currency_id: crc.id
           )

    assert Repo.get_by!(Currency, code: "CRC")
  end

  test "DELETE /currencies/:currency_id keeps USD required", %{conn: conn} do
    %{usd: usd, organization: organization} = seed_currency_settings()

    conn = delete(conn, ~p"/currencies/#{usd.id}")

    assert redirected_to(conn) == ~p"/currencies"

    assert Repo.get_by!(OrganizationCurrency,
             organization_id: organization.id,
             currency_id: usd.id
           )

    assert Repo.reload!(organization).base_currency_id == usd.id
  end

  defp seed_currency_settings do
    now = DateTime.utc_now(:second)

    usd =
      %Currency{}
      |> Currency.changeset(%{
        code: "USD",
        name: "US Dollar",
        symbol: "$",
        decimal_places: 2,
        activated_at: now
      })
      |> Repo.insert!()

    crc =
      %Currency{}
      |> Currency.changeset(%{
        code: "CRC",
        name: "Costa Rican Colón",
        symbol: "₡",
        decimal_places: 2,
        activated_at: now
      })
      |> Repo.insert!()

    organization =
      %Organization{}
      |> Organization.changeset(%{
        name: "Distribuidora Blanco S.A.",
        legal_name: "Distribuidora Blanco Sociedad Anónima",
        tax_id: "3101234567",
        base_currency_id: usd.id,
        activated_at: now
      })
      |> Repo.insert!()

    for {currency, base?} <- [{usd, true}, {crc, false}] do
      %OrganizationCurrency{}
      |> OrganizationCurrency.changeset(%{
        organization_id: organization.id,
        currency_id: currency.id,
        base: base?,
        activated_at: now
      })
      |> Repo.insert!()
    end

    %ExchangeRate{}
    |> ExchangeRate.changeset(%{
      base_currency_id: usd.id,
      quote_currency_id: crc.id,
      rate: Decimal.new("491.92"),
      as_of: ~U[2026-07-22 00:00:00Z],
      scope: "GLOBAL",
      source: "test"
    })
    |> Repo.insert!()

    %{usd: usd, crc: crc, organization: organization}
  end

  defp seed_bank_account(currency) do
    organization = Repo.one!(Organization)

    %BankAccount{}
    |> BankAccount.changeset(%{
      organization_id: organization.id,
      currency_id: currency.id,
      name: "Banco Nacional",
      current_account_number: "111111111",
      customer_account_number: "222222222",
      iban: "CR123"
    })
    |> Repo.insert!()
  end

  defp seed_transaction(bank_account) do
    seed_transaction(bank_account, "deposit_or_transfer_received", "Depósito inicial")
  end

  defp seed_transaction(bank_account, movement_type, concept) do
    %Transaction{}
    |> Transaction.changeset(%{
      bank_account_id: bank_account.id,
      currency_id: bank_account.currency_id,
      movement_type: movement_type,
      transaction_date: ~D[2026-07-22],
      amount: Decimal.new("491.92"),
      exchange_rate: Decimal.new("491.92"),
      amount_usd: Decimal.new("1"),
      voucher: "1",
      concept: concept
    })
    |> Repo.insert!()
  end

  defp seed_exchange_difference(bank_account) do
    %ExchangeDifference{}
    |> ExchangeDifference.changeset(%{
      bank_account_id: bank_account.id,
      currency_id: bank_account.currency_id,
      transaction_date: ~D[2026-07-22],
      foreign_amount: Decimal.new("100"),
      purchase_exchange_rate: Decimal.new("500"),
      sale_exchange_rate: Decimal.new("510"),
      result_amount: Decimal.new("1000"),
      voucher: "FX-1",
      concept: "Venta de dólares"
    })
    |> Repo.insert!()
  end

  defp seed_petty_cash(currency) do
    seed_petty_cash(currency, Decimal.new("491.92"))
  end

  defp seed_petty_cash(currency, amount) do
    organization = Repo.one!(Organization)

    %PettyCashTransaction{}
    |> PettyCashTransaction.changeset(%{
      organization_id: organization.id,
      currency_id: currency.id,
      details: "Compra de sellos",
      amount: amount,
      exchange_rate: Decimal.new("491.92"),
      amount_usd: Decimal.div(amount, Decimal.new("491.92")),
      transaction_type: "withdrawal"
    })
    |> Repo.insert!()
  end
end
