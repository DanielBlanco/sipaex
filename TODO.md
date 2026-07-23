# SIPAEX TODO

## Estado actual

SIPAEX es una aplicacion Phoenix para ERP multiempresa. La base actual ya incluye:

- Login basico con usuario asociado a una organizacion.
- Semillas para organizacion, usuario `daniel`, monedas y tipos de cambio.
- Dashboard/panel principal compacto para modulos.
- Modulo de monedas con moneda base por organizacion y USD como moneda obligatoria.
- Modulo de cuenta corriente con cuentas bancarias, movimientos, diferencial cambiario y dashboard.
- Modulo de banco con resumen y caja chica.
- Modulo de dividendos/capital accionario con wizard inicial.
- Modulo de gastos.
- Modulo de impuestos con tarifas IVA configurables.
- Modulo de compras/ventas con productos, lineas de factura y busqueda de productos.
- Aislamiento multiempresa reforzado en codigo y base de datos.
- Periodos contables, ejercicios fiscales y eventos auditables.
- Base de libro diario con `journal_entries` y `journal_lines`.

## Ultimos commits relevantes

- `3b3b5c8` - `Build multi-organization accounting foundation`
- `88d3678` - `Add accounting journal foundation`

## Decisiones importantes

- Toda informacion operativa debe estar asociada directa o indirectamente a `organizations`.
- Las consultas y formularios deben usar siempre la organizacion activa del usuario.
- Los IDs recibidos desde formularios deben validarse contra la organizacion activa.
- USD se mantiene como moneda obligatoria y canonica para almacenamiento financiero.
- La moneda base de la organizacion se usa para reportes y visualizacion.
- Los montos financieros deben conservar precision suficiente en base de datos.
- Los periodos contables se validan por fecha efectiva del movimiento, no por `inserted_at`.
- Si existe un periodo para la fecha, solo `open` y `closing` permiten escritura.
- Por ahora, si no existe periodo configurado para una fecha, la operacion sigue permitida para no bloquear el spike.
- Los asientos contables posteados no deberian borrarse; deben revertirse con asientos `reversal`.

## Completado

- [x] Fase 1: scope organizacional explicito.
- [x] Fase 2: validaciones de pertenencia en codigo.
- [x] Fase 3: refuerzo en base de datos con `organization_id`, FKs compuestas, indices y checks.
- [x] Fase 4: ejercicios fiscales, periodos contables y eventos.
- [x] Fase 5 parcial: bloqueo de escrituras operativas en periodos cerrados/bloqueados.
- [x] Fase 6 parcial: tablas de libro diario, lineas de asiento, balanceo y balance de comprobacion inicial.

## Pendiente principal

- [ ] Definir y crear catalogo de cuentas (`chart_of_accounts`).
- [ ] Definir mapeos contables por modulo operativo.
- [ ] Hacer que compras, gastos, banco, caja chica, dividendos e impuestos generen asientos automaticamente.
- [ ] Implementar ajustes posteriores a periodo cerrado con permisos y auditoria.
- [ ] Implementar cierre mensual.
- [ ] Implementar cierre anual:
  - cerrar ingresos y gastos;
  - trasladar resultado acumulado;
  - generar asientos `closing` trazables.
- [ ] Implementar reversos contables controlados.
- [ ] Crear UI para ejercicios fiscales, periodos, cierres y libro diario.
- [ ] Crear reportes contables por rango:
  - saldo inicial;
  - balance de comprobacion;
  - estado de resultados;
  - balance general.

## Proximo paso recomendado

Crear el catalogo de cuentas antes de conectar mas modulos.

Modelo sugerido:

- `accounting_accounts`
  - `id`
  - `organization_id`
  - `code`
  - `name`
  - `account_type`
  - `normal_balance`
  - `parent_id`
  - `active`

Tipos iniciales:

- `asset`
- `liability`
- `equity`
- `income`
- `expense`

Luego agregar una tabla de mapeos contables:

- `accounting_mappings`
  - `organization_id`
  - `module`
  - `event`
  - `account_id`

Ejemplos de mapeo:

- Compra contado:
  - Debe: inventario o gasto
  - Debe: IVA acreditable, si aplica
  - Haber: banco o caja chica
- Compra credito:
  - Debe: inventario o gasto
  - Debe: IVA acreditable, si aplica
  - Haber: cuentas por pagar
- Venta:
  - Debe: banco o cuentas por cobrar
  - Haber: ingresos por ventas
  - Haber: IVA por pagar, si aplica

## Comandos utiles

```bash
docker compose up -d
mix ecto.setup
mix phx.server
mix test
mix precommit
```

Servidor local:

```bash
mix phx.server
```

URL:

```text
http://localhost:4000
```

Usuario seed:

```text
daniel.blancorojas@gmail.com
```

La clave seed esta en `priv/repo/seeds.exs`.

## Documento largo

El plan detallado de aislamiento multiempresa y periodos contables esta en:

- `docs/data-isolation-accounting-periods-plan.md`
