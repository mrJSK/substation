-- ============================================================================
-- 0200 ORG HIERARCHY  (owner: Org Structure team)
-- Fully tenant-defined hierarchy. Nothing about "Zone/Circle/Substation" is
-- hard-coded: each tenant defines its own levels, names and depth.
--   UPPTCL : Zone > Circle > Division > Substation > Bay
--   MSEDCL : Region > Zone > Circle > Division > Sub-division > Substation
--   Small  : Company > Substation
-- Ragged trees are allowed: a unit only needs a level ranked below its parent,
-- so a Substation may sit directly under a Division where that is the reality.
-- RLS for these tables is in 0300_iam.
-- ============================================================================

set search_path = public, extensions;  -- ltree lives in the extensions schema

-- ── Level definitions per tenant ───────────────────────────────────────────
create table org_levels (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id) on delete cascade,
  rank            smallint not null check (rank between 1 and 20),  -- 1 = top
  name            text not null,
  code            text not null,
  is_operational  boolean not null default false,  -- shifts, logsheets, PTW happen at units of this level
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (tenant_id, rank),
  unique (tenant_id, code),
  unique (tenant_id, name)
);

create trigger trg_org_levels_updated_at before update on org_levels
  for each row execute function set_updated_at();

-- ── Org units (any depth) ──────────────────────────────────────────────────
create table org_units (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references tenants(id) on delete cascade,
  parent_id        uuid references org_units(id) on delete restrict,
  level_id         uuid not null references org_levels(id) on delete restrict,
  name             text not null,
  code             text not null,
  path             ltree not null,                -- maintained by trigger; never set from the client
  voltage_kv       numeric,
  total_consumers  integer not null default 0,    -- used for SAIDI/SAIFI at any level
  latitude         numeric,
  longitude        numeric,
  attributes       jsonb not null default '{}',   -- tenant-specific extras, rendered via dynamic forms
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (tenant_id, code)
);

create index org_units_path_gist   on org_units using gist (path);
create index org_units_parent_idx  on org_units (parent_id);
create index org_units_level_idx   on org_units (level_id);

create trigger trg_org_units_updated_at before update on org_units
  for each row execute function set_updated_at();

-- Validates placement and computes the materialized path.
create function org_units_before_write() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_rank          smallint;
  v_level_tenant  uuid;
  v_parent        org_units;
  v_parent_rank   smallint;
  v_label         ltree := text2ltree(replace(new.id::text, '-', ''));
begin
  select rank, tenant_id into v_rank, v_level_tenant from org_levels where id = new.level_id;
  if v_level_tenant is distinct from new.tenant_id then
    raise exception 'Level does not belong to this tenant';
  end if;

  if new.parent_id is null then
    new.path := v_label;
  else
    select * into v_parent from org_units where id = new.parent_id;
    if v_parent.tenant_id is distinct from new.tenant_id then
      raise exception 'Parent unit does not belong to this tenant';
    end if;
    select rank into v_parent_rank from org_levels where id = v_parent.level_id;
    if v_rank <= v_parent_rank then
      raise exception 'A unit must be at a lower level than its parent';
    end if;
    if tg_op = 'UPDATE' and v_parent.path <@ old.path then
      raise exception 'A unit cannot be moved under itself or its own descendant';
    end if;
    new.path := v_parent.path || v_label;
  end if;

  if tg_op = 'UPDATE' and new.level_id <> old.level_id and exists (
    select 1 from org_units c join org_levels l on l.id = c.level_id
    where c.parent_id = new.id and l.rank <= v_rank
  ) then
    raise exception 'Children would no longer be below this unit''s level';
  end if;

  return new;
end;
$$;

create trigger trg_org_units_before_write
  before insert or update of parent_id, level_id on org_units
  for each row execute function org_units_before_write();

-- Moving a unit re-paths its whole subtree.
create function org_units_after_move() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  if new.path is distinct from old.path then
    update org_units
       set path = new.path || subpath(path, nlevel(old.path))
     where path <@ old.path and id <> new.id;
  end if;
  return null;
end;
$$;

create trigger trg_org_units_after_move
  after update of parent_id on org_units
  for each row execute function org_units_after_move();

-- A level's rank cannot change once units use it (would break the ordering rule).
create function org_levels_guard_rank() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.rank <> old.rank and exists (select 1 from org_units where level_id = old.id) then
    raise exception 'Cannot change the rank of a level that already has units';
  end if;
  return new;
end;
$$;

create trigger trg_org_levels_guard_rank before update of rank on org_levels
  for each row execute function org_levels_guard_rank();

-- ── Cross-level data sharing ───────────────────────────────────────────────
-- Users whose scope covers TARGET can read data of SOURCE and its whole subtree.
-- Works between any two units at any levels (e.g. SLDC reads a Substation,
-- a neighbouring Circle reads a shared tie-line Substation).
create table org_unit_shares (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references tenants(id) on delete cascade,
  source_org_unit_id  uuid not null references org_units(id) on delete cascade,
  target_org_unit_id  uuid not null references org_units(id) on delete cascade,
  valid_from          date not null default current_date,
  valid_to            date,
  reason              text,
  created_by          uuid default auth.uid(),
  created_at          timestamptz not null default now(),
  unique (source_org_unit_id, target_org_unit_id),
  check (source_org_unit_id <> target_org_unit_id)
);

-- ── Read model: the tree with level names (RLS of the caller applies) ──────
create view org_tree with (security_invoker = true) as
select
  u.id, u.tenant_id, u.parent_id, u.name, u.code,
  u.path::text          as path,
  nlevel(u.path)        as depth,
  u.level_id, l.name    as level_name, l.code as level_code, l.rank as level_rank,
  l.is_operational,
  u.voltage_kv, u.total_consumers, u.latitude, u.longitude, u.attributes, u.is_active
from org_units u
join org_levels l on l.id = u.level_id;

revoke execute on function org_units_before_write() from public, anon, authenticated;
revoke execute on function org_units_after_move() from public, anon, authenticated;
revoke execute on function org_levels_guard_rank() from public, anon, authenticated;

alter table org_levels      enable row level security;
alter table org_units       enable row level security;
alter table org_unit_shares enable row level security;
