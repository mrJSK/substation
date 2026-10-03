-- ============================================================
-- Migration 010 — Dynamic org hierarchy configuration
-- Removes hardcoded "Zone > Circle > Division" from the app.
-- Each tenant defines its own level names.
-- ============================================================

-- Per-tenant level name configuration
-- e.g. UPTCL: {1:"Zone", 2:"Circle", 3:"Division", 4:"Subdivision", 5:"Substation", 6:"Bay"}
-- e.g. MSEDCL: {1:"Region", 2:"Circle", 3:"Division", 4:"Sub-division", 5:"Substation"}
create table tenant_hierarchy_levels (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants(id) on delete cascade,
  level       smallint not null,
  level_name  text not null,          -- "Zone", "Region", "Circle", "Substation", etc.
  level_code  text,                   -- short label for UI chips: "ZN", "CR", "DIV", "SS"
  is_leaf     boolean default false,  -- true = equipment/operations happen here (usually level 5+)
  created_at  timestamptz default now(),
  unique (tenant_id, level)
);

-- Remove the hardcoded 1–6 level constraint from org_units
-- so tenants can use however many levels they need (2–8)
alter table org_units drop constraint if exists org_units_level_check;
alter table org_units add constraint org_units_level_check check (level >= 1 and level <= 10);

-- RLS for tenant_hierarchy_levels
alter table tenant_hierarchy_levels enable row level security;

create policy hier_levels_select on tenant_hierarchy_levels for select
  using (tenant_id = current_tenant_id());

create policy hier_levels_write on tenant_hierarchy_levels for all
  using (tenant_id = current_tenant_id())
  with check (
    tenant_id = current_tenant_id()
    and exists (
      select 1 from user_role_assignments ura
      join role_permissions rp on rp.role_id = ura.role_id
      join permissions pe on pe.id = rp.permission_id
      where ura.user_id = auth.uid() and pe.code = 'USER_ADMIN'
    )
  );

-- Helper: get hierarchy level name for a given org_unit
create or replace function get_level_name(p_org_unit_id uuid)
returns text language sql stable security definer as $$
  select thl.level_name
  from org_units ou
  join tenant_hierarchy_levels thl
    on thl.tenant_id = ou.tenant_id
   and thl.level     = ou.level
  where ou.id = p_org_unit_id;
$$;

-- Helper: get full hierarchy config for a tenant (used on app startup, cached 7 days)
create or replace function get_hierarchy_config(p_tenant_id uuid)
returns jsonb language sql stable security definer as $$
  select jsonb_agg(
    jsonb_build_object(
      'level',      thl.level,
      'level_name', thl.level_name,
      'level_code', thl.level_code,
      'is_leaf',    thl.is_leaf
    ) order by thl.level
  )
  from tenant_hierarchy_levels thl
  where thl.tenant_id = p_tenant_id;
$$;

-- Seed default UPTCL hierarchy (for development / demo tenant)
-- Real tenants configure their own on onboarding
insert into tenant_hierarchy_levels (tenant_id, level, level_name, level_code, is_leaf)
select
  t.id,
  v.level,
  v.level_name,
  v.level_code,
  v.is_leaf
from tenants t,
(values
  (1, 'Zone',        'ZN',  false),
  (2, 'Circle',      'CR',  false),
  (3, 'Division',    'DIV', false),
  (4, 'Subdivision', 'SD',  false),
  (5, 'Substation',  'SS',  true),
  (6, 'Bay',         'BAY', false)
) as v(level, level_name, level_code, is_leaf)
where t.is_active = true
on conflict (tenant_id, level) do nothing;
