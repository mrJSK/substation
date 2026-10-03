-- ============================================================================
-- 0800 ENERGY  (owner: Energy Accounting team)
-- Energy Account Register (Reg 8). One cumulative meter reading per meter
-- point per day; net energy = (reading − previous reading) × MF, computed here.
-- ============================================================================

set search_path = public, extensions;  -- ltree lives in the extensions schema

create table energy_readings (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id         uuid not null references org_units(id) on delete restrict,
  equipment_id        uuid not null references equipment(id) on delete restrict,
  reading_date        date not null,
  reading_type        text not null check (reading_type in ('IMPORT','EXPORT')),
  meter_reading       numeric not null check (meter_reading >= 0),
  multiplying_factor  numeric not null default 1 check (multiplying_factor > 0),
  net_energy_kwh      numeric,
  is_meter_reset      boolean not null default false,  -- meter replaced/rolled over: no delta for this day
  recorded_by         uuid default auth.uid() references user_profiles(id),
  approved_by         uuid references user_profiles(id),
  approved_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (equipment_id, reading_date, reading_type)
);

create index energy_org_date_idx on energy_readings (org_unit_id, reading_date);

create trigger trg_energy_updated_at before update on energy_readings
  for each row execute function set_updated_at();
create trigger trg_energy_audit after insert or update or delete on energy_readings
  for each row execute function audit_row_change();

create function energy_readings_compute_net() returns trigger
language plpgsql set search_path = public as $$
declare
  v_prev numeric;
begin
  if new.is_meter_reset then
    new.net_energy_kwh := null;
    return new;
  end if;

  select meter_reading into v_prev
  from energy_readings
  where equipment_id = new.equipment_id
    and reading_type = new.reading_type
    and reading_date < new.reading_date
  order by reading_date desc
  limit 1;

  new.net_energy_kwh := case when v_prev is null then null
                             else (new.meter_reading - v_prev) * new.multiplying_factor end;
  if new.net_energy_kwh < 0 then
    raise exception 'Meter reading is lower than the previous reading; mark it as a meter reset if the meter was replaced';
  end if;
  return new;
end;
$$;

create trigger trg_energy_compute_net before insert or update of meter_reading, multiplying_factor, is_meter_reset
  on energy_readings for each row execute function energy_readings_compute_net();

-- Balance for any unit, aggregated over its subtree.
create function compute_energy_balance(p_org_unit_id uuid, p_year integer, p_month integer)
returns jsonb
language sql stable security invoker set search_path = public, extensions as $$
  with r as (
    select er.reading_type, er.net_energy_kwh
    from energy_readings er
    join org_units u on u.id = er.org_unit_id
    where u.path <@ (select path from org_units where id = p_org_unit_id)
      and extract(year from er.reading_date) = p_year
      and (p_month = 0 or extract(month from er.reading_date) = p_month)
  ), t as (
    select coalesce(sum(net_energy_kwh) filter (where reading_type = 'IMPORT'), 0) as import_kwh,
           coalesce(sum(net_energy_kwh) filter (where reading_type = 'EXPORT'), 0) as export_kwh
    from r
  )
  select jsonb_build_object(
    'import_kwh',   round(import_kwh, 2),
    'export_kwh',   round(export_kwh, 2),
    'loss_kwh',     round(import_kwh - export_kwh, 2),
    'loss_percent', round(100.0 * (import_kwh - export_kwh) / nullif(import_kwh, 0), 2)
  )
  from t;
$$;

revoke execute on function energy_readings_compute_net() from public, anon, authenticated;

alter table energy_readings enable row level security;

create policy energy_read on energy_readings for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy energy_insert on energy_readings for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('ENERGY_WRITE', org_unit_id));
create policy energy_update on energy_readings for update to authenticated
  using (tenant_id = current_tenant_id() and approved_at is null
         and (user_has_permission('ENERGY_WRITE', org_unit_id) or user_has_permission('ENERGY_APPROVE', org_unit_id)))
  with check (tenant_id = current_tenant_id()
              and (approved_at is null or user_has_permission('ENERGY_APPROVE', org_unit_id)));
