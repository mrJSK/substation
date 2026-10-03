-- ============================================================================
-- 0100 PLATFORM  (owner: Platform team)
-- Tenancy root, shared utilities, document numbering, immutable audit trail.
-- Every other module depends on this file. Nothing here depends on them.
-- ============================================================================

create extension if not exists ltree with schema extensions;

-- ── API exposure model ─────────────────────────────────────────────────────
-- "Automatically expose new tables" is OFF for this project, so access is
-- granted here once for every object later migrations create:
--   anon          → nothing (no table access, no function execution)
--   authenticated → table DML; Row Level Security decides which rows
--   service_role  → everything (Edge Functions, provisioning)
-- Internal trigger/helper functions are revoked again in their own module.
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant usage, select on sequences to authenticated, service_role;
alter default privileges revoke execute on functions from public;   -- global: per-schema rules cannot remove it
alter default privileges in schema public revoke execute on functions from public, anon;
alter default privileges in schema public grant execute on functions to authenticated, service_role;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke truncate, trigger, references on tables from authenticated;  -- TRUNCATE bypasses RLS

-- ── Tenants: one row per licensed utility ──────────────────────────────────
create table tenants (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  short_code    text not null unique,
  utility_type  text not null check (utility_type in ('TRANSCO','DISCOM','GENCO','SLDC','OTHER')),
  state         text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ── Shared trigger: updated_at ─────────────────────────────────────────────
create function set_updated_at() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_tenants_updated_at before update on tenants
  for each row execute function set_updated_at();

-- ── Document numbering: PTW-2026-000001, WO-2026-000001 … per tenant/year ──
create table document_sequences (
  tenant_id  uuid not null references tenants(id) on delete cascade,
  doc_type   text not null,
  year       smallint not null,
  last_value integer not null default 0,
  primary key (tenant_id, doc_type, year)
);

create function next_document_number(p_tenant_id uuid, p_doc_type text, p_prefix text)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_year smallint := extract(year from now())::smallint;
  v_next integer;
begin
  insert into document_sequences (tenant_id, doc_type, year, last_value)
  values (p_tenant_id, p_doc_type, v_year, 1)
  on conflict (tenant_id, doc_type, year)
  do update set last_value = document_sequences.last_value + 1
  returning last_value into v_next;

  return format('%s-%s-%s', p_prefix, v_year, lpad(v_next::text, 6, '0'));
end;
$$;

-- ── Immutable audit trail ──────────────────────────────────────────────────
create table audit_logs (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid references tenants(id) on delete cascade,
  org_unit_id  uuid,
  actor_id     uuid,
  action       text not null,
  entity_type  text not null,
  entity_id    uuid,
  old_data     jsonb,
  new_data     jsonb,
  created_at   timestamptz not null default now()
);

create index audit_logs_tenant_time_idx on audit_logs (tenant_id, created_at desc);
create index audit_logs_entity_idx on audit_logs (entity_type, entity_id);

-- Attach with: create trigger … after insert or update or delete … execute function audit_row_change();
create function audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_row jsonb := to_jsonb(coalesce(new, old));
begin
  insert into audit_logs (tenant_id, org_unit_id, actor_id, action, entity_type, entity_id, old_data, new_data)
  values (
    (v_row ->> 'tenant_id')::uuid,
    (v_row ->> 'org_unit_id')::uuid,
    auth.uid(),
    tg_op,
    tg_table_name,
    (v_row ->> 'id')::uuid,
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end;
$$;

revoke execute on function set_updated_at() from public, anon, authenticated;
revoke execute on function audit_row_change() from public, anon, authenticated;
revoke execute on function next_document_number(uuid, text, text) from public, anon, authenticated;

alter table tenants            enable row level security;
alter table document_sequences enable row level security;
alter table audit_logs         enable row level security;
-- Policies for these tables live in 0300_iam (they need the access functions).
-- document_sequences has no policies: only next_document_number() touches it.
