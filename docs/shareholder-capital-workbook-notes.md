# Shareholder Capital Workbook Notes

Source directory:

`/Users/dblanco/Library/CloudStorage/Dropbox/ERP/PROYECTO D-W/DETALLISTAS Y DISTRIBUIDORAS/12.   CAPITAL ACCIONARIO`

## Files

- `0.1 CAPITAL ACCIONARIO.xlsx`: mayor summary of shareholder capital.
- `3.  CREAR ACCIONISTA.xlsx`: source workflow for shareholder metadata and share subscriptions/payments.

## Source Workbook

Sheet: `AUXILIAR CAPITAL ACIONARIO`

Shareholder metadata:

- Shareholder name
- Identification
- Phone
- Email
- Address
- Company name
- Company legal ID

Capital line columns:

- Date
- Share/security type
- Share value
- Subscription quantity
- Total share capital
- Payments
- Receivable from shareholders

Workbook formulas:

- `capital = share_value * quantity`
- `receivable = capital - payment`

## Mayor Workbook

Sheet: `Hoja1`

Columns:

- Shareholder
- Total share capital
- Payments
- Receivable from shareholders

Phoenix model implication: shareholder records should be shared with dividend distribution. The app combines workbook folders 12 and 13 into one module because dividends depend on shareholder capital participation.
