-- ============================================================================
-- 0300 IAM — Identity & Access Management  (owner: Security / IAM team)
--
-- Authorization = WHO × WHAT × WHERE
--   WHO   : user_profiles                     (a person in a tenant)
--   WHAT  : permissions → role_permissions → roles   (SAP: auth objects in a role)
--   WHERE : user_role_assignments.org_unit_id  (scope; optionally + all descendants)
-- Plus time validity (valid_from / valid_to) and cross-level sharing (org_unit_shares).
--
-- This file also owns every access-control function and the RLS policies of
-- the platform and org tables. Domain modules only CALL these functions.
-- ============================================================================

set search_path = public, extensions;  -- ltree lives in the extensions schema

-- ── WHO: user profiles (1:1 with auth.users) ───────────────────────────────
create table user_profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  tenant_id         uuid not null references tenants(id) on delete cascade,
  full_name         text not null,
  email             text,
  employee_id       text,
  designation       text,
  phone             text,
  home_org_unit_id  uuid references org_units(id) on delete set null,  -- primary posting
  is_active         boolean not null default true,
  valid_from        date not null default current_date,
  valid_to          date,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (tenant_id, employee_id)
);

create index user_profiles_tenant_idx on user_profiles (tenant_id);

create trigger trg_user_profiles_updated_at before update on user_profiles
  for each row execute function set_updated_at();

-- Statutory competency certificates (CEA staff qualification)
create table user_certificates (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  user_id       uuid not null references user_profiles(id) on delete cascade,
  cert_type     text not null,
  cert_number   text,
  issued_by     text,
  valid_from    date,
  valid_to      date,
  document_path text,
  created_at    timestamptz not null default now()
);

-- ── WHAT: permission catalog (global, platform-managed) ────────────────────
create table permissions (
  code         text primary key,
  module       text not null,
  description  text not null,
  sort_order   smallint not null default 0
);

-- Roles: tenant_id NULL = standard template shipped with the product (read-only).
-- Tenants copy a template (clone_role) to customise it — the SAP PFCG pattern.
create table roles (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid references tenants(id) on delete cascade,
  code         text not null,
  name         text not null,
  description  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique nulls not distinct (tenant_id, code)
);

create trigger trg_roles_updated_at before update on roles
  for each row execute function set_updated_at();

create table role_permissions (
  role_id          uuid not null references roles(id) on delete cascade,
  permission_code  text not null references permissions(code) on delete cascade,
  primary key (role_id, permission_code)
);

-- ── WHERE: scoped, time-bound role assignments ─────────────────────────────
create table user_role_assignments (
  id                   uuid primary key default gen_random_uuid(),
  tenant_id            uuid not null references tenants(id) on delete cascade,
  user_id              uuid not null references user_profiles(id) on delete cascade,
  role_id              uuid not null references roles(id) on delete cascade,
  org_unit_id          uuid not null references org_units(id) on delete cascade,
  include_descendants  boolean not null default true,
  valid_from           date not null default current_date,
  valid_to             date,
  assigned_by          uuid default auth.uid(),
  created_at           timestamptz not null default now(),
  unique (user_id, role_id, org_unit_id),
  check (valid_to is null or valid_to >= valid_from)
);

create index ura_user_idx on user_role_assignments (user_id);
create index ura_org_idx  on user_role_assignments (org_unit_id);

-- ============================================================================
-- ACCESS FUNCTIONS — the single source of truth for authorization.
-- security definer: they read IAM tables regardless of the caller's RLS.
-- ============================================================================

create function current_tenant_id() returns uuid
language sql stable security definer set search_path = public as $$
  select tenant_id from user_profiles
  where id = auth.uid() and is_active
    and current_date between valid_from and coalesce(valid_to, 'infinity'::date);
$$;

-- Active assignments of the caller, with the scope path.
create function my_active_scopes()
returns table (assignment_id uuid, role_id uuid, org_unit_id uuid, scope_path ltree, include_descendants boolean)
language sql stable security definer set search_path = public, extensions as $$
  select a.id, a.role_id, a.org_unit_id, s.path, a.include_descendants
  from user_role_assignments a
  join org_units s      on s.id = a.org_unit_id
  join user_profiles u  on u.id = a.user_id
  where a.user_id = auth.uid()
    and u.is_active
    and current_date between u.valid_from and coalesce(u.valid_to, 'infinity'::date)
    and current_date between a.valid_from and coalesce(a.valid_to, 'infinity'::date);
$$;

-- Does the caller hold permission p_code at unit p_org_unit_id?
create function user_has_permission(p_code text, p_org_unit_id uuid) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1
    from my_active_scopes() m
    join role_permissions rp on rp.role_id = m.role_id and rp.permission_code = p_code
    join org_units t on t.id = p_org_unit_id
    where t.id = m.org_unit_id or (m.include_descendants and t.path <@ m.scope_path)
  );
$$;

-- Tenant-wide permission = held at a root unit with descendants (e.g. ROLE_ADMIN).
create function user_has_tenant_permission(p_code text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1
    from my_active_scopes() m
    join role_permissions rp on rp.role_id = m.role_id and rp.permission_code = p_code
    join org_units s on s.id = m.org_unit_id
    where s.parent_id is null and m.include_descendants
  );
$$;

-- Can the caller see data belonging to this unit?
-- Yes if any active assignment covers it, or a valid share grants it.
create function can_read_org_unit(p_org_unit_id uuid) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  with t as (select id, path from org_units where id = p_org_unit_id),
       m as (select * from my_active_scopes())
  select exists (
           select 1 from m, t
           where t.id = m.org_unit_id or (m.include_descendants and t.path <@ m.scope_path)
         )
      or exists (
           select 1
           from org_unit_shares sh
           join org_units src on src.id = sh.source_org_unit_id
           join org_units tgt on tgt.id = sh.target_org_unit_id
           cross join t
           join m on (tgt.id = m.org_unit_id or (m.include_descendants and tgt.path <@ m.scope_path))
           where t.path <@ src.path
             and current_date between sh.valid_from and coalesce(sh.valid_to, 'infinity'::date)
         );
$$;

-- Permissions the caller holds at one unit (server-side check / debugging).
create function get_user_permissions(p_org_unit_id uuid) returns text[]
language sql stable security definer set search_path = public, extensions as $$
  select coalesce(array_agg(distinct rp.permission_code order by rp.permission_code), '{}')
  from my_active_scopes() m
  join role_permissions rp on rp.role_id = m.role_id
  join org_units t on t.id = p_org_unit_id
  where t.id = m.org_unit_id or (m.include_descendants and t.path <@ m.scope_path);
$$;

-- Session bootstrap: ONE call after login, cached on device.
-- The app evaluates permissions locally from this (works offline).
create function get_my_access() returns jsonb
language sql stable security definer set search_path = public, extensions as $$
  select jsonb_build_object(
    'profile', jsonb_build_object(
      'id', u.id, 'full_name', u.full_name, 'email', u.email,
      'employee_id', u.employee_id, 'designation', u.designation, 'phone', u.phone,
      'home_org_unit_id', u.home_org_unit_id
    ),
    'tenant', jsonb_build_object('id', t.id, 'name', t.name, 'short_code', t.short_code),
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'assignment_id', m.assignment_id,
        'role_id', r.id, 'role_code', r.code, 'role_name', r.name,
        'org_unit_id', m.org_unit_id, 'org_unit_name', s.name,
        'scope_path', m.scope_path::text,
        'include_descendants', m.include_descendants,
        'permissions', coalesce((select jsonb_agg(rp.permission_code order by rp.permission_code)
                                 from role_permissions rp where rp.role_id = r.id), '[]'::jsonb)
      ))
      from my_active_scopes() m
      join roles r     on r.id = m.role_id
      join org_units s on s.id = m.org_unit_id
    ), '[]'::jsonb),
    'issued_at', now()
  )
  from user_profiles u
  join tenants t on t.id = u.tenant_id
  where u.id = auth.uid() and u.is_active and t.is_active;
$$;

-- Units the caller can work in (unit picker). Optionally only operational levels.
create function get_accessible_org_units(p_operational_only boolean default false)
returns setof org_tree
language sql stable security invoker set search_path = public, extensions as $$
  select ot.* from org_tree ot
  where can_read_org_unit(ot.id)
    and (not p_operational_only or ot.is_operational)
  order by ot.path;
$$;

-- Org breadcrumbs for any unit, root first.
create function get_org_ancestors(p_org_unit_id uuid)
returns setof org_tree
language sql stable security invoker set search_path = public, extensions as $$
  select a.* from org_tree a, org_units t
  where t.id = p_org_unit_id and a.path::ltree @> t.path
  order by a.depth;
$$;

-- Copy a role (template or tenant role) into the caller's tenant for customisation.
create function clone_role(p_source_role_id uuid, p_code text, p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_tenant uuid := current_tenant_id();
  v_new    uuid;
begin
  if not user_has_tenant_permission('ROLE_ADMIN') then
    raise exception 'ROLE_ADMIN at tenant level is required';
  end if;
  if not exists (select 1 from roles where id = p_source_role_id and (tenant_id is null or tenant_id = v_tenant)) then
    raise exception 'Source role not found';
  end if;

  insert into roles (tenant_id, code, name, description)
  select v_tenant, p_code, p_name, description from roles where id = p_source_role_id
  returning id into v_new;

  insert into role_permissions (role_id, permission_code)
  select v_new, permission_code from role_permissions where role_id = p_source_role_id;

  return v_new;
end;
$$;

-- ── Assignment guard: tenant consistency + no privilege escalation ─────────
-- A granter may only hand out permissions they themselves hold at that scope.
create function user_role_assignments_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_missing text;
begin
  if not exists (select 1 from user_profiles where id = new.user_id and tenant_id = new.tenant_id)
     or not exists (select 1 from org_units where id = new.org_unit_id and tenant_id = new.tenant_id)
     or not exists (select 1 from roles where id = new.role_id and (tenant_id is null or tenant_id = new.tenant_id)) then
    raise exception 'User, role and scope must belong to the same tenant';
  end if;

  if auth.uid() is not null then  -- service role / migrations bypass
    select rp.permission_code into v_missing
    from role_permissions rp
    where rp.role_id = new.role_id
      and not user_has_permission(rp.permission_code, new.org_unit_id)
    limit 1;
    if v_missing is not null then
      raise exception 'You cannot grant % at this scope because you do not hold it yourself', v_missing;
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_ura_guard before insert or update on user_role_assignments
  for each row execute function user_role_assignments_guard();

create trigger trg_ura_audit after insert or update or delete on user_role_assignments
  for each row execute function audit_row_change();
create trigger trg_role_permissions_audit after insert or update or delete on role_permissions
  for each row execute function audit_row_change();
create trigger trg_user_profiles_audit after insert or update or delete on user_profiles
  for each row execute function audit_row_change();
create trigger trg_org_units_audit after insert or update or delete on org_units
  for each row execute function audit_row_change();

-- ── Tenant provisioning (platform operator only, via service role) ─────────
-- p_levels: [{"rank":1,"name":"Zone","code":"ZN","is_operational":false}, …]
create function provision_tenant(
  p_name text, p_short_code text, p_utility_type text, p_state text,
  p_levels jsonb, p_root_name text, p_root_code text,
  p_admin_user_id uuid, p_admin_full_name text
) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_tenant uuid;
  v_root_level uuid;
  v_root uuid;
  v_admin_role uuid;
begin
  insert into tenants (name, short_code, utility_type, state)
  values (p_name, p_short_code, p_utility_type, p_state)
  returning id into v_tenant;

  insert into org_levels (tenant_id, rank, name, code, is_operational)
  select v_tenant, (l->>'rank')::smallint, l->>'name', l->>'code', coalesce((l->>'is_operational')::boolean, false)
  from jsonb_array_elements(p_levels) l;

  select id into v_root_level from org_levels where tenant_id = v_tenant order by rank limit 1;

  insert into org_units (tenant_id, level_id, name, code)
  values (v_tenant, v_root_level, p_root_name, p_root_code)
  returning id into v_root;

  insert into user_profiles (id, tenant_id, full_name, email, home_org_unit_id)
  select p_admin_user_id, v_tenant, p_admin_full_name, au.email, v_root
  from auth.users au where au.id = p_admin_user_id;

  select id into v_admin_role from roles where tenant_id is null and code = 'TENANT_ADMIN';

  insert into user_role_assignments (tenant_id, user_id, role_id, org_unit_id)
  values (v_tenant, p_admin_user_id, v_admin_role, v_root);

  return v_tenant;
end;
$$;

revoke execute on function provision_tenant(text,text,text,text,jsonb,text,text,uuid,text) from public, anon, authenticated;
revoke execute on function user_role_assignments_guard() from public, anon, authenticated;

-- ============================================================================
-- RLS — platform, org and IAM tables
-- ============================================================================
alter table user_profiles          enable row level security;
alter table user_certificates      enable row level security;
alter table permissions            enable row level security;
alter table roles                  enable row level security;
alter table role_permissions       enable row level security;
alter table user_role_assignments  enable row level security;

-- tenants: read own tenant only; writes via provision_tenant (service role)
create policy tenants_read on tenants for select to authenticated
  using (id = current_tenant_id());

-- audit_logs: read-only for AUDIT_VIEW holders; rows written by audit_row_change()
create policy audit_logs_read on audit_logs for select to authenticated
  using (tenant_id = current_tenant_id()
         and (user_has_tenant_permission('AUDIT_VIEW')
              or (org_unit_id is not null and user_has_permission('AUDIT_VIEW', org_unit_id))));

-- org_levels: everyone in tenant reads; tenant-level ORG_ADMIN writes
create policy org_levels_read on org_levels for select to authenticated
  using (tenant_id = current_tenant_id());
create policy org_levels_insert on org_levels for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('ORG_ADMIN'));
create policy org_levels_update on org_levels for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('ORG_ADMIN'))
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('ORG_ADMIN'));
create policy org_levels_delete on org_levels for delete to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('ORG_ADMIN'));

-- org_units: structure is visible tenant-wide (pickers, breadcrumbs);
-- changes need ORG_ADMIN over the affected branch.
create policy org_units_read on org_units for select to authenticated
  using (tenant_id = current_tenant_id());
create policy org_units_insert on org_units for insert to authenticated
  with check (tenant_id = current_tenant_id() and (
    (parent_id is not null and user_has_permission('ORG_ADMIN', parent_id))
    or (parent_id is null and user_has_tenant_permission('ORG_ADMIN'))));
create policy org_units_update on org_units for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('ORG_ADMIN', id))
  with check (tenant_id = current_tenant_id() and (
    (parent_id is not null and user_has_permission('ORG_ADMIN', parent_id))
    or (parent_id is null and user_has_tenant_permission('ORG_ADMIN'))));
create policy org_units_delete on org_units for delete to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('ORG_ADMIN', id));

-- org_unit_shares: read tenant-wide; ORG_ADMIN over the source branch manages them
create policy org_shares_read on org_unit_shares for select to authenticated
  using (tenant_id = current_tenant_id());
create policy org_shares_insert on org_unit_shares for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('ORG_ADMIN', source_org_unit_id));
create policy org_shares_update on org_unit_shares for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('ORG_ADMIN', source_org_unit_id))
  with check (tenant_id = current_tenant_id() and user_has_permission('ORG_ADMIN', source_org_unit_id));
create policy org_shares_delete on org_unit_shares for delete to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('ORG_ADMIN', source_org_unit_id));

-- user_profiles: colleagues visible tenant-wide; USER_ADMIN over the home unit edits.
-- Inserts happen through the iam-admin-users Edge Function (service role).
create policy user_profiles_read on user_profiles for select to authenticated
  using (tenant_id = current_tenant_id() or id = (select auth.uid()));
create policy user_profiles_update on user_profiles for update to authenticated
  using (tenant_id = current_tenant_id() and (
    (home_org_unit_id is not null and user_has_permission('USER_ADMIN', home_org_unit_id))
    or user_has_tenant_permission('USER_ADMIN')))
  with check (tenant_id = current_tenant_id() and (
    (home_org_unit_id is not null and user_has_permission('USER_ADMIN', home_org_unit_id))
    or user_has_tenant_permission('USER_ADMIN')));

create policy user_certs_read on user_certificates for select to authenticated
  using (tenant_id = current_tenant_id());
create policy user_certs_insert on user_certificates for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('USER_ADMIN'));
create policy user_certs_update on user_certificates for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('USER_ADMIN'))
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('USER_ADMIN'));
create policy user_certs_delete on user_certificates for delete to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('USER_ADMIN'));

-- permissions catalog: read-only for everyone signed in
create policy permissions_read on permissions for select to authenticated using (true);

-- roles: templates + own tenant visible; only own-tenant roles editable
create policy roles_read on roles for select to authenticated
  using (tenant_id is null or tenant_id = current_tenant_id());
create policy roles_insert on roles for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('ROLE_ADMIN'));
create policy roles_update on roles for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('ROLE_ADMIN'))
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('ROLE_ADMIN'));
create policy roles_delete on roles for delete to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('ROLE_ADMIN'));

create policy role_permissions_read on role_permissions for select to authenticated
  using (exists (select 1 from roles r where r.id = role_id
                 and (r.tenant_id is null or r.tenant_id = current_tenant_id())));
create policy role_permissions_insert on role_permissions for insert to authenticated
  with check (exists (select 1 from roles r where r.id = role_id and r.tenant_id = current_tenant_id())
              and user_has_tenant_permission('ROLE_ADMIN'));
create policy role_permissions_delete on role_permissions for delete to authenticated
  using (exists (select 1 from roles r where r.id = role_id and r.tenant_id = current_tenant_id())
         and user_has_tenant_permission('ROLE_ADMIN'));

-- assignments: visible tenant-wide; USER_ADMIN at the scope grants/revokes
create policy ura_read on user_role_assignments for select to authenticated
  using (tenant_id = current_tenant_id());
create policy ura_insert on user_role_assignments for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('USER_ADMIN', org_unit_id));
create policy ura_update on user_role_assignments for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('USER_ADMIN', org_unit_id))
  with check (tenant_id = current_tenant_id() and user_has_permission('USER_ADMIN', org_unit_id));
create policy ura_delete on user_role_assignments for delete to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('USER_ADMIN', org_unit_id));

-- ============================================================================
-- SEED: permission catalog + standard role templates
-- ============================================================================
insert into permissions (code, module, description, sort_order) values
  ('LOGSHEET_READ',    'OPERATIONS',  'View shift logsheets',                          10),
  ('LOGSHEET_WRITE',   'OPERATIONS',  'Create and update shift logsheet entries',      11),
  ('TRIPPING_WRITE',   'OPERATIONS',  'Record tripping events (Reg 10)',               12),
  ('STOPPAGE_WRITE',   'OPERATIONS',  'Record stoppages (Reg 11)',                     13),
  ('MESSAGE_WRITE',    'OPERATIONS',  'Log SLDC messages',                             14),
  ('PTW_REQUEST',      'PTW',         'Raise shutdown / PTW requests',                 20),
  ('PTW_ISSUE',        'PTW',         'Isolate, issue, return and close permits',      21),
  ('PTW_APPROVE_SLDC', 'PTW',         'Record SLDC approval for shutdown',             22),
  ('PTW_CANCEL',       'PTW',         'Cancel a permit',                               23),
  ('DEFECT_CREATE',    'MAINTENANCE', 'Report defects (Reg 7)',                        30),
  ('DEFECT_CLOSE',     'MAINTENANCE', 'Close defects',                                 31),
  ('WO_CREATE',        'MAINTENANCE', 'Create work orders',                            32),
  ('WO_ASSIGN',        'MAINTENANCE', 'Assign work orders',                            33),
  ('WO_COMPLETE',      'MAINTENANCE', 'Complete work orders with test results',        34),
  ('MAINT_PLAN_ADMIN', 'MAINTENANCE', 'Manage maintenance plans and schedules',        35),
  ('ASSET_READ',       'ASSETS',      'View equipment master',                         40),
  ('ASSET_WRITE',      'ASSETS',      'Create and update equipment master',            41),
  ('ENERGY_READ',      'ENERGY',      'View energy accounts',                          50),
  ('ENERGY_WRITE',     'ENERGY',      'Enter meter readings (Reg 8)',                  51),
  ('ENERGY_APPROVE',   'ENERGY',      'Approve monthly energy balance',                52),
  ('ACCIDENT_REPORT',  'SAFETY',      'File accident / dangerous occurrence reports',  60),
  ('REPORT_VIEW',      'REPORTS',     'View dashboards and reliability reports',       70),
  ('ORG_ADMIN',        'ADMIN',       'Manage hierarchy levels, org units and sharing',80),
  ('USER_ADMIN',       'ADMIN',       'Create users and assign roles',                 81),
  ('ROLE_ADMIN',       'ADMIN',       'Create roles and edit their permissions',       82),
  ('UI_ADMIN',         'ADMIN',       'Manage micro-apps and dynamic forms',           83),
  ('AUDIT_VIEW',       'ADMIN',       'View the audit trail',                          84);

insert into roles (tenant_id, code, name, description) values
  (null, 'SHIFT_ENGINEER', 'Shift Engineer',                    'Shift in-charge: operations, PTW issuer'),
  (null, 'JE_OPERATIONS',  'Junior Engineer (Operations)',      'Logsheet, tripping and stoppage entries'),
  (null, 'OPERATOR',       'Substation Operator',               'Shift readings and defect reporting'),
  (null, 'JE_MAINTENANCE', 'Junior Engineer (Maintenance)',     'Work orders and testing'),
  (null, 'AE_MAINTENANCE', 'Assistant Engineer (Maintenance)',  'Assigns work, approves energy'),
  (null, 'AE_OPERATIONS',  'Assistant Engineer (Operations)',   'Reviews operations, SLDC approvals'),
  (null, 'EXECUTIVE_ENGINEER', 'Executive Engineer',            'Oversight and approvals for a branch'),
  (null, 'TENANT_ADMIN',   'Tenant Administrator',              'Full access including administration');

insert into role_permissions (role_id, permission_code)
select r.id, p.code
from roles r
join permissions p on case r.code
  when 'SHIFT_ENGINEER' then p.code in ('LOGSHEET_READ','LOGSHEET_WRITE','TRIPPING_WRITE','STOPPAGE_WRITE','MESSAGE_WRITE',
                                        'PTW_REQUEST','PTW_ISSUE','PTW_APPROVE_SLDC','PTW_CANCEL','DEFECT_CREATE',
                                        'ASSET_READ','ENERGY_READ','ENERGY_WRITE','ACCIDENT_REPORT','REPORT_VIEW')
  when 'JE_OPERATIONS'  then p.code in ('LOGSHEET_READ','LOGSHEET_WRITE','TRIPPING_WRITE','STOPPAGE_WRITE','MESSAGE_WRITE',
                                        'PTW_REQUEST','DEFECT_CREATE','ASSET_READ','ENERGY_READ','ENERGY_WRITE','REPORT_VIEW')
  when 'OPERATOR'       then p.code in ('LOGSHEET_READ','LOGSHEET_WRITE','DEFECT_CREATE','ASSET_READ')
  when 'JE_MAINTENANCE' then p.code in ('LOGSHEET_READ','DEFECT_CREATE','DEFECT_CLOSE','WO_CREATE','WO_COMPLETE',
                                        'PTW_REQUEST','ASSET_READ','ENERGY_READ','REPORT_VIEW')
  when 'AE_MAINTENANCE' then p.code in ('LOGSHEET_READ','DEFECT_CREATE','DEFECT_CLOSE','WO_CREATE','WO_ASSIGN','WO_COMPLETE',
                                        'MAINT_PLAN_ADMIN','PTW_REQUEST','ASSET_READ','ASSET_WRITE',
                                        'ENERGY_READ','ENERGY_WRITE','ENERGY_APPROVE','REPORT_VIEW')
  when 'AE_OPERATIONS'  then p.code in ('LOGSHEET_READ','LOGSHEET_WRITE','TRIPPING_WRITE','STOPPAGE_WRITE','MESSAGE_WRITE',
                                        'PTW_REQUEST','PTW_APPROVE_SLDC','DEFECT_CREATE','DEFECT_CLOSE','ASSET_READ',
                                        'ENERGY_READ','ENERGY_WRITE','ACCIDENT_REPORT','REPORT_VIEW')
  when 'EXECUTIVE_ENGINEER' then p.module <> 'ADMIN'
  when 'TENANT_ADMIN'   then true
  else false
end
where r.tenant_id is null;
