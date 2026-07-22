defmodule SipaexWeb.PageControllerTest do
  use SipaexWeb.ConnCase

  alias Sipaex.Common.Currency
  alias Sipaex.Common.ExchangeRate
  alias Sipaex.Bank.PettyCashTransaction
  alias Sipaex.Commerce.Entry, as: CommerceEntry
  alias Sipaex.Commerce.Party
  alias Sipaex.Dividends.Beneficiary
  alias Sipaex.Dividends.CapitalEntry
  alias Sipaex.Dividends.Entry
  alias Sipaex.Expenses.Entry, as: ExpenseEntry
  alias Sipaex.Expenses.FinancialEntry
  alias Sipaex.Expenses.Provider, as: ExpenseProvider
  alias Sipaex.Ledger
  alias Sipaex.Ledger.BankAccount
  alias Sipaex.Ledger.ExchangeDifference
  alias Sipaex.Ledger.Transaction
  alias Sipaex.Organizations.Organization
  alias Sipaex.Organizations.OrganizationCurrency
  alias Sipaex.Repo
  alias Sipaex.Taxes.IncomeTaxEntry
  alias Sipaex.Taxes.VatPeriod
  alias Sipaex.Taxes.VatRate

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
    seed_currency_settings()

    conn = get(conn, ~p"/dashboard")
    html = html_response(conn, 200)

    assert html =~ ~s(id="app-dashboard")
    assert html =~ ~s(id="dashboard-currencies-link")
    assert html =~ ~s(id="dashboard-ledger-link")
    assert html =~ ~s(id="dashboard-bank-link")
    assert html =~ ~s(id="dashboard-dividends-link")
    assert html =~ ~s(id="dashboard-expenses-link")
    assert html =~ ~s(id="dashboard-taxes-link")
    assert html =~ ~s(id="dashboard-purchases-link")
    assert html =~ ~s(id="dashboard-sales-link")
    assert html =~ ~s(id="app-organization-summary")
    refute html =~ ~s(id="app-topnav")
    assert html =~ "Panel"
    assert html =~ "Distribuidora Blanco Sociedad Anónima"
    assert html =~ "Cédula jurídica: 3101234567"
    assert html =~ "Moneda base: USD"
    assert html =~ "Monedas"
    assert html =~ "Cuenta corriente"
    assert html =~ "Banco"
    assert html =~ "Capital y dividendos"
    assert html =~ "Gastos"
    assert html =~ "Impuestos"
    assert html =~ "Ventas y compras"
    assert html =~ "Compras"
    assert html =~ "Ventas"
    assert html =~ "Contabilidad y reportes"
    assert html =~ "Estado de resultados"
  end

  test "GET /currencies renders currency settings", %{conn: conn} do
    seed_currency_settings()

    conn = get(conn, ~p"/currencies")
    html = html_response(conn, 200)

    assert html =~ ~s(id="currencies-page")
    assert html =~ ~s(id="app-organization-summary")
    assert html =~ ~s(id="currencies-panel-link")
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
    assert html =~ ~s(id="app-organization-summary")
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
    assert html =~ ~s(id="ledger-panel-link")
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
    assert html =~ ~s(id="app-organization-summary")
    assert html =~ ~s(id="bank-summary-table")
    assert html =~ ~s(id="petty-cash-widget")
    assert html =~ ~s(id="petty-cash-form")
    assert html =~ ~s(id="petty-cash-transactions")
    assert html =~ ~s(id="bank-panel-link")
    assert html =~ ~s(id="bank-ledger-link")
    assert html =~ "Banco"
    assert html =~ "EGRESOS POR CUENTAS POR PAGAR COMPRAS"
    assert html =~ "INGRESOS POR NOTA DE CRÉDITO DE BANCOS"
    assert html =~ "DIFERENCIAL CAMBIARIO"
    assert html =~ "EGRESOS POR PAGO DE DIVIDENDOS"
    assert html =~ "Caja chica"
    assert html =~ "Agregar"
  end

  test "GET /dividends renders dividend workflow", %{conn: conn} do
    seed_currency_settings()
    beneficiary = seed_dividend_beneficiary()
    seed_capital_entry(beneficiary)
    seed_dividend_entry(beneficiary)

    conn = get(conn, ~p"/dividends?tab=entries")
    html = html_response(conn, 200)

    assert html =~ ~s(id="dividends-page")
    assert html =~ ~s(id="dividends-wizard-tab")
    assert html =~ ~s(id="dividends-dashboard-tab")
    assert html =~ ~s(id="dividends-shareholders-tab")
    assert html =~ ~s(id="dividends-capital-tab")
    assert html =~ ~s(id="dividends-entries-tab")
    assert html =~ ~s(id="shareholder-capital-major-table")
    assert html =~ ~s(id="dividends-major-table")
    assert html =~ ~s(id="dividend-beneficiaries-table")
    assert html =~ ~s(id="shareholder-capital-entries-table")
    assert html =~ ~s(id="dividend-entries-table")
    assert html =~ ~s(id="dividend-beneficiary-form")
    assert html =~ ~s(id="capital-entry-form")
    assert html =~ ~s(id="dividend-entry-form")
    assert html =~ ~s(id="dividends-panel-link")
    assert html =~ ~s(id="dividends-wizard-help")
    assert html =~ ~s(id="wizard-add-shareholder")
    assert html =~ ~s(id="wizard-add-capital")
    assert html =~ ~s(id="wizard-review-capital")
    assert html =~ ~s(id="wizard-add-dividend")
    assert html =~ ~s(id="wizard-review-summary")
    assert html =~ ~s(id="dividends-dashboard-help")
    assert html =~ ~s(id="dividends-shareholders-help")
    assert html =~ ~s(id="dividends-capital-help")
    assert html =~ ~s(id="dividends-entries-help")
    assert html =~ ~s(data-active-dividends-tab="entries")
    assert html =~ "Capital y dividendos"
    assert html =~ "Accionista Uno"
    assert html =~ "Capital accionario"
    assert html =~ "Dividendos por pagar"
  end

  test "GET /dividends defaults to wizard", %{conn: conn} do
    seed_currency_settings()

    conn = get(conn, ~p"/dividends")
    html = html_response(conn, 200)

    assert html =~ ~s(data-active-dividends-tab="wizard")
    assert html =~ "Guía de capital y dividendos"
  end

  test "GET /expenses renders expenses workflow", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    provider = seed_expense_provider("administrative")
    financial_provider = seed_expense_provider("financial", "Banco de Prueba")
    seed_expense_entry(provider, crc)
    seed_financial_expense_entry(financial_provider, crc)

    conn = get(conn, ~p"/expenses?tab=financial")
    html = html_response(conn, 200)

    assert html =~ ~s(id="expenses-page")
    assert html =~ ~s(id="expenses-dashboard-tab")
    assert html =~ ~s(id="expenses-providers-tab")
    assert html =~ ~s(id="expenses-entries-tab")
    assert html =~ ~s(id="expenses-financial-tab")
    assert html =~ ~s(id="expense-providers-table")
    assert html =~ ~s(id="expenses-major-table")
    assert html =~ ~s(id="financial-expenses-major-table")
    assert html =~ ~s(id="expense-entries-table")
    assert html =~ ~s(id="financial-expense-entries-table")
    assert html =~ ~s(id="expense-provider-form")
    assert html =~ ~s(id="expense-entry-form")
    assert html =~ ~s(id="financial-expense-entry-form")
    assert html =~ ~s(id="expenses-panel-link")
    assert html =~ ~s(id="expenses-dashboard-help")
    assert html =~ ~s(id="expenses-providers-help")
    assert html =~ ~s(id="expenses-entries-help")
    assert html =~ ~s(id="expenses-financial-help")
    assert html =~ ~s(data-active-expenses-tab="financial")
    assert html =~ ~s(data-exchange-rate="491.92000000")
    assert html =~ "Gastos"
    assert html =~ "Proveedor Administrativo"
    assert html =~ "Banco de Prueba"
  end

  test "GET /purchases renders purchase workflow", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    vat_rate = seed_vat_rate("General 13%", "0.13")
    party = seed_commerce_party("purchase", "Proveedor Compras")
    seed_commerce_entry("purchase", party, crc, vat_rate)

    conn = get(conn, ~p"/purchases?tab=entries")
    html = html_response(conn, 200)

    assert html =~ ~s(id="purchase-page")
    assert html =~ ~s(id="purchase-parties-table")
    assert html =~ ~s(id="purchase-entries-table")
    assert html =~ ~s(id="purchase-party-form")
    assert html =~ ~s(id="purchase-entry-form")
    assert html =~ "Compras"
    assert html =~ "Proveedor Compras"
  end

  test "GET /sales renders sales workflow", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    vat_rate = seed_vat_rate("General 13%", "0.13")
    party = seed_commerce_party("sale", "Cliente Ventas")
    seed_commerce_entry("sale", party, crc, vat_rate)

    conn = get(conn, ~p"/sales?tab=entries")
    html = html_response(conn, 200)

    assert html =~ ~s(id="sale-page")
    assert html =~ ~s(id="sale-parties-table")
    assert html =~ ~s(id="sale-entries-table")
    assert html =~ ~s(id="sale-party-form")
    assert html =~ ~s(id="sale-entry-form")
    assert html =~ "Ventas"
    assert html =~ "Cliente Ventas"
  end

  test "POST /purchases/entries creates VAT purchase entry", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    vat_rate = seed_vat_rate("General 13%", "0.13")
    party = seed_commerce_party("purchase", "Proveedor Compras")

    conn =
      post(conn, ~p"/purchases/entries", %{
        "commerce_entry" => %{
          "party_id" => party.id,
          "currency_id" => crc.id,
          "vat_rate_id" => vat_rate.id,
          "entry_date" => "2026-07-22",
          "document_number" => "C-1",
          "exempt_amount" => "0",
          "taxable_amount" => "491920",
          "payment" => "0",
          "concept" => "Compra gravada"
        }
      })

    assert redirected_to(conn) == ~p"/purchases?tab=entries"
    entry = Repo.get_by!(CommerceEntry, document_number: "C-1")
    assert entry.entry_type == "purchase"
    assert Decimal.equal?(entry.vat_amount_usd, Decimal.new("130"))
  end

  test "POST /sales/entries creates VAT sales entry", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    vat_rate = seed_vat_rate("General 13%", "0.13")
    party = seed_commerce_party("sale", "Cliente Ventas")

    conn =
      post(conn, ~p"/sales/entries", %{
        "commerce_entry" => %{
          "party_id" => party.id,
          "currency_id" => crc.id,
          "vat_rate_id" => vat_rate.id,
          "entry_date" => "2026-07-22",
          "document_number" => "V-1",
          "exempt_amount" => "0",
          "taxable_amount" => "491920",
          "payment" => "0",
          "concept" => "Venta gravada"
        }
      })

    assert redirected_to(conn) == ~p"/sales?tab=entries"
    entry = Repo.get_by!(CommerceEntry, document_number: "V-1")
    assert entry.entry_type == "sale"
    assert Decimal.equal?(entry.vat_amount_usd, Decimal.new("130"))
  end

  test "POST /expenses/providers creates provider", %{conn: conn} do
    seed_currency_settings()

    conn =
      post(conn, ~p"/expenses/providers", %{
        "provider" => %{
          "category" => "sales",
          "name" => "Proveedor Ventas",
          "identification" => "3101222222",
          "email" => "ventas@example.com",
          "phone" => "2222-2222",
          "address" => "San José",
          "contact" => "Laura",
          "payment_terms_days" => "30"
        }
      })

    assert redirected_to(conn) == ~p"/expenses?tab=providers"
    assert Repo.get_by!(ExpenseProvider, name: "Proveedor Ventas").category == "sales"
  end

  test "POST /expenses/entries creates calculated expense entry", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    provider = seed_expense_provider("administrative")

    conn =
      post(conn, ~p"/expenses/entries", %{
        "expense_entry" => %{
          "provider_id" => provider.id,
          "currency_id" => crc.id,
          "entry_date" => "2026-07-22",
          "invoice_number" => "FAC-1",
          "exempt_amount" => "100",
          "taxable_amount" => "130",
          "tax_rate" => "0.13",
          "credit_note" => "10",
          "debit_note" => "5",
          "payment" => "50",
          "voucher" => "G-1",
          "concept" => "Servicios administrativos"
        }
      })

    assert redirected_to(conn) == ~p"/expenses?tab=entries"

    entry = Repo.get_by!(ExpenseEntry, invoice_number: "FAC-1")
    assert entry.category == "administrative"
    assert Decimal.equal?(entry.total_usd, Decimal.new("0.4917466255"))
    assert Decimal.equal?(entry.payment_usd, Decimal.new("0.1016425435"))
  end

  test "POST /expenses/financial-entries creates financial expense entry", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    provider = seed_expense_provider("financial", "Banco Financiero")

    conn =
      post(conn, ~p"/expenses/financial-entries", %{
        "financial_entry" => %{
          "provider_id" => provider.id,
          "currency_id" => crc.id,
          "entry_date" => "2026-07-22",
          "loan_amount" => "1000000",
          "principal_payment" => "200000",
          "financial_expense" => "50000",
          "credit_note" => "1000",
          "debit_note" => "500",
          "financial_expense_payment" => "10000",
          "voucher" => "GF-1",
          "concept" => "Intereses préstamo"
        }
      })

    assert redirected_to(conn) == ~p"/expenses?tab=financial"

    entry = Repo.get_by!(FinancialEntry, concept: "Intereses préstamo")
    assert Decimal.equal?(entry.loan_payable_usd, Decimal.new("1626.2806960481"))
    assert Decimal.equal?(entry.financial_expense_payable_usd, Decimal.new("80.2976093674"))
  end

  test "GET /taxes renders taxes workflow", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    seed_income_tax_entry(crc)
    seed_vat_period(crc)

    conn = get(conn, ~p"/taxes?tab=vat")
    html = html_response(conn, 200)

    assert html =~ ~s(id="taxes-page")
    assert html =~ ~s(id="taxes-dashboard-tab")
    assert html =~ ~s(id="taxes-vat-rates-tab")
    assert html =~ ~s(id="taxes-income-tab")
    assert html =~ ~s(id="taxes-vat-tab")
    assert html =~ ~s(id="vat-rates-table")
    assert html =~ ~s(id="income-tax-major-table")
    assert html =~ ~s(id="vat-major-table")
    assert html =~ ~s(id="income-tax-entries-table")
    assert html =~ ~s(id="vat-periods-table")
    assert html =~ ~s(id="vat-rate-form")
    assert html =~ "Tarifa (%)"
    assert html =~ ~s(id="income-tax-entry-form")
    assert html =~ ~s(id="vat-period-form")
    assert html =~ ~s(id="taxes-panel-link")
    assert html =~ ~s(id="taxes-dashboard-help")
    assert html =~ ~s(id="taxes-vat-rates-help")
    assert html =~ ~s(id="taxes-income-help")
    assert html =~ ~s(id="taxes-vat-help")
    assert html =~ ~s(data-active-taxes-tab="vat")
    assert html =~ ~s(data-exchange-rate="491.92000000")
    assert html =~ "Impuestos"
    assert html =~ "Tarifas IVA"
    assert html =~ "toggle-vat-rate-"
    assert html =~ "Renta"
    assert html =~ "IVA"
    refute html =~ "<th>País</th>"
    refute html =~ "<th>Nombre</th>"
  end

  test "POST /taxes/vat-rates creates VAT rate", %{conn: conn} do
    seed_currency_settings()

    conn =
      post(conn, ~p"/taxes/vat-rates", %{
        "vat_rate" => %{
          "rate" => "7",
          "description" => "Tarifa general Panamá"
        }
      })

    assert redirected_to(conn) == ~p"/taxes?tab=vat-rates"

    rate = Repo.get_by!(VatRate, name: "IVA 7.00%")
    assert rate.country_code == "CR"
    assert Decimal.equal?(rate.rate, Decimal.new("0.07"))
    assert rate.active
  end

  test "PUT /taxes/vat-rates/:id/toggle toggles VAT rate", %{conn: conn} do
    seed_currency_settings()
    rate = seed_vat_rate()

    conn = put(conn, ~p"/taxes/vat-rates/#{rate.id}/toggle")

    assert redirected_to(conn) == ~p"/taxes?tab=vat-rates"
    refute Repo.reload!(rate).active

    conn = put(conn, ~p"/taxes/vat-rates/#{rate.id}/toggle")

    assert redirected_to(conn) == ~p"/taxes?tab=vat-rates"
    assert Repo.reload!(rate).active
  end

  test "PUT /taxes/vat-rates/:id/toggle keeps exempt VAT active", %{conn: conn} do
    seed_currency_settings()
    exempt_rate = seed_vat_rate("Exento", "0")

    conn = put(conn, ~p"/taxes/vat-rates/#{exempt_rate.id}/toggle")

    assert redirected_to(conn) == ~p"/taxes?tab=vat-rates"
    assert Repo.reload!(exempt_rate).active
  end

  test "POST /taxes/income-tax creates calculated income tax entry", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()

    conn =
      post(conn, ~p"/taxes/income-tax", %{
        "income_tax_entry" => %{
          "currency_id" => crc.id,
          "entry_date" => "2026-07-22",
          "fiscal_period" => "2026",
          "tax_amount" => "491920",
          "payment" => "91920",
          "voucher" => "REN-1",
          "concept" => "Impuesto renta 2026"
        }
      })

    assert redirected_to(conn) == ~p"/taxes?tab=income"

    entry = Repo.get_by!(IncomeTaxEntry, fiscal_period: "2026")
    assert Decimal.equal?(entry.tax_amount_usd, Decimal.new("1000"))
    assert Decimal.equal?(entry.payment_usd, Decimal.new("186.8596519759"))
    assert Decimal.equal?(entry.payable_usd, Decimal.new("813.1403480241"))
  end

  test "POST /taxes/vat-periods creates calculated VAT period", %{conn: conn} do
    %{crc: crc} = seed_currency_settings()
    vat_rate = seed_vat_rate("General 13%", "0.13")
    purchase_party = seed_commerce_party("purchase", "Proveedor IVA")
    sale_party = seed_commerce_party("sale", "Cliente IVA")
    expense_provider = seed_expense_provider("administrative", "Proveedor Gasto IVA")

    seed_commerce_entry("sale", sale_party, crc, vat_rate, "VENTA-IVA", Decimal.new("1000"))

    seed_commerce_entry(
      "purchase",
      purchase_party,
      crc,
      vat_rate,
      "COMPRA-IVA",
      Decimal.new("153.8461538462")
    )

    seed_expense_entry(expense_provider, crc, Decimal.new("10"))

    conn =
      post(conn, ~p"/taxes/vat-periods", %{
        "vat_period" => %{
          "currency_id" => crc.id,
          "period_month" => "7",
          "period_year" => "2026",
          "payment" => "50000",
          "voucher" => "IVA-1",
          "concept" => "IVA enero"
        }
      })

    assert redirected_to(conn) == ~p"/taxes?tab=vat"

    period = Repo.get_by!(VatPeriod, period_month: 7, period_year: 2026)
    assert Decimal.equal?(period.debit_sales_usd, Decimal.new("130.0000000000"))
    assert Decimal.equal?(period.credit_purchases_usd, Decimal.new("20.0000000000"))
    assert Decimal.equal?(period.credit_expenses_usd, Decimal.new("10"))
    assert Decimal.equal?(period.net_vat_usd, Decimal.new("100.0000000000"))
    assert Decimal.equal?(period.payment_usd, Decimal.new("101.6425435030"))
    assert Decimal.equal?(period.payable_usd, Decimal.new("-1.6425435030"))
  end

  test "POST /dividends/beneficiaries creates beneficiary", %{conn: conn} do
    seed_currency_settings()

    conn =
      post(conn, ~p"/dividends/beneficiaries", %{
        "beneficiary" => %{
          "name" => "Accionista Uno",
          "identification" => "101010101",
          "email" => "accionista@example.com",
          "phone" => "2222-2222",
          "address" => "San José"
        }
      })

    assert redirected_to(conn) == ~p"/dividends?tab=beneficiaries"
    assert Repo.get_by!(Beneficiary, name: "Accionista Uno").identification == "101010101"
  end

  test "POST /dividends/capital-entries creates calculated capital entry", %{conn: conn} do
    seed_currency_settings()
    beneficiary = seed_dividend_beneficiary()

    conn =
      post(conn, ~p"/dividends/capital-entries", %{
        "capital_entry" => %{
          "beneficiary_id" => beneficiary.id,
          "entry_date" => "2026-07-22",
          "share_type" => "ACCIONES COMUNES",
          "share_value_usd" => "10000",
          "quantity" => "2",
          "payment_usd" => "15000",
          "voucher" => "CAP-1",
          "concept" => "Suscripción"
        }
      })

    assert redirected_to(conn) == ~p"/dividends?tab=capital"

    entry = Repo.get_by!(CapitalEntry, concept: "Suscripción")
    assert Decimal.equal?(entry.capital_usd, Decimal.new("20000"))
    assert Decimal.equal?(entry.receivable_usd, Decimal.new("5000"))
  end

  test "POST /dividends/entries creates calculated dividend entry", %{conn: conn} do
    seed_currency_settings()
    beneficiary = seed_dividend_beneficiary()
    seed_capital_entry(beneficiary)

    conn =
      post(conn, ~p"/dividends/entries", %{
        "dividend_entry" => %{
          "beneficiary_id" => beneficiary.id,
          "entry_date" => "2026-07-22",
          "declaration_amount_usd" => "1000",
          "payment_usd" => "150",
          "voucher" => "DIV-1",
          "concept" => "Declaratoria"
        }
      })

    assert redirected_to(conn) == ~p"/dividends?tab=entries"

    entry = Repo.get_by!(Entry, concept: "Declaratoria")
    assert Decimal.equal?(entry.participation_percent, Decimal.new("1"))
    assert Decimal.equal?(entry.shareholder_dividend_usd, Decimal.new("1000"))
    assert Decimal.equal?(entry.payable_usd, Decimal.new("850"))
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

  defp seed_dividend_beneficiary do
    organization = Repo.one!(Organization)

    %Beneficiary{}
    |> Beneficiary.changeset(%{
      organization_id: organization.id,
      name: "Accionista Uno",
      identification: "101010101",
      email: "accionista@example.com",
      phone: "2222-2222",
      address: "San José"
    })
    |> Repo.insert!()
  end

  defp seed_capital_entry(beneficiary) do
    %CapitalEntry{}
    |> CapitalEntry.changeset(%{
      beneficiary_id: beneficiary.id,
      entry_date: ~D[2026-07-22],
      share_type: "ACCIONES COMUNES",
      share_value_usd: Decimal.new("10000"),
      quantity: 2,
      capital_usd: Decimal.new("20000"),
      payment_usd: Decimal.new("15000"),
      receivable_usd: Decimal.new("5000"),
      voucher: "CAP-1",
      concept: "Suscripción"
    })
    |> Repo.insert!()
  end

  defp seed_dividend_entry(beneficiary) do
    %Entry{}
    |> Entry.changeset(%{
      beneficiary_id: beneficiary.id,
      entry_date: ~D[2026-07-22],
      declaration_amount_usd: Decimal.new("1000"),
      total_share_capital_usd: Decimal.new("5000"),
      shareholder_capital_usd: Decimal.new("1000"),
      participation_percent: Decimal.new("0.2"),
      shareholder_dividend_usd: Decimal.new("200"),
      payment_usd: Decimal.new("150"),
      payable_usd: Decimal.new("50"),
      voucher: "DIV-1",
      concept: "Declaratoria"
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

  defp seed_expense_provider(category, name \\ "Proveedor Administrativo") do
    organization = Repo.one!(Organization)

    %ExpenseProvider{}
    |> ExpenseProvider.changeset(%{
      organization_id: organization.id,
      category: category,
      name: name,
      identification: "#{category}-3101000000",
      email: "#{category}@example.com",
      phone: "2222-0000",
      contact: "Contacto",
      payment_terms_days: 30
    })
    |> Repo.insert!()
  end

  defp seed_expense_entry(provider, currency, tax_amount \\ Decimal.new("0.26")) do
    %ExpenseEntry{}
    |> ExpenseEntry.changeset(%{
      provider_id: provider.id,
      currency_id: currency.id,
      category: provider.category,
      entry_date: ~D[2026-07-22],
      invoice_number: "FAC-TEST",
      exempt_amount_usd: Decimal.new("1"),
      taxable_amount_usd: Decimal.new("2"),
      tax_rate: Decimal.new("0.13"),
      tax_amount_usd: tax_amount,
      credit_note_usd: Decimal.new("0"),
      debit_note_usd: Decimal.new("0"),
      total_usd: Decimal.new("3.26"),
      payment_usd: Decimal.new("1"),
      payable_usd: Decimal.new("2.26"),
      exchange_rate: Decimal.new("491.92"),
      concept: "Gasto de prueba"
    })
    |> Repo.insert!()
  end

  defp seed_commerce_party(entry_type, name) do
    organization = Repo.one!(Organization)

    %Party{}
    |> Party.changeset(%{
      organization_id: organization.id,
      party_type: entry_type,
      name: name,
      identification: "#{entry_type}-3101000000"
    })
    |> Repo.insert!()
  end

  defp seed_commerce_entry(
         entry_type,
         party,
         currency,
         vat_rate,
         document_number \\ "DOC-TEST",
         taxable_amount_usd \\ Decimal.new("100")
       ) do
    vat_amount = Decimal.mult(taxable_amount_usd, vat_rate.rate)
    total = Decimal.add(taxable_amount_usd, vat_amount)

    %CommerceEntry{}
    |> CommerceEntry.changeset(%{
      party_id: party.id,
      currency_id: currency.id,
      vat_rate_id: vat_rate.id,
      entry_type: entry_type,
      entry_date: ~D[2026-07-22],
      document_number: document_number,
      exempt_amount_usd: Decimal.new("0"),
      taxable_amount_usd: taxable_amount_usd,
      vat_rate: vat_rate.rate,
      vat_amount_usd: vat_amount,
      total_usd: total,
      payment_usd: Decimal.new("0"),
      balance_usd: total,
      exchange_rate: Decimal.new("491.92"),
      concept: "Documento de prueba"
    })
    |> Repo.insert!()
  end

  defp seed_financial_expense_entry(provider, currency) do
    %FinancialEntry{}
    |> FinancialEntry.changeset(%{
      provider_id: provider.id,
      currency_id: currency.id,
      entry_date: ~D[2026-07-22],
      loan_amount_usd: Decimal.new("100"),
      principal_payment_usd: Decimal.new("10"),
      financial_expense_usd: Decimal.new("5"),
      credit_note_usd: Decimal.new("1"),
      debit_note_usd: Decimal.new("0"),
      net_financial_expense_usd: Decimal.new("4"),
      financial_expense_payment_usd: Decimal.new("2"),
      loan_payable_usd: Decimal.new("90"),
      financial_expense_payable_usd: Decimal.new("2"),
      exchange_rate: Decimal.new("491.92"),
      concept: "Gasto financiero de prueba"
    })
    |> Repo.insert!()
  end

  defp seed_income_tax_entry(currency) do
    organization = Repo.one!(Organization)

    %IncomeTaxEntry{}
    |> IncomeTaxEntry.changeset(%{
      organization_id: organization.id,
      currency_id: currency.id,
      entry_date: ~D[2026-07-22],
      fiscal_period: "2025",
      tax_amount_usd: Decimal.new("100"),
      payment_usd: Decimal.new("25"),
      payable_usd: Decimal.new("75"),
      exchange_rate: Decimal.new("491.92"),
      voucher: "REN-TEST",
      concept: "Renta prueba"
    })
    |> Repo.insert!()
  end

  defp seed_vat_period(currency) do
    organization = Repo.one!(Organization)

    %VatPeriod{}
    |> VatPeriod.changeset(%{
      organization_id: organization.id,
      currency_id: currency.id,
      period_month: 1,
      period_year: 2025,
      debit_sales_usd: Decimal.new("50"),
      credit_purchases_usd: Decimal.new("10"),
      credit_expenses_usd: Decimal.new("5"),
      net_vat_usd: Decimal.new("35"),
      payment_usd: Decimal.new("15"),
      payable_usd: Decimal.new("20"),
      exchange_rate: Decimal.new("491.92"),
      voucher: "IVA-TEST",
      concept: "IVA prueba"
    })
    |> Repo.insert!()
  end

  defp seed_vat_rate(name \\ "Especial 15%", rate \\ "0.15") do
    organization = Repo.one!(Organization)

    %VatRate{}
    |> VatRate.changeset(%{
      organization_id: organization.id,
      country_code: "CR",
      name: name,
      rate: Decimal.new(rate),
      description: "Tarifa especial",
      active: true
    })
    |> Repo.insert!()
  end
end
