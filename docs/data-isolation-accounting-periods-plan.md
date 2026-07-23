# Plan de Aislamiento Multiempresa y Periodos Contables

Este plan convierte la auditoria del modelo de datos en una ruta de implementacion. La prioridad es evitar acceso cruzado entre organizaciones antes de seguir agregando modulos financieros.

## Objetivos

- Toda lectura, escritura, actualizacion, eliminacion y reporte debe ejecutarse contra una organizacion activa explicita.
- Ningun ID recibido desde formularios debe usarse sin validar pertenencia a la organizacion activa.
- La base de datos debe reforzar las reglas principales; no depender solo de filtros en codigo.
- Todo movimiento con impacto financiero debe poder validarse contra un periodo contable abierto.
- Los cierres mensuales/anuales deben ser auditables, reversibles de forma controlada y aislados por organizacion.

## Fase 1: Scope Organizacional Explicito

Estado: completada.

- [x] Crear una forma unica de resolver la organizacion activa desde la sesion/usuario.
- [x] Cambiar contextos `settings`, `summary`, `create_*`, `delete_*`, `toggle_*` para recibir organizacion o scope.
- [x] Eliminar uso operativo de `first_organization!()` fuera de seeds/tests/fallback temporal.
- [x] Corregir consultas globales en dashboard y monedas.
- [x] Agregar pruebas con dos organizaciones para detectar fugas.

Notas:

- `current_organization/1` ya resuelve la organizacion desde `user_id` en sesion.
- Las rutas internas ya exigen sesion de usuario; solo login queda publico.
- `users.organization_id` ya es requerido por changeset y por base de datos.
- `Currencies.currency_settings/1` ya filtra `organization_currencies` por organizacion.
- Dashboard ya limita conteos de monedas de organizacion y usuarios a la organizacion activa.
- Banco, cuenta corriente, gastos, dividendos, impuestos, compras/ventas e inventario ya aceptan organizacion explicita en sus flujos principales.

Criterios de aceptacion:

- Las pantallas muestran solo datos de la organizacion activa.
- Los formularios no aceptan IDs de otra organizacion.
- Las agregaciones no mezclan organizaciones.

## Fase 2: Validaciones de Pertenencia en Codigo

Estado: completada.

- [x] Ledger: validar `bank_account_id` contra organizacion antes de movimientos y diferenciales.
- [x] Commerce: validar `party_id`, `product_id` y `vat_rate_id` contra organizacion antes de crear documentos.
- [x] Expenses: validar `provider_id` contra organizacion antes de gastos ordinarios/financieros.
- [x] Dividends: validar `beneficiary_id` contra organizacion antes de capital/dividendos.
- [x] Taxes: validar `vat_rate_id` en toggle y moneda activa para impuestos.
- [x] Bank: eliminar caja chica solo si pertenece a la organizacion activa.

Notas:

- `Taxes.toggle_vat_rate/2` ya valida `vat_rate_id` por organizacion.
- `currency_id` ya se valida contra monedas habilitadas de la organizacion en banco, cuenta corriente, gastos, impuestos y compras/ventas.
- Existen pruebas IDOR para bancos, caja chica, ledger, gastos ordinarios/financieros, capital/dividendos, compras, productos, tarifas IVA y monedas no habilitadas.

Criterios de aceptacion:

- Cualquier intento de usar IDs cruzados devuelve error controlado.
- Los tests cubren operaciones permitidas y rechazadas por organizacion.

## Fase 3: Refuerzo en Base de Datos

Estado: completada.

- [x] Agregar `organization_id` directo a tablas transaccionales de alto uso:
  - `ledger_transactions`
  - `ledger_exchange_differences`
  - `expense_entries`
  - `financial_expense_entries`
  - `dividend_entries`
  - `shareholder_capital_entries`
  - `commerce_entries`
  - `commerce_entry_lines`
- [x] Backfill desde padres actuales.
- [x] Agregar indices compuestos por `organization_id` y fechas/documentos.
- [x] Agregar unique parcial para una sola moneda base por organizacion.
- [x] Agregar constraints o FKs compuestas para impedir mezclar padres de otra organizacion.
- [x] Agregar checks para enums string.

Notas:

- `20260723120000_add_organization_id_to_transaction_tables.exs` agrega columnas, backfill, `NOT NULL`, indices y unique parcial de moneda base.
- `20260723121000_add_organization_composite_foreign_keys.exs` agrega FKs compuestas para impedir relaciones padre/hijo entre organizaciones distintas.
- `20260723122000_add_string_enum_check_constraints.exs` agrega checks de enums string.
- Existe prueba directa de base de datos para rechazar una transaccion con `organization_id` y `bank_account_id` cruzados.

Criterios de aceptacion:

- La base de datos rechaza relaciones cruzadas aunque el codigo falle.
- Las consultas frecuentes usan indices por organizacion.

## Fase 4: Periodos Contables

Estado: completada.

- [x] Crear `accounting_fiscal_years`.
- [x] Crear `accounting_periods`.
- [x] Crear `accounting_period_events`.
- [x] Modelar estados: `open`, `closing`, `closed`, `locked`.
- [x] Validar que periodos no se traslapen dentro de una organizacion.
- [x] Permitir los mismos rangos de periodo en organizaciones distintas.

Notas:

- `20260723130000_create_accounting_periods.exs` crea ejercicios fiscales, periodos y eventos.
- La base de datos usa exclusion constraint por `organization_id` y rango inclusivo de fechas para impedir traslapes.
- `Sipaex.Accounting` provee creacion de ejercicios, creacion de periodos, busqueda por fecha y cambios de estado auditados.
- Esta fase solo crea soporte estructural. La validacion de escrituras contra periodos cerrados se integra en Fase 5.

Criterios de aceptacion:

- Cada organizacion administra su propio calendario fiscal.
- No hay traslapes ni huecos invalidos segun politica definida.

## Fase 5: Bloqueo por Periodo

Estado: en progreso.

- [x] Validar toda escritura por fecha efectiva (`entry_date` o `transaction_date`).
- [x] Rechazar creacion/modificacion/eliminacion en periodos cerrados o bloqueados.
- [ ] Permitir ajustes posteriores solo con permiso y periodo/tipo especial.
- [x] Registrar usuario y motivo para reaperturas.

Notas:

- Las escrituras operativas existentes ya llaman `Accounting.ensure_writable_period/2`.
- Si no existe periodo configurado para una fecha, la operacion sigue permitida para no bloquear el spike mientras se configura el calendario.
- Si existe periodo, solo `open` y `closing` permiten escritura; `closed` y `locked` rechazan.
- Se cubren ledger, diferencial cambiario, compras/ventas, gastos, gastos financieros, dividendos/capital, renta, IVA mensual y caja chica.
- Los ajustes posteriores quedan pendientes hasta Fase 6, donde se modelan asientos `adjustment`, `closing` y permisos especificos.

Criterios de aceptacion:

- Un movimiento fechado en periodo cerrado no se puede alterar indirectamente.
- Las reaperturas quedan auditadas.

## Fase 6: Libro Diario y Cierre

Estado: en progreso.

- [x] Crear `journal_entries` y `journal_lines`.
- [x] Relacionar documentos operativos con asientos contables via `source_type/source_id`.
- [x] Distinguir asientos `operational`, `adjustment`, `closing`, `reversal`.
- [x] Validar asientos balanceados y vinculados a un periodo abierto de la organizacion.
- [x] Agregar balance de comprobacion inicial por cuenta sobre `journal_lines`.
- [ ] Implementar cierre mensual.
- [ ] Implementar cierre anual de cuentas temporales y traslado de resultado acumulado.

Criterios de aceptacion:

- Reportes financieros pueden reconstruirse desde asientos.
- Cierre anual genera asientos trazables.

## Fase 7: Reportes por Rango

Estado: pendiente.

- [ ] Reportes deben recibir organizacion y rango de fechas.
- [ ] Calcular saldo inicial anterior al rango.
- [ ] Separar movimientos operativos de ajustes y cierres.
- [ ] Agregar balance de comprobacion, estado de resultados y balance general sobre periodos.

Criterios de aceptacion:

- Reportes no dependen de `inserted_at`.
- Reportes muestran saldos anteriores y movimientos del rango correctamente.

## Pruebas Requeridas

- Dos organizaciones con monedas, productos, proveedores, bancos y movimientos separados.
- Intentos IDOR por cada modulo operativo.
- Dashboard y reportes con conteos/totales aislados.
- Periodos iguales en organizaciones distintas.
- Periodos traslapados dentro de una misma organizacion rechazados.
- Escritura en periodo cerrado rechazada.
- Ajuste posterior permitido solo con permiso/evento auditable.

## Regla de Trabajo

Cada fase debe terminar con:

- Migraciones aplicadas si existen.
- Tests especificos del cambio.
- `mix precommit`.
- Checklist actualizado en este documento.
