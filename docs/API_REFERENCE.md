# GridERP — Supabase API Reference

**For frontend teams.** Every RPC, REST endpoint, storage path, and Edge Function in one place.  
Generated from: `supabase/migrations/003_functions.sql` + schema.  
Update this file whenever a new RPC or endpoint is added.

---

## Base URL

```
https://ciznlknixpddqwrbvyvc.supabase.co
```

All calls require the `Authorization: Bearer <user-jwt>` header (handled automatically by `supabase_flutter`).

---

## Authentication

| Operation | Method | Notes |
|-----------|--------|-------|
| Sign in | `supabase.auth.signInWithPassword({email, password})` | Returns session JWT |
| Sign out | `supabase.auth.signOut()` | Clears local session |
| Session stream | `supabase.auth.onAuthStateChange` | Use in `SessionNotifier` |
| Current user | `supabase.auth.currentUser` | `null` if signed out |

Auth is **invite-only** — users created by TENANT_ADMIN via Supabase Dashboard or IAM module.

---

## RPC Functions (call via `supabase.rpc()`)

### User & Permissions

#### `get_user_permissions(p_user_id, p_org_unit_id) → text[]`
Returns all permission codes the user has at the given org unit (checks ancestor scopes via ltree).  
**Cache: 8 hours (Hive).** Invalidate on role change.
```dart
final perms = await supabase.rpc('get_user_permissions', params: {
  'p_user_id': userId,
  'p_org_unit_id': substationId,
});
```

#### `get_hierarchy_config(p_tenant_id) → jsonb`
Returns ordered level definitions for a tenant.  
**Cache: 7 days.** Only re-fetch if tenant changes config.
```dart
final config = await supabase.rpc('get_hierarchy_config', params: {
  'p_tenant_id': tenantId,
});
// [{level: 1, level_name: "Zone", level_code: "ZN", is_leaf: false}, ...]
```

#### `get_org_ancestors(p_org_unit_id) → [{id, name, level}]`
Returns ancestor chain (for breadcrumbs). Ordered root → leaf.
```dart
final ancestors = await supabase.rpc('get_org_ancestors', params: {
  'p_org_unit_id': orgUnitId,
});
```

#### `get_accessible_substations(p_user_id) → [{id, name, code, voltage_kv, parent_name, parent_id}]`
All substations within the user's role scope. Used for substation picker on login.  
**Cache: 48 hours (Hive).**
```dart
final substations = await supabase.rpc('get_accessible_substations', params: {
  'p_user_id': userId,
});
```

---

### Dashboard & KPIs

#### `get_dashboard_kpis(p_substation_id, p_year, p_month) → jsonb`
Single call for the entire dashboard. Use `p_month = 0` for full-year.
```dart
final kpis = await supabase.rpc('get_dashboard_kpis', params: {
  'p_substation_id': substationId,
  'p_year': 2026,
  'p_month': 10,
});
// {availability, energy_balance, saidi_saifi, open_ptw_count,
//  open_wo_count, open_defect_count, overdue_wo_count, critical_defect_count}
```

#### `compute_availability(p_substation_id, p_year, p_month) → numeric`
Returns availability % using CERC formula.

#### `compute_saidi_saifi(p_substation_id, p_year, p_month) → jsonb`
Returns `{saidi, saifi, caidi, total_consumers, period_year, period_month}`.

#### `compute_energy_balance(p_substation_id, p_year, p_month) → jsonb`
Returns `{import_kwh, export_kwh, loss_kwh, loss_percent}`.

---

### Operations

#### `get_or_create_shift(p_substation_id, p_shift_date, p_shift_type, p_user_id) → shift_logs row`
Upserts today's shift log. Call on shift start.
```dart
final shift = await supabase.rpc('get_or_create_shift', params: {
  'p_substation_id': substationId,
  'p_shift_date': '2026-10-03',
  'p_shift_type': 'MORNING',
  'p_user_id': userId,
});
```

---

### Maintenance

#### `get_overdue_maintenance(p_substation_id, p_days_ahead) → table`
Returns equipment overdue or due within N days.
```dart
final overdue = await supabase.rpc('get_overdue_maintenance', params: {
  'p_substation_id': substationId,
  'p_days_ahead': 7,
});
// [{equipment_id, equipment_name, plan_title, last_done_at, next_due_at, days_overdue}]
```

---

## REST Table Endpoints

All via PostgREST. Select only the columns you need — never `select(*)`.

### org_units
```dart
// Fetch all org units for tenant (cached 7 days)
supabase.from('org_units')
  .select('id, name, code, level, parent_id, voltage_kv, total_consumers')
  .order('level');
```

### user_profiles
```dart
// Own profile
supabase.from('user_profiles')
  .select('id, full_name, employee_id, designation, org_unit_id')
  .eq('id', supabase.auth.currentUser!.id)
  .single();

// All users in tenant (IAM screen)
supabase.from('user_profiles')
  .select('id, full_name, employee_id, designation, org_unit_id, org_units(name)')
  .order('full_name');
```

### user_role_assignments
```dart
// User's roles
supabase.from('user_role_assignments')
  .select('id, role_id, org_unit_id, valid_from, valid_to, roles(name), org_units(name)')
  .eq('user_id', userId);
```

### roles
```dart
// All roles for tenant
supabase.from('roles')
  .select('id, name, description, is_system')
  .order('name');
```

### permissions
```dart
// All permission codes (global, cached forever)
supabase.from('permissions')
  .select('id, code, description, module');
```

### shift_logs / shift_readings
```dart
// Today's shifts for a substation
supabase.from('shift_logs')
  .select('id, shift_date, shift_type, shift_in_charge, status, user_profiles(full_name)')
  .eq('substation_id', substationId)
  .eq('shift_date', today);

// Readings for a shift (offline queue → batch upsert)
supabase.from('shift_readings')
  .upsert([...readings], onConflict: 'shift_log_id,equipment_id,reading_time');
```

### ptw_requests
```dart
// Active PTWs (Realtime subscription — use sparingly)
supabase.from('ptw_requests')
  .select('id, ptw_number, status, work_description, start_time, end_time, issued_by')
  .eq('substation_id', substationId)
  .in_('status', ['ISSUED', 'WORK_IN_PROGRESS']);
```

### work_orders
```dart
supabase.from('work_orders')
  .select('id, wo_number, title, type, status, scheduled_date, equipment_id, equipment(name)')
  .eq('substation_id', substationId)
  .not('status', 'in', '("COMPLETED","CANCELLED")')
  .order('scheduled_date');
```

### notifications
```dart
// Unread alerts (poll on app resume, not continuous)
supabase.from('notifications')
  .select('id, type, priority, title, body, entity_type, entity_id, created_at')
  .eq('org_unit_id', substationId)
  .eq('is_read', false)
  .order('created_at', ascending: false);
```

---

## Storage Buckets

| Bucket | Path pattern | Max size | Allowed types |
|--------|-------------|----------|---------------|
| `documents` | `{tenant_id}/{entity_id}/{filename}` | 50 MB | PDF, image, docx |
| `test-reports` | `{tenant_id}/{wo_id}/{filename}` | 20 MB | PDF, image |
| `accident-photos` | `{tenant_id}/{accident_id}/{filename}` | 10 MB | JPEG, PNG |
| `defect-photos` | `{tenant_id}/{defect_id}/{filename}` | 10 MB | JPEG, PNG |
| `signatures` | `{tenant_id}/{ptw_id}/{role}.png` | 1 MB | PNG only |
| `certificates` | `{tenant_id}/{user_id}/{filename}` | 5 MB | PDF, image |

```dart
// Upload example
await supabase.storage.from('defect-photos').upload(
  '$tenantId/$defectId/${DateTime.now().millisecondsSinceEpoch}.jpg',
  file,
);

// Get URL example
final url = supabase.storage.from('defect-photos')
  .getPublicUrl('$tenantId/$defectId/photo.jpg');
```

---

## Edge Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `generate-work-orders` | Cron: `0 1 * * *` (1AM daily) | Creates PREVENTIVE WOs from maintenance_schedules |
| `notify-deadlines` | Cron: `0 */4 * * *` (every 4hr) | CEIG deadline, energy statement, PTW overrun alerts |

Manual invocation (for testing):
```bash
supabase functions invoke generate-work-orders --project-ref ciznlknixpddqwrbvyvc
```

---

## Realtime Subscriptions

**Use sparingly — only for live operational status.**

```dart
// Active PTW changes (control room display)
supabase.from('ptw_requests')
  .stream(primaryKey: ['id'])
  .eq('substation_id', substationId)
  .listen((rows) { ... });

// Unread notifications
supabase.from('notifications')
  .stream(primaryKey: ['id'])
  .eq('org_unit_id', substationId)
  .eq('is_read', false)
  .listen((rows) { ... });
```

**Do NOT subscribe to:** shift_readings, energy_readings, work_orders, defects — use periodic fetch instead.

---

## Permission Codes Reference

| Code | Module | Who needs it |
|------|--------|-------------|
| `LOGSHEET_WRITE` | Operations | Shift Engineer, JE Operations, SSO |
| `TRIPPING_WRITE` | Operations | Shift Engineer, JE Operations |
| `STOPPAGE_WRITE` | Operations | Shift Engineer, JE Operations |
| `PTW_REQUEST` | PTW | JE Maintenance, JE Operations |
| `PTW_ISSUE` | PTW | Shift Engineer |
| `PTW_APPROVE_SLDC` | PTW | EE, AE Operations |
| `PTW_CANCEL` | PTW | EE |
| `DEFECT_CREATE` | Maintenance | All field staff |
| `DEFECT_CLOSE` | Maintenance | JE Maintenance, AE Maintenance |
| `WO_CREATE` | Maintenance | JE Maintenance, AE Maintenance |
| `WO_ASSIGN` | Maintenance | AE Maintenance |
| `WO_COMPLETE` | Maintenance | JE Maintenance |
| `ENERGY_WRITE` | Energy | Shift Engineer, JE Operations |
| `ASSET_WRITE` | Assets | AE Maintenance, EE |
| `ACCIDENT_REPORT` | Safety | Shift Engineer, EE |
| `USER_ADMIN` | IAM | Tenant Admin |
| `ROLE_ADMIN` | IAM | Tenant Admin |
| `REPORT_VIEW` | Reports | EE, AE Operations, AE Maintenance |
