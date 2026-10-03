-- ============================================================================
-- 0500 OPERATIONS  (owner: Operations team)
-- Daily Log Sheet (Reg 19), Tripping Register (Reg 10), Stoppage Register (Reg 11).
-- Statutory registers: no delete policies.
-- Row ids are generated on the device so offline queues can upsert idempotently.
-- ============================================================================

create table shift_logs (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id      uuid not null references org_units(id) on delete restrict,
  shift_date       date not null,
  shift_code       text not null,                 -- tenant-defined: A/B/C, MORNING/EVENING/NIGHT …
  shift_in_charge  uuid references user_profiles(id),
  started_at       timestamptz,
  ended_at         timestamptz,
  handover_notes   text,
  is_completed     boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (org_unit_id, shift_date, shift_code)
);

create trigger trg_shift_logs_updated_at before update on shift_logs
  for each row execute function set_updated_at();
create trigger trg_shift_logs_audit after insert or update or delete on shift_logs
  for each row execute function audit_row_change();

-- Readings: common EHV fields are typed columns; anything a tenant's dynamic
-- form adds goes into `extra`. form_code/version record which form produced it.
create table shift_readings (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  shift_log_id     uuid not null references shift_logs(id) on delete cascade,
  equipment_id     uuid not null references equipment(id) on delete restrict,
  recorded_at      timestamptz not null,
  form_code        text,
  form_version     integer,
  current_r_a      numeric,
  current_y_a      numeric,
  current_b_a      numeric,
  voltage_kv       numeric,
  mw               numeric,
  mvar             numeric,
  power_factor     numeric,
  frequency_hz     numeric,
  tap_position     smallint,
  wti_c            numeric,
  oti_c            numeric,
  breaker_status   text,
  has_alarm        boolean not null default false,
  alarm_details    text,
  remarks          text,
  extra            jsonb not null default '{}',
  recorded_by      uuid default auth.uid() references user_profiles(id),
  created_at       timestamptz not null default now()
);

create index shift_readings_shift_idx on shift_readings (shift_log_id);
create index shift_readings_eq_time_idx on shift_readings (equipment_id, recorded_at desc);

create table tripping_events (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id         uuid not null references org_units(id) on delete restrict,
  equipment_id        uuid not null references equipment(id) on delete restrict,
  tripped_at          timestamptz not null,
  restored_at         timestamptz,
  fault_type          text,
  relay_flags_local   jsonb,
  relay_flags_remote  jsonb,
  fault_distance_km   numeric,
  root_cause          text,
  analysis_remarks    text,
  recorded_by         uuid default auth.uid() references user_profiles(id),
  created_at          timestamptz not null default now(),
  check (restored_at is null or restored_at >= tripped_at)
);

create index tripping_org_time_idx on tripping_events (org_unit_id, tripped_at desc);
create trigger trg_tripping_audit after insert or update or delete on tripping_events
  for each row execute function audit_row_change();

create table stoppages (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id         uuid not null references org_units(id) on delete restrict,
  equipment_id        uuid not null references equipment(id) on delete restrict,
  stoppage_type       text not null check (stoppage_type in ('TRIPPING','BREAKDOWN','SHUTDOWN','ROSTERING')),
  started_at          timestamptz not null,
  ended_at            timestamptz,
  duration_min        numeric generated always as (extract(epoch from (ended_at - started_at)) / 60) stored,
  cause               text,
  consumers_affected  integer,
  ptw_id              uuid,     -- FK added in 0600_ptw
  tripping_id         uuid references tripping_events(id),
  recorded_by         uuid default auth.uid() references user_profiles(id),
  created_at          timestamptz not null default now(),
  check (ended_at is null or ended_at >= started_at)
);

create index stoppages_org_time_idx on stoppages (org_unit_id, started_at desc);
create trigger trg_stoppages_audit after insert or update or delete on stoppages
  for each row execute function audit_row_change();

-- Upsert today's shift (caller's RLS applies: needs LOGSHEET_WRITE at the unit).
create function get_or_create_shift(p_org_unit_id uuid, p_shift_date date, p_shift_code text)
returns shift_logs
language plpgsql security invoker set search_path = public as $$
declare
  v_shift shift_logs;
begin
  insert into shift_logs (org_unit_id, shift_date, shift_code, shift_in_charge, started_at)
  values (p_org_unit_id, p_shift_date, p_shift_code, auth.uid(), now())
  on conflict (org_unit_id, shift_date, shift_code) do nothing;

  select * into v_shift from shift_logs
  where org_unit_id = p_org_unit_id and shift_date = p_shift_date and shift_code = p_shift_code;
  return v_shift;
end;
$$;

alter table shift_logs      enable row level security;
alter table shift_readings  enable row level security;
alter table tripping_events enable row level security;
alter table stoppages       enable row level security;

create policy shift_logs_read on shift_logs for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy shift_logs_insert on shift_logs for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('LOGSHEET_WRITE', org_unit_id));
create policy shift_logs_update on shift_logs for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('LOGSHEET_WRITE', org_unit_id) and not is_completed)
  with check (tenant_id = current_tenant_id() and user_has_permission('LOGSHEET_WRITE', org_unit_id));

create policy shift_readings_read on shift_readings for select to authenticated
  using (exists (select 1 from shift_logs s where s.id = shift_log_id
                 and s.tenant_id = current_tenant_id() and can_read_org_unit(s.org_unit_id)));
create policy shift_readings_insert on shift_readings for insert to authenticated
  with check (exists (select 1 from shift_logs s where s.id = shift_log_id
                      and s.tenant_id = current_tenant_id() and not s.is_completed
                      and user_has_permission('LOGSHEET_WRITE', s.org_unit_id)));
create policy shift_readings_update on shift_readings for update to authenticated
  using (exists (select 1 from shift_logs s where s.id = shift_log_id
                 and s.tenant_id = current_tenant_id() and not s.is_completed
                 and user_has_permission('LOGSHEET_WRITE', s.org_unit_id)))
  with check (exists (select 1 from shift_logs s where s.id = shift_log_id
                      and user_has_permission('LOGSHEET_WRITE', s.org_unit_id)));

create policy tripping_read on tripping_events for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy tripping_insert on tripping_events for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('TRIPPING_WRITE', org_unit_id));
create policy tripping_update on tripping_events for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('TRIPPING_WRITE', org_unit_id))
  with check (tenant_id = current_tenant_id() and user_has_permission('TRIPPING_WRITE', org_unit_id));

create policy stoppages_read on stoppages for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy stoppages_insert on stoppages for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('STOPPAGE_WRITE', org_unit_id));
create policy stoppages_update on stoppages for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('STOPPAGE_WRITE', org_unit_id))
  with check (tenant_id = current_tenant_id() and user_has_permission('STOPPAGE_WRITE', org_unit_id));
