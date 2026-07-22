# SIPAE Phoenix Spike Handoff

Use this as context for a Phoenix + LiveView spike in `../sipaex`.

## Product Context

SIPAE is an ERP-style application for small and medium businesses. The first target market is Costa Rica.

Code, database names, infrastructure, and AI collaboration should stay in English. User-facing UI should be Spanish by default. Future i18n is desired, but the current product language is Spanish.

The current implementation lives in `/Users/dblanco/Code/sipae` and is a Rust workspace:

- `crates/web`: Axum + Maud + HTMX server-rendered UI.
- `crates/common`: shared primitives, pagination, Postgres helpers.
- Module stacks usually follow `domain`, `app`, and `infra` crates.
- PostgreSQL migrations live in `migrations/`.

Active or recently implemented modules:

- purchases
- taxes
- inventory
- costs
- fixed assets
- human resources / payroll
- bank summaries
- organization currencies

## Product Rules Discovered So Far

- Purchases are source facts for inventory receipts.
- Inventory entries should mostly come from purchases, with controlled write-offs for damaged, lost, or stolen goods.
- Monetary values should use the organization default/base currency.
- UI should display currency symbols where business users expect money.
- Lists should be paginated server-side.
- Forms should support fast inline workflows.
- Spreadsheet files are business references, not database designs.
- Normalize source facts and derive summaries instead of copying workbook layouts one-to-one.

## Recommended Phoenix Stack

Use:

- Phoenix
- LiveView
- Ecto
- PostgreSQL

The spike should test whether Phoenix LiveView makes SIPAE faster to build than the current Rust + Axum + Maud + HTMX stack.

Keep the first spike narrow:

- CRUD
- server-side pagination
- validations
- Spanish UI labels
- one useful derived summary

Avoid building the full ERP in the spike.

## Best First Spike Target

Recommended target: Human Resources.

Reason:

- It has enough forms and workflow complexity to be a meaningful comparison.
- It exercises CRUD, validation, derived summaries, and module navigation.
- It shows whether LiveView reduces ceremony compared to the current Rust implementation.

## HR Domain Context

The HR module should be one top-level module, even if the menu exposes Personal and Planilla concepts.

Suggested tabs:

- `Resumen`
- `Funcionarios`
- `Salarios`
- `Planilla`
- `Períodos`

Current HR concepts:

- employees
- salary setup over time
- payroll periods
- payroll runs
- payroll employee lines
- monthly payroll summary derived from payroll lines/runs

Keep internal names English:

- `employees`
- `employee_compensations` or `employee_salaries`
- `payroll_periods`
- `payroll_runs`
- `payroll_employee_lines`

Spanish UI labels:

- `Funcionarios`
- `Salarios`
- `Planilla`
- `Períodos`
- `Resumen`

## HR Modeling Notes

Employee fields:

- `organization_id`
- `identification_number`
- `full_name`
- `phone`
- `email`
- `job_title`
- `start_date`
- `payment_frequency`
- `active`

Salary setup fields:

- `employee_id`
- `effective_from`
- `base_currency_code`
- `base_salary_amount`
- `hourly_rate_amount`
- `payment_frequency`
- `active`

Payroll period fields:

- `organization_id`
- `period_year`
- `period_month`
- `status`
- `active`

Suggested statuses:

- `draft`
- `calculated`
- `posted`
- `paid`
- `closed`

Payroll run fields:

- `organization_id`
- `payroll_period_id`
- `run_date`
- `payment_date`
- `status`
- `base_currency_code`
- `gross_salary_amount`
- `employee_deduction_amount`
- `net_salary_amount`
- `employer_contribution_amount`
- `total_payable_amount`
- `active`

Payroll employee line fields:

- `payroll_run_id`
- `employee_id`
- `base_salary_amount`
- `hourly_rate_amount`
- `overtime_hours`
- `double_time_hours`
- `unworked_hours`
- `unworked_amount`
- `extra_salary_amount`
- `gross_salary_amount`
- `employee_deduction_amount`
- `employee_insurance_amount`
- `employee_recurring_deduction_amount`
- `garnishment_amount`
- `other_deduction_amount`
- `net_salary_amount`
- `employer_contribution_amount`
- `employer_insurance_amount`
- `christmas_bonus_accrual_amount`
- `disability_amount`
- `active`

Do not hard-code Costa Rica-specific concepts into the core model when a generic term works:

- `CCSS / seguro social` should become configurable `insurance_plan`.
- `Aguinaldo` should be named internally `christmas_bonus`.
- `Asociación Solidarista` should become a generic `employee_deduction_plan`.

## HR Spike Scope

For the spike, implement:

1. Employees list/create/edit/deactivate.
2. Salaries list/create/edit/deactivate.
3. Payroll periods list/create/edit/deactivate.
4. Payroll line create flow that creates or reuses a draft payroll run for the selected period.
5. Payroll line form prefilled from active salary setup.
6. Monthly summary derived from payroll lines/runs.

This is enough to compare Phoenix productivity against the Rust version.

## Fixed Assets Context

Fixed assets are another good spike candidate if HR is too large.

Concepts:

- categories
- assets
- provider/acquisition details
- depreciation defaults from category
- payment history later

Important rules:

- Category does not need a code; use name only.
- If a category is not depreciable, useful life and residual value fields should be disabled in the UI.
- Assets usually come from providers.
- Asset acquisition can later connect to purchases/payments.
- Depreciation should be derived over time from acquisition cost, residual value, useful life, and method.

Suggested fixed-assets spike:

1. Categories list/create/edit/deactivate.
2. Asset create flow using category defaults.
3. Provider selector.
4. Derived depreciation preview.

## Current Rust Reference Files

Useful files to inspect from `/Users/dblanco/Code/sipae`:

- `docs/project.md`
- `docs/working-on.md`
- `docs/issues/I14.md`
- `docs/issues/I15.md`
- `crates/web/src/routes/hr.rs`
- `crates/web/src/ui/hr/`
- `crates/hr/domain/`
- `crates/hr/app/`
- `crates/hr/infra/`
- `crates/web/src/routes/fixed_assets.rs`
- `crates/web/src/ui/fixed_assets/`
- `crates/fixed_assets/domain/`
- `crates/fixed_assets/app/`
- `crates/fixed_assets/infra/`

## Decision Criteria

Use the spike to answer:

- Can Phoenix LiveView produce the same module with less ceremony?
- Are forms, validation, pagination, and inline updates easier to maintain?
- Is the resulting code easier for future contributors to understand?
- Does LiveView reduce the amount of manual HTMX wiring?
- Does Ecto make schema/migration/query work faster than SQLx plus repository traits?

If the answer is yes, strongly consider moving SIPAE to Phoenix before the Rust codebase grows further.
