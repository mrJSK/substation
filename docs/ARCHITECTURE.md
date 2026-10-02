# SubERP — Architecture

**Entry point:** See `CLAUDE.md`.

---

## Multi-Tenancy

Every table has `tenant_id`. Supabase RLS isolates tenants completely:

```sql
create function current_tenant_id() returns uuid language sql stable as $$
  select tenant_id from user_profiles where id = auth.uid()
$$;

create policy tenant_isolation on equipment
  using (tenant_id = current_tenant_id());
```

A user from UPTCL never sees MSEDCL data — enforced at the database level, not just the app.

---

## Org Hierarchy

```
Tenant (0)  →  Zone (1)  →  Circle (2)  →  Division (3)
  →  Subdivision (4)  →  Substation (5)  →  Bay (6)
```

Stored in `org_units` as self-referential tree with `path ltree` for fast ancestor queries:
```sql
-- All substations under Circle "AGRA":
select * from org_units where path ~ '*.AGRA.*' and level = 5;
```

---

## Permission Model (SAP-style)

Three layers:

**1. Permissions** (fine-grained predicates — seeded in schema.sql):
- `PTW_ISSUE`, `LOGSHEET_WRITE`, `ENERGY_APPROVE`, `USER_ADMIN`, etc.

**2. Roles** (named collection of permissions):
- `SHIFT_ENGINEER` = {PTW_ISSUE, PTW_APPROVE_SLDC, LOGSHEET_WRITE, TRIPPING_WRITE, ...}
- `JE_MAINTENANCE` = {WO_CREATE, WO_COMPLETE, DEFECT_CREATE, TESTING_WRITE, ...}
- `AE_MAINTENANCE` = {WO_ASSIGN, ENERGY_APPROVE, ASSET_WRITE, ...}

**3. User Role Assignments** (role + org scope):
- "Ramesh has SHIFT_ENGINEER role at Substation SS-042 (and all bays under it)"
- One user can have multiple assignments: shift engineer at one substation, JE at another

**SoD rule (Segregation of Duties):** PTW issuer ≠ workman. Enforced in:
- `ptw_requests` table check: `issued_by != workman_user_id`
- App-level: workman list excludes the logged-in user when issuing PTW

---

## Offline-First Architecture (CRITICAL)

The old Firebase app was shut down due to API costs. This must not happen again.

### What's cached locally (Hive)

| Data | TTL | Reason |
|------|-----|--------|
| Org unit tree | 7 days | Never changes; needed for dropdowns |
| Equipment list per substation | 48 hrs | Needed offline for logsheet entry |
| Active roles + permissions | 8 hrs (shift length) | Auth checks offline |
| Maintenance plan templates | 7 days | Reference data |

Cache is validated at login. If stale, a single batch fetch updates all caches.

### What's queued locally (Drift/SQLite)

| Operation | Queue strategy |
|-----------|---------------|
| Shift logsheet reading entry | Write to Drift immediately; sync every 15 min |
| Defect report | Write to Drift; sync on connectivity restore |
| PTW workflow steps | Sync immediately (safety-critical — retry on failure) |
| Energy meter reading | Write to Drift; sync at shift end |

Sync mechanism:
1. Drift queue table: `pending_syncs (id, entity_type, payload JSON, created_at, attempt_count)`
2. Background isolate checks connectivity and drains the queue
3. On sync success: delete from queue
4. On permanent failure (3 attempts): mark `is_failed = true`, surface in UI

### What's Realtime (Supabase Realtime — keep minimal)

| Channel | Why Realtime |
|---------|-------------|
| `ptw_requests:substation_id=eq.SS042` | Active permits must show up live on all shift staff devices |
| `defects:status=eq.CRITICAL` | Critical defects need immediate attention |
| Nothing else | Everything else: fetch-on-navigate |

---

## Supabase Edge Functions (server-side computation)

Never pull raw rows to compute KPIs — compute server-side, return a single JSON:

| Function | Replaces |
|----------|---------|
| `compute-availability` | Fetching all `stoppages` rows for a month |
| `compute-energy-balance` | Fetching all `energy_readings` for a month |
| `generate-saidi-saifi` | Fetching all `stoppages` + customer count |
| `create-scheduled-work-orders` | Cron: daily job to check `maintenance_schedules` and create `work_orders` |
| `send-maintenance-reminders` | FCM notifications for overdue maintenance |

---

## State Management (Riverpod)

Pattern per feature:
```
feature/
  data/
    feature_repository.dart     # Supabase queries + Drift cache
  domain/
    feature_model.dart          # Freezed immutable models
  presentation/
    feature_provider.dart       # @riverpod AsyncNotifier
    feature_screen.dart         # ConsumerWidget
    feature_controller.dart     # @riverpod class (mutations)
```

Providers are code-generated (`@riverpod` annotation → `build_runner` → `.g.dart` files).

---

## PDF Generation

Statutory registers must be printable. Pattern:
```dart
// In any feature's PDF service:
final pdf = pw.Document();
pdf.addPage(pw.Page(
  build: (context) => pw.Table(/* register rows */),
));
await Printing.sharePdf(bytes: await pdf.save(), filename: 'PTW_Register_2026-10.pdf');
```

Every register that has a statutory format gets a PDF export button.

---

## Key Supabase Tables Quick Reference

| Table | Purpose | Reg |
|-------|---------|-----|
| `org_units` | Tenant → Zone → Circle → Division → Subdivision → Substation → Bay | — |
| `equipment` | Asset master (transformer, CB, CT, LA, battery, etc.) | Reg 2 |
| `equipment_history` | Plant history register | Reg 2 |
| `shift_logs` | One row per shift at each substation | Reg 19 |
| `shift_readings` | Hourly readings (MW, kV, temp, status) per bay | Reg 19 |
| `ptw_requests` | 7-step PTW workflow | Reg 9a/9b |
| `defects` | Defect register | Reg 7 |
| `work_orders` | All WOs (preventive, corrective, breakdown) | Reg 6/7 |
| `energy_readings` | Daily 8 AM meter readings per feeder | Reg 8 |
| `tripping_events` | Primary system trippings with fault analysis | Reg 10 |
| `stoppages` | All interruptions (feeds SAIDI/SAIFI) | Reg 11 |
| `maintenance_plans` | Template schedules per equipment type | IEC/IS |
| `maintenance_schedules` | Next-due per equipment | IEC/IS |
| `accident_reports` | Dangerous occurrence book | CEA Reg 46 |
| `audit_logs` | Immutable — RLS blocks update/delete | CEA |
