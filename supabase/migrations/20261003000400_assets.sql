-- ============================================================================
-- 0400 ASSETS  (owner: Asset Management team)
-- Equipment master (SAP PM: equipment at a functional location) and the
-- Plant History Register (Reg 2).
-- ============================================================================

create table equipment (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id       uuid not null references org_units(id) on delete restrict,
  parent_id         uuid references equipment(id) on delete restrict,   -- sub-component
  asset_tag         text not null,
  name              text not null,
  equipment_type    text not null,        -- TRANSFORMER, CB, CT, PT, LA, BATTERY, ISOLATOR, RELAY …
  manufacturer      text,
  model             text,
  serial_number     text,
  year_of_mfg       smallint,
  commissioned_on   date,
  warranty_expiry   date,
  technical_params  jsonb not null default '{}',   -- rendered via dynamic forms per type
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (tenant_id, asset_tag)
);

create index equipment_org_idx  on equipment (org_unit_id);
create index equipment_type_idx on equipment (tenant_id, equipment_type);

create trigger trg_equipment_updated_at before update on equipment
  for each row execute function set_updated_at();
create trigger trg_equipment_audit after insert or update or delete on equipment
  for each row execute function audit_row_change();

create table equipment_history (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  equipment_id   uuid not null references equipment(id) on delete cascade,
  event_type     text not null,    -- COMMISSIONING, OVERHAUL, REPLACEMENT, INCIDENT, TEST
  event_at       timestamptz not null,
  description    text not null,
  done_by        uuid references user_profiles(id),
  document_paths text[] not null default '{}',
  created_at     timestamptz not null default now()
);

create index equipment_history_eq_idx on equipment_history (equipment_id, event_at desc);

alter table equipment         enable row level security;
alter table equipment_history enable row level security;

create policy equipment_read on equipment for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy equipment_insert on equipment for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('ASSET_WRITE', org_unit_id));
create policy equipment_update on equipment for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('ASSET_WRITE', org_unit_id))
  with check (tenant_id = current_tenant_id() and user_has_permission('ASSET_WRITE', org_unit_id));

create policy equipment_history_read on equipment_history for select to authenticated
  using (exists (select 1 from equipment e where e.id = equipment_id
                 and e.tenant_id = current_tenant_id() and can_read_org_unit(e.org_unit_id)));
create policy equipment_history_insert on equipment_history for insert to authenticated
  with check (exists (select 1 from equipment e where e.id = equipment_id
                      and e.tenant_id = current_tenant_id()
                      and (user_has_permission('ASSET_WRITE', e.org_unit_id)
                           or user_has_permission('WO_COMPLETE', e.org_unit_id))));
-- Plant history is a statutory register: no update or delete policies.
