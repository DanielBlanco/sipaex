# Ledger Workbook Notes

Source workbook:

`/Users/dblanco/Library/CloudStorage/Dropbox/ERP/PROYECTO D-W/DETALLISTAS Y DISTRIBUIDORAS/11.  CUENTA CORRIENTE/1.  CREAR BANCO.xlsx`

Use this workbook as product workflow reference for the ledger / current account module. Do not copy the workbook shape directly into the database model.

## Sheets

The workbook has six sheets:

- `DEPÓSITOS Y TRANSF. RECIBIDAS`
- `CHEQUES Y TRANSF. EMITIDAS`
- `NOTAS DE CRÉDITO`
- `NOTAS DE DÉBITO`
- `SALDO ACTUAL`
- `DIFERENCIAL CAMBIARIO`

## Shared Bank Account Metadata

The first transaction sheet owns the bank account references, and the other sheets read them through formulas:

- Bank name
- Current account number
- Customer account number
- IBAN
- Currency label

Phoenix model implication: keep bank account metadata in one table, then attach all ledger movements to that bank account. Avoid duplicating account references per movement type.

## Movement Sheets

The first four sheets represent movement classes:

- Deposits and received transfers: money in.
- Checks and emitted transfers: money out.
- Credit notes: money in.
- Debit notes: money out.

Each movement sheet uses the same transaction columns:

- Date
- Amount
- Voucher / comprobante
- Concept
- Exchange rate
- Total in national currency

Workbook formula:

`total_in_national_currency = amount * exchange_rate`

Phoenix model implication: use one ledger transaction table with a `movement_type` or `direction` rather than four separate transaction tables. Store canonical amounts in USD per SIPAE currency policy, keep entered currency/rate metadata for display and audit, and derive reporting amounts from the organization default currency.

Suggested movement types:

- `deposit_received`
- `transfer_received`
- `check_issued`
- `transfer_issued`
- `credit_note`
- `debit_note`

Or, if simpler for the first implementation:

- `deposit_or_transfer_received`
- `check_or_transfer_issued`
- `credit_note`
- `debit_note`

## Current Balance

The `SALDO ACTUAL` sheet derives balance from movement totals:

`deposits_received - checks_transfers_issued + credit_notes - debit_notes`

Phoenix model implication: current balance should be derived from ledger transactions, not stored as a mutable fact except for optional snapshots/reconciliations later.

## Exchange Difference

The `DIFERENCIAL CAMBIARIO` sheet tracks gains and losses from exchange-rate spread.

Columns:

- Date
- Foreign currency amount
- Voucher / comprobante
- Concept
- Sell exchange rate
- Buy exchange rate
- FX result in national currency

Workbook formula:

`fx_result = (foreign_amount * sell_rate) - (foreign_amount * buy_rate)`

Positive results are exchange-rate gains. Negative results are exchange-rate losses.

Phoenix model implication: model FX adjustment as a derived or explicit ledger adjustment tied to a bank account and currency pair. Keep buy/sell rates and amount as source inputs.

## First Ledger Module Scope

For the first SIPAE ledger module, implement:

1. Bank account create/edit/list.
2. Ledger transaction list/create for the four movement classes.
3. Derived current balance per bank account.
4. USD canonical storage with reporting display using default organization currency.
5. Exchange-rate fields on non-USD entries.
6. FX difference screen or derived summary after the basic movement flow works.
