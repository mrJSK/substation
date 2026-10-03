# GridERP Architecture

Audience: engineers on any GridERP team. Start with [CLAUDE.md](../CLAUDE.md).

---

## 1. Module map and ownership

| Module | Database file(s) | Flutter feature | Owns |
|---|---|---|---|
| Platform | `0100_platform`, `1000_notifications`, `1200_storage` | `core/`, `app/` | tenants, document numbering, audit trail, notifications, files |
| Org Structure | `0200_org_hierarchy` | `features/org` (OR01) | levels, org units, cross-level shares |
| Security / IAM | `0300_iam` | `features/auth`, `features/iam` (SU01, PFCG) | users, permission catalog, roles, assignments, **all access functions and IAM/org RLS** |
| Platform UX | `0350_experience` | `features/launchpad`, `features/forms` (UI01) | micro-app catalog, tenant app settings, dynamic forms |
| Assets | `0400_assets` | (next) AS01 | equipment register, plant history |
| Operations | `0500_operations` | (next) OP01–OP04 | shift logs, readings, tripping, stoppages |
| Safety / PTW | `0600_ptw`, `0900_safety` | (next) PT01, SF01 | permits, accident register |
| Maintenance | `0700_maintenance` | (next) MT01–MT03 | defects, work orders, plans, schedules |
| Energy | `0800_energy` | (next) EN01–EN02 | meter readings, energy balance |
| Analytics | `1100_reports` | (next) RP01 | KPI functions |
| Data & AI | `1300_semantic_layer` | — | table/column descriptions for AI and report builders |

Dependency direction: domain modules → IAM access functions → org → platform.
Never the reverse. A domain module may reference another domain's table by
foreign key (e.g. work_orders → ptw_requests) but does not change it.

## 2. Multi-tenancy

- `tenants` is the root. Every business table has `tenant_id`, defaulting to
  `current_tenant_id()` so clients never send it for domain rows.
- `current_tenant_id()` reads the caller's active `user_profiles` row; an
  inactive or expired user resolves to no tenant and therefore sees nothing.
- New customers are created by the platform operator with
  `provision_tenant(...)` (service role only): tenant, its levels, a root unit
  and the first administrator holding `TENANT_ADMIN` at the root.

## 3. Dynamic hierarchy

- `org_levels(tenant_id, rank, name, code, is_operational)` — the tenant's own
  level names. Rank 1 is the top. `is_operational` marks where shift work happens.
- `org_units(parent_id, level_id, path ltree, …)` — any depth. A child's level
  rank must be greater than its parent's; levels may be skipped (ragged trees).
- `path` is maintained by triggers (insert, move, re-parent of a whole subtree).
  Subtree query: `u.path <@ (select path from org_units where id = :x)`.
- `org_tree` view = units + level names + depth (security invoker).
- Data tables reference `org_unit_id`, never a fixed "substation" column, so
  every report works at any level.

## 4. Authorization: WHO × WHAT × WHERE

```
user_profiles ──< user_role_assignments >── roles ──< role_permissions >── permissions
   WHO               WHERE: org_unit_id           WHAT                      catalog (code, module)
                     + include_descendants
                     + valid_from / valid_to
```

- **Permissions** are a fixed catalog shipped with the product (e.g. `PTW_ISSUE`).
- **Roles** bundle permissions. `tenant_id IS NULL` = standard templates
  (read-only); tenants create their own or copy a template with `clone_role`.
- **Assignments** grant a role at a unit, optionally to all units below it,
  for a validity window.
- **Access functions** (security definer, `0300_iam`):
  `user_has_permission(code, unit)`, `user_has_tenant_permission(code)`,
  `can_read_org_unit(unit)`, `get_user_permissions(unit)`, `get_my_access()`.
- **Read rule** for domain data: tenant matches **and** `can_read_org_unit` —
  any active role covering the unit, or a valid share.
- **Write rule**: the specific permission at the row's unit.
- **No privilege escalation**: a trigger rejects any assignment whose role
  contains a permission the granter does not hold at that scope.
- **Cross-level sharing**: `org_unit_shares(source, target, valid_to)` lets
  users covering *target* read *source* and everything below it.
- The app evaluates the same rules locally from `get_my_access()` (cached) to
  hide unavailable actions; the database is always the enforcer.

## 5. Micro-apps (T-codes)

- `app_catalog(code, name, module, icon, required_permission)` — one row per app.
- `tenant_app_settings` — per-tenant enable/disable and rename.
- `get_my_apps()` — apps the caller may launch (permission held at any scope).
- Flutter: `lib/app/micro_app_registry.dart` maps code → screen;
  `MicroAppHost` checks access and shows "not released yet" for catalog
  entries without a screen; `openMicroApp(context, code)` navigates; the
  launchpad's T-code box accepts any code.

| Code | App | Code | App |
|---|---|---|---|
| OP01 | Shift Logsheet | MT01 | Work Orders |
| OP02 | Tripping Register | MT02 | Defect Register |
| OP03 | Stoppage Register | MT03 | Maintenance Plans |
| OP04 | SLDC Messages | AS01 | Equipment Master |
| PT01 | Permit to Work | EN01 | Meter Readings |
| SF01 | Accident Register | EN02 | Energy Balance |
| RP01 | Dashboard | OR01 | Org Structure |
| SU01 | User Maintenance | PFCG | Role Maintenance |
| UI01 | Forms and Apps | SM20 | Audit Trail |

## 6. Dynamic UI

- `ui_forms(tenant_id, code, version, schema jsonb)`; `get_form(code)` returns
  the tenant's newest override, else the standard form.
- Schema: `sections[] → fields[]` with `key, label, type (text, textarea,
  number, integer, select, toggle, date, datetime), unit, required, hint,
  options, min, max, decimals, limits {alarm_low, alarm_high, trip_low,
  trip_high}, visible_if {field, equals}`.
- `DynamicForm` (features/forms) renders any schema; limits warn, never block
  (abnormal readings must be recorded). Values map to typed columns, extra
  keys to the row's `extra` JSON.
- UI01 previews forms, saves tenant overrides as new versions, and switches
  micro-apps on or off.

## 7. Statutory workflow enforcement (examples)

- PTW: `DRAFT → PENDING_SLDC → SLDC_APPROVED → ISOLATION_DONE → ISSUED →
  WORK_IN_PROGRESS → RETURNED → CLOSED` (or `CANCELLED` with a reason). The
  trigger checks the transition, the permission for it, earthing points and
  workman before issue, and issuer ≠ workman.
- Registers (logsheet, tripping, stoppage, defects, plant history, energy)
  have no delete policies. Completed shifts and approved energy readings are
  locked.
- Document numbers (`PTW-2026-000001`, `WO-…`, `DEF-…`, `ACC-…`) come from
  `next_document_number`, per tenant per year.
- Energy: net kWh = (reading − previous) × MF, computed by trigger; a lower
  reading is rejected unless marked as a meter reset.
- `audit_row_change()` records before/after JSON for critical tables.

## 8. API exposure and security baseline

- "Automatically expose new tables" is **off**. `0100_platform` sets default
  privileges: `anon` gets nothing; `authenticated` gets select/insert/update/
  delete (RLS decides rows); no TRUNCATE (it bypasses RLS).
- Internal trigger/helper functions are revoked from `public, anon,
  authenticated` in the file that defines them.
- Security definer functions set `search_path`. `ltree` lives in `extensions`.
- `supabase db advisors --linked` must stay clean except the intentional
  "authenticated can execute access functions" notice.

## 9. Offline-first client

- `LocalCache` (Hive CE, JSON) stores the access profile, app list, org tree
  and forms with a max age (7 days). Repositories try the network and fall
  back to the cache, so the app opens and authorizes offline.
- Row ids for field data are UUIDs generated on the device, so a future write
  queue can upsert idempotently.
- No polling. Realtime only for live PTW status and alerts.

## 10. Edge Functions

| Function | Trigger | Purpose |
|---|---|---|
| `iam-admin-users` | App (SU01) | Create sign-in account + profile; caller needs USER_ADMIN at the home unit; first role is granted as the caller so the escalation guard applies |
| `generate-work-orders` | pg_cron daily (service role) | Preventive WOs for schedules due in 3 days |
| `notify-deadlines` | pg_cron every 4 h (service role) | Inspector reporting deadline, missing energy readings, PTW overruns |

Shared helpers: `functions/_shared/clients.ts` (`adminClient` vs
`callerClient` — prefer the caller client so RLS applies), `_shared/http.ts`.

## 11. AI readiness

- **Semantic layer** (`1300_semantic_layer`): every business table, key column
  and KPI function has a plain-English comment. AI models read these to map
  questions to queries/tools. New tables must add comments.
- **Same security for AI**: an assistant runs with the user's JWT, never the
  service key, so tenant isolation, org scope and permissions apply to every
  AI-generated query.
- **Planned**: an `ai-query` Edge Function (Claude with tool calls restricted
  to read-only views and the KPI functions), and pgvector search over
  manuals, SOPs and plant history for retrieval.
