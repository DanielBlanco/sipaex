# Dividend Workbook Notes

Source directory:

`/Users/dblanco/Library/CloudStorage/Dropbox/ERP/PROYECTO D-W/DETALLISTAS Y DISTRIBUIDORAS/13.   DISTRIBUCIÓN DE DIVIDENDOS`

Files with `MAYOR` in the title are summary/aggregator files. Source data comes from the non-`MAYOR` workbooks.

The app combines this folder with `12. CAPITAL ACCIONARIO` in one `Capital y dividendos` module because dividend participation is derived from shareholder capital.

## Files

- `0.1.  MAYOR GENERAL DIVIDENDOS.xlsx`: summary of shareholders, dividends, payments, and payable balances.
- `1.  CREAR BENEFICIARIO DE DIVIDENDOS.xlsx`: source workflow for shareholder/beneficiary metadata and dividend auxiliary lines.

## Source Workbook

Sheet: `AUXILIAR DIVIDENDOS`

Beneficiary metadata:

- Company name and identification
- Shareholder name and identification
- Shareholder email
- Shareholder phone
- Shareholder address

Dividend line columns:

- Date
- Declaration amount
- Total share capital
- Shareholder capital
- Shareholder participation percentage
- Shareholder dividend amount
- Dividend payment
- Dividends payable

Workbook formulas:

- `participation_percent = shareholder_capital / total_share_capital`
- `shareholder_dividend = declaration_amount * participation_percent`
- `payable = shareholder_dividend - payment`

## Mayor Workbook

Sheet: `Hoja1`

Columns:

- Shareholder
- Dividends
- Payments
- Dividends payable

Phoenix model implication: store beneficiaries separately from dividend entries. Derive the mayor summary from entries instead of storing summary balances as mutable facts.
