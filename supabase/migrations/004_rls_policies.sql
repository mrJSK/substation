-- ============================================================
-- Migration 004 — Complete RLS policies
-- Replaces the partial policies in 001_initial_schema.sql
-- ============================================================

-- Drop the partial policies created in 001 before redefining
do $$
declare
  r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
  loop
    execute format('drop policy if exists %I on %I', r.policyname, r.tablename);
  end loop;
end;
$$;

-- ── Helper: check if user has a permission at a specific org unit ─────────

create or replace function user_has_permission(
  p_permission_code text,
  p_org_unit_id     uuid
) returns boolean language sql stable security definer as $$
  select exists (
    select 1
    from user_role_assignments ura
    join role_permissions rp on rp.role_id = ura.role_id
    join permissions pe on pe.id = rp.permission_id
    join org_units target on target.id = p_org_unit_id
    join org_units scope  on scope.id  = ura.org_unit_id
    where ura.user_id = auth.uid()
      and pe.code = p_permission_code
      and (ura.valid_from is null or ura.valid_from <= current_date)
      and (ura.valid_to   is null or ura.valid_to   >= current_date)
      and (target.path <@ scope.path or target.id = scope.id)
  );
$$;

-- ── tenants ───────────────────────────────────────────────────────────────
alter table tenants enable row level security;

-- Superadmin only can create tenants (managed via service role key)
create policy tenants_select on tenants for select
  using (id = current_tenant_id());

-- ── org_units ─────────────────────────────────────────────────────────────
alter table org_units enable row level security;

create policy org_units_select on org_units for select
  using (tenant_id = current_tenant_id());

create policy org_units_insert on org_units for insert
  with check (
    tenant_id = current_tenant_id()
    and user_has_permission('USER_ADMIN', id)
  );

create policy org_units_update on org_units for update
  using (tenant_id = current_tenant_id())
  with check (user_has_permission('USER_ADMIN', id));

-- ── user_profiles ─────────────────────────────────────────────────────────
alter table user_profiles enable row level security;

-- Everyone in tenant can read profiles (needed for dropdowns, "assigned to")
create policy user_profiles_select on user_profiles for select
  using (tenant_id = current_tenant_id());

-- Own profile: can update own record
create policy user_profiles_update_own on user_profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and tenant_id = current_tenant_id());

-- User admins can insert / update any profile in tenant
create policy user_profiles_admin_insert on user_profiles for insert
  with check (
    tenant_id = current_tenant_id()
    and exists (
      select 1 from user_role_assignments ura
      join role_permissions rp on rp.role_id = ura.role_id
      join permissions pe on pe.id = rp.permission_id
      where ura.user_id = auth.uid() and pe.code = 'USER_ADMIN'
    )
  );

-- ── user_certificates ─────────────────────────────────────────────────────
alter table user_certificates enable row level security;

create policy user_certs_select on user_certificates for select
  using (exists (
    select 1 from user_profiles up
    where up.id = user_certificates.user_id
      and up.tenant_id = current_tenant_id()
  ));

create policy user_certs_write on user_certificates for all
  using (exists (
    select 1 from user_profiles up
    where up.id = user_certificates.user_id
      and up.tenant_id = current_tenant_id()
  ))
  with check (exists (
    select 1 from user_profiles up
    where up.id = user_certificates.user_id
      and up.tenant_id = current_tenant_id()
  ));

-- ── roles & permissions (tenant-scoped; admin-managed) ────────────────────
alter table roles enable row level security;
alter table permissions enable row level security;
alter table role_permissions enable row level security;
alter table user_role_assignments enable row level security;

create policy roles_select on roles for select
  using (tenant_id = current_tenant_id());

create policy roles_write on roles for all
  using (tenant_id = current_tenant_id())
  with check (
    tenant_id = current_tenant_id()
    and exists (
      select 1 from user_role_assignments ura
      join role_permissions rp on rp.role_id = ura.role_id
      join permissions pe on pe.id = rp.permission_id
      where ura.user_id = auth.uid() and pe.code = 'ROLE_ADMIN'
    )
  );

-- Permissions are global (seed data) — readable by everyone, writable by nobody via client
create policy permissions_select on permissions for select using (true);

create policy role_permissions_select on role_permissions for select
  using (exists (
    select 1 from roles r
    where r.id = role_permissions.role_id
      and r.tenant_id = current_tenant_id()
  ));

create policy ura_select on user_role_assignments for select
  using (exists (
    select 1 from user_profiles up
    where up.id = user_role_assignments.user_id
      and up.tenant_id = current_tenant_id()
  ));

create policy ura_write on user_role_assignments for all
  using (exists (
    select 1 from user_profiles up
    where up.id = user_role_assignments.user_id
      and up.tenant_id = current_tenant_id()
  ))
  with check (
    exists (
      select 1 from user_role_assignments ura
      join role_permissions rp on rp.role_id = ura.role_id
      join permissions pe on pe.id = rp.permission_id
      where ura.user_id = auth.uid() and pe.code = 'USER_ADMIN'
    )
  );

-- ── equipment ─────────────────────────────────────────────────────────────
alter table equipment enable row level security;

create policy equipment_select on equipment for select
  using (tenant_id = current_tenant_id());

create policy equipment_write on equipment for insert or update
  using (tenant_id = current_tenant_id())
  with check (
    tenant_id = current_tenant_id()
    and user_has_permission('ASSET_WRITE', org_unit_id)
  );

-- ── shift_logs & shift_readings ───────────────────────────────────────────
alter table shift_logs enable row level security;
alter table shift_readings enable row level security;

create policy shift_logs_select on shift_logs for select
  using (tenant_id = current_tenant_id());

create policy shift_logs_write on shift_logs for insert or update
  using (tenant_id = current_tenant_id())
  with check (user_has_permission('LOGSHEET_WRITE', substation_id));

-- Readings inherit from their shift log
create policy shift_readings_select on shift_readings for select
  using (exists (
    select 1 from shift_logs sl
    where sl.id = shift_readings.shift_log_id
      and sl.tenant_id = current_tenant_id()
  ));

create policy shift_readings_write on shift_readings for insert or update
  using (exists (
    select 1 from shift_logs sl
    where sl.id = shift_readings.shift_log_id
      and sl.tenant_id = current_tenant_id()
  ))
  with check (exists (
    select 1 from shift_logs sl
    where sl.id = shift_readings.shift_log_id
      and user_has_permission('LOGSHEET_WRITE', sl.substation_id)
  ));

-- ── ptw_requests ─────────────────────────────────────────────────────────
alter table ptw_requests enable row level security;

create policy ptw_select on ptw_requests for select
  using (tenant_id = current_tenant_id());

create policy ptw_insert on ptw_requests for insert
  with check (
    tenant_id = current_tenant_id()
    and user_has_permission('PTW_REQUEST', substation_id)
  );

create policy ptw_update on ptw_requests for update
  using (tenant_id = current_tenant_id())
  with check (
    -- Issuing: needs PTW_ISSUE
    (new.status = 'ISSUED' and user_has_permission('PTW_ISSUE', substation_id))
    -- SLDC approval: needs PTW_APPROVE_SLDC
    or (new.status = 'SLDC_APPROVED' and user_has_permission('PTW_APPROVE_SLDC', substation_id))
    -- Cancellation: needs PTW_CANCEL
    or (new.status = 'CANCELLED' and user_has_permission('PTW_CANCEL', substation_id))
    -- All other updates (isolation, return, close): PTW_ISSUE is sufficient
    or user_has_permission('PTW_ISSUE', substation_id)
  );

-- ── defects ───────────────────────────────────────────────────────────────
alter table defects enable row level security;

create policy defects_select on defects for select
  using (tenant_id = current_tenant_id());

create policy defects_insert on defects for insert
  with check (
    tenant_id = current_tenant_id()
    and user_has_permission('DEFECT_CREATE', substation_id)
  );

create policy defects_update on defects for update
  using (tenant_id = current_tenant_id())
  with check (
    user_has_permission('DEFECT_CREATE', substation_id)
    or user_has_permission('DEFECT_CLOSE', substation_id)
  );

-- ── work_orders ───────────────────────────────────────────────────────────
alter table work_orders enable row level security;

create policy wo_select on work_orders for select
  using (tenant_id = current_tenant_id());

create policy wo_insert on work_orders for insert
  with check (
    tenant_id = current_tenant_id()
    and user_has_permission('WO_CREATE', substation_id)
  );

create policy wo_update on work_orders for update
  using (tenant_id = current_tenant_id())
  with check (
    user_has_permission('WO_CREATE', substation_id)
    or user_has_permission('WO_ASSIGN', substation_id)
    or user_has_permission('WO_COMPLETE', substation_id)
  );

-- ── energy_readings ───────────────────────────────────────────────────────
alter table energy_readings enable row level security;

create policy energy_select on energy_readings for select
  using (tenant_id = current_tenant_id());

create policy energy_write on energy_readings for insert or update
  using (tenant_id = current_tenant_id())
  with check (user_has_permission('ENERGY_WRITE', substation_id));

-- ── tripping & stoppages ──────────────────────────────────────────────────
alter table tripping_events enable row level security;
alter table stoppages enable row level security;

create policy tripping_select on tripping_events for select
  using (tenant_id = current_tenant_id());

create policy tripping_write on tripping_events for insert or update
  using (tenant_id = current_tenant_id())
  with check (user_has_permission('TRIPPING_WRITE', substation_id));

create policy stoppages_select on stoppages for select
  using (tenant_id = current_tenant_id());

create policy stoppages_write on stoppages for insert or update
  using (tenant_id = current_tenant_id())
  with check (user_has_permission('STOPPAGE_WRITE', substation_id));

-- ── maintenance_plans & schedules ────────────────────────────────────────
alter table maintenance_plans enable row level security;
alter table maintenance_schedules enable row level security;

-- Plans are tenant-scoped (admins can create custom plans)
create policy maint_plans_select on maintenance_plans for select
  using (tenant_id = current_tenant_id());

create policy maint_schedules_select on maintenance_schedules for select
  using (exists (
    select 1 from equipment e where e.id = maintenance_schedules.equipment_id
      and e.tenant_id = current_tenant_id()
  ));

-- ── accident_reports ─────────────────────────────────────────────────────
alter table accident_reports enable row level security;

create policy accident_select on accident_reports for select
  using (tenant_id = current_tenant_id());

create policy accident_write on accident_reports for insert or update
  using (tenant_id = current_tenant_id())
  with check (user_has_permission('ACCIDENT_REPORT', substation_id));

-- ── audit_logs ────────────────────────────────────────────────────────────
-- Already has row-level policies in 001. Re-apply cleanly.
alter table audit_logs enable row level security;

create policy audit_logs_select on audit_logs for select
  using (tenant_id = current_tenant_id());

-- Insert: anyone in tenant (triggered server-side)
create policy audit_logs_insert on audit_logs for insert
  with check (tenant_id = current_tenant_id());

-- No update, no delete — ever
create policy audit_logs_no_update on audit_logs for update using (false);
create policy audit_logs_no_delete on audit_logs for delete using (false);
