# GridERP API Reference

Audience: frontend and integration developers. This is the contract between
the database teams and everyone calling them. Update it in the same change as
any new or changed RPC, table, bucket or Edge Function.

- Base URL: `https://ciznlknixpddqwrbvyvc.supabase.co`
- Client key: the **publishable** key (`lib/core/supabase/supabase_config.dart`). Never ship the secret key.
- Every call runs as the signed-in user; RLS filters rows by tenant and org scope.
- Name columns explicitly. Postgrest Dart `.order()` defaults to **descending** — pass `ascending: true`.
- Errors: map with `AppFailure.from(e)` (`lib/core/errors/app_failure.dart`); `42501` = no permission.

---

## Session

| Call | Returns | Notes |
|---|---|---|
| `auth.signInWithPassword(email, password)` | session | Accounts are created by admins (SU01); self sign-up is off. |
| `rpc('get_my_access')` | `{profile, tenant, assignments[], issued_at}` or `null` | One call after login; cache it. Each assignment: `role_code, role_name, org_unit_id, org_unit_name, scope_path, include_descendants, permissions[]`. `null` = account not linked to a tenant. |
| `rpc('get_my_apps')` | `[{code, name, module, description, icon, required_permission}]` | Launchpad source; tenant settings applied. |
| `rpc('get_user_permissions', {p_org_unit_id})` | `text[]` | Server-side check for one unit. |
| `rpc('current_tenant_id')` | `uuid` | |

Client-side permission check (offline-capable): `AccessProfile.can(code, unitPath:)`,
`canAnywhere(code)`, `canTenantWide(code)` — same semantics as the database.

## Org structure

| Call | Notes |
|---|---|
| `from('org_levels').select('id, rank, name, code, is_operational')` | Tenant's own levels. Write: tenant-wide `ORG_ADMIN`. |
| `from('org_tree').select('id, parent_id, name, code, path, depth, level_id, level_name, level_rank, is_operational, is_active, voltage_kv, total_consumers')` | Whole tree; cache 7 days. `path` is `a.b.c`; descendants start with `path.`. |
| `from('org_units').insert({tenant_id, parent_id, level_id, name, code, voltage_kv, total_consumers})` | Needs `ORG_ADMIN` at the parent. `path` is computed; child level rank must exceed parent's. |
| `from('org_units').update({...}).eq('id', id)` | Changing `parent_id` moves the whole subtree. |
| `from('org_unit_shares')` `id, source_org_unit_id, target_org_unit_id, valid_from, valid_to, reason` | Users covering target read source subtree. Write: `ORG_ADMIN` at source. |
| `rpc('get_accessible_org_units', {p_operational_only})` | Units the caller can see (unit picker). |
| `rpc('get_org_ancestors', {p_org_unit_id})` | Breadcrumb, root first. |

## IAM

| Call | Notes |
|---|---|
| `from('user_profiles').select('id, full_name, email, employee_id, designation, phone, home_org_unit_id, is_active, valid_to')` | Update needs `USER_ADMIN` at the home unit. `is_active=false` removes all access. |
| `functions.invoke('iam-admin-users', body: {email, password, full_name, home_org_unit_id, employee_id?, designation?, phone?, role_id?, scope_org_unit_id?})` | Creates account + profile. → `{user_id}` (201) or `{error}`. |
| `from('roles').select('id, tenant_id, code, name, description')` | `tenant_id null` = standard template (read-only). |
| `from('permissions').select('code, module, description').order('sort_order', ascending: true)` | Catalog. |
| `from('role_permissions')` insert/delete `{role_id, permission_code}` | Tenant roles only; tenant-wide `ROLE_ADMIN`. |
| `rpc('clone_role', {p_source_role_id, p_code, p_name})` | → new role id. |
| `from('user_role_assignments')` `id, tenant_id, user_id, role_id, org_unit_id, include_descendants, valid_from, valid_to` | Needs `USER_ADMIN` at `org_unit_id`; rejected if the role contains a permission the granter lacks there. |

## Micro-apps and dynamic UI

| Call | Notes |
|---|---|
| `rpc('get_form', {p_code})` | Effective form `{id, code, version, title, description, schema, is_tenant_override}`; cache it. |
| `from('ui_forms')` insert `{tenant_id, code, version, title, schema}` | Tenant override = new version. `UI_ADMIN`. |
| `from('app_catalog').select('code, name, module, required_permission')` | All apps. |
| `from('tenant_app_settings').upsert({tenant_id, app_code, is_enabled}, onConflict: 'tenant_id,app_code')` | `UI_ADMIN`. |

Standard forms: `TRANSFORMER_HOURLY`, `BATTERY_DAILY`.

## Domain tables (all scoped by `org_unit_id`; `tenant_id` defaults server-side)

| Table | Write permission | Notes |
|---|---|---|
| `equipment` | `ASSET_WRITE` | `unique (tenant_id, asset_tag)`; `technical_params` JSON |
| `equipment_history` | `ASSET_WRITE` or `WO_COMPLETE` | append-only |
| `shift_logs` | `LOGSHEET_WRITE` | `unique (org_unit_id, shift_date, shift_code)`; locked when `is_completed` |
| `shift_readings` | `LOGSHEET_WRITE` | generate `id` on device; upsert on `id`; tenant extras in `extra` |
| `tripping_events` | `TRIPPING_WRITE` | |
| `stoppages` | `STOPPAGE_WRITE` | `duration_min` computed |
| `ptw_requests` | per transition (see below) | `ptw_number` assigned on insert |
| `defects` | `DEFECT_CREATE`; closing needs `DEFECT_CLOSE` | `defect_number` assigned |
| `work_orders` | `WO_CREATE` / `WO_ASSIGN` / `WO_COMPLETE` | completing a plan WO advances its schedule |
| `maintenance_plans` | tenant-wide `MAINT_PLAN_ADMIN` | templates have `tenant_id null` |
| `maintenance_schedules` | `MAINT_PLAN_ADMIN` | |
| `energy_readings` | `ENERGY_WRITE`; approval `ENERGY_APPROVE` | `net_energy_kwh` computed; set `is_meter_reset` after meter change |
| `accident_reports` | `ACCIDENT_REPORT` | `report_number` assigned; inspector notice within 24 h |
| `notifications` | — (written by jobs) | update `is_read`, `read_at`, `read_by` |

PTW transitions: DRAFT→PENDING_SLDC (`PTW_REQUEST`) · →SLDC_APPROVED
(`PTW_APPROVE_SLDC`) · →ISOLATION_DONE / ISSUED / WORK_IN_PROGRESS / RETURNED /
CLOSED (`PTW_ISSUE`) · any open→CANCELLED (`PTW_CANCEL`, `cancel_reason`
required). Issuing requires `workman_user_id` ≠ issuer and at least one earthing point.

`rpc('get_or_create_shift', {p_org_unit_id, p_shift_date, p_shift_code})` → the shift row.

## Reports (any unit; aggregates its subtree; `p_month = 0` = whole year)

| RPC | Returns |
|---|---|
| `get_dashboard_kpis(p_org_unit_id, p_year, p_month)` | `{availability, energy_balance, reliability, open_ptw, open_work_orders, overdue_work_orders, open_defects, critical_defects}` |
| `compute_energy_balance(…)` | `{import_kwh, export_kwh, loss_kwh, loss_percent}` |
| `compute_saidi_saifi(…)` | `{saidi, saifi, caidi, total_consumers}` |
| `compute_availability(…)` | `%` for one unit |
| `get_overdue_maintenance(p_org_unit_id, p_days_ahead)` | rows with `days_overdue` |

## Storage

Path for every bucket: `{tenant_id}/{org_unit_id}/{entity_id}/{file}`. Read and
upload need access to the org unit; objects are immutable (no update/delete).

| Bucket | Max | Types |
|---|---|---|
| documents | 50 MB | PDF, images, DOCX |
| test-reports | 20 MB | PDF, images |
| accident-photos, defect-photos | 10 MB | images |
| signatures | 1 MB | PNG |
| certificates | 5 MB | PDF, images |

## Edge Functions

| Function | Caller | Purpose |
|---|---|---|
| `iam-admin-users` | app (USER_ADMIN) | create user |
| `generate-work-orders` | pg_cron, service-role JWT | preventive WOs |
| `notify-deadlines` | pg_cron, service-role JWT | deadline and overrun notifications |

## Platform operator only (service role / SQL)

`provision_tenant(p_name, p_short_code, p_utility_type, p_state, p_levels jsonb,
p_root_name, p_root_code, p_admin_user_id, p_admin_full_name)` → tenant id.
