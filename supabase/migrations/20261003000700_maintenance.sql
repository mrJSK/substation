-- ============================================================================
-- 0700 MAINTENANCE  (owner: Maintenance team)
-- Defect Register (Reg 7), Work Orders, preventive Maintenance Plans and
-- per-equipment Schedules. Templates (tenant_id NULL) ship with the product
-- and can be used directly or copied and adjusted by a tenant.
-- ============================================================================

set search_path = public, extensions;  -- ltree lives in the extensions schema

create type defect_status   as enum ('OPEN','WO_RAISED','IN_PROGRESS','CLOSED');
create type defect_priority as enum ('CRITICAL','HIGH','NORMAL','LOW');
create type wo_type   as enum ('PREVENTIVE','CORRECTIVE','CONDITION_BASED','BREAKDOWN','INSPECTION');
create type wo_status as enum ('PLANNED','ASSIGNED','IN_PROGRESS','PENDING_PTW','COMPLETED','CANCELLED');

create table maintenance_plans (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid references tenants(id) on delete cascade,   -- null = product template
  equipment_type  text not null,
  title           text not null,
  frequency_type  text not null check (frequency_type in
                    ('DAILY','WEEKLY','MONTHLY','QUARTERLY','HALF_YEARLY','YEARLY','2_YEARLY','3_YEARLY','5_YEARLY','COUNTER_BASED')),
  counter_limit   integer,
  task_checklist  jsonb not null default '[]',
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger trg_maintenance_plans_updated_at before update on maintenance_plans
  for each row execute function set_updated_at();

create table maintenance_schedules (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  plan_id       uuid not null references maintenance_plans(id) on delete cascade,
  equipment_id  uuid not null references equipment(id) on delete cascade,
  last_done_on  date,
  next_due_on   date not null,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (plan_id, equipment_id)
);

create index maintenance_schedules_due_idx on maintenance_schedules (next_due_on) where is_active;

create trigger trg_maintenance_schedules_updated_at before update on maintenance_schedules
  for each row execute function set_updated_at();

create table defects (
  id               uuid primary key default gen_random_uuid(),
  defect_number    text unique,
  tenant_id        uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id      uuid not null references org_units(id) on delete restrict,
  equipment_id     uuid references equipment(id) on delete restrict,
  status           defect_status not null default 'OPEN',
  priority         defect_priority not null default 'NORMAL',
  description      text not null,
  reported_at      timestamptz not null default now(),
  reported_by      uuid default auth.uid() references user_profiles(id),
  compliance_date  date,
  closed_at        timestamptz,
  closed_by        uuid references user_profiles(id),
  photo_paths      text[] not null default '{}',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index defects_org_status_idx on defects (org_unit_id, status);

create table work_orders (
  id              uuid primary key default gen_random_uuid(),
  wo_number       text unique,
  tenant_id       uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id     uuid not null references org_units(id) on delete restrict,
  equipment_id    uuid references equipment(id) on delete restrict,
  defect_id       uuid references defects(id),
  schedule_id     uuid references maintenance_schedules(id),   -- set when generated from a plan
  ptw_id          uuid references ptw_requests(id),
  type            wo_type not null,
  status          wo_status not null default 'PLANNED',
  title           text not null,
  description     text,
  scheduled_date  date,
  assigned_to     uuid references user_profiles(id),
  started_at      timestamptz,
  completed_at    timestamptz,
  checklist       jsonb not null default '[]',   -- copied from the plan, filled on completion
  test_results    jsonb not null default '{}',
  findings        text,
  created_by      uuid default auth.uid() references user_profiles(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index work_orders_org_status_idx on work_orders (org_unit_id, status);
create index work_orders_schedule_idx on work_orders (schedule_id) where schedule_id is not null;

create trigger trg_defects_updated_at before update on defects
  for each row execute function set_updated_at();
create trigger trg_work_orders_updated_at before update on work_orders
  for each row execute function set_updated_at();
create trigger trg_defects_audit after insert or update or delete on defects
  for each row execute function audit_row_change();
create trigger trg_work_orders_audit after insert or update or delete on work_orders
  for each row execute function audit_row_change();

create function defects_number() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.defect_number := next_document_number(new.tenant_id, 'DEFECT', 'DEF');
  return new;
end;
$$;
create trigger trg_defects_number before insert on defects
  for each row execute function defects_number();

create function work_orders_number() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.wo_number := next_document_number(new.tenant_id, 'WO', 'WO');
  return new;
end;
$$;
create trigger trg_work_orders_number before insert on work_orders
  for each row execute function work_orders_number();

-- Completing a plan-generated WO rolls its schedule forward.
create function work_orders_after_complete() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_interval interval;
begin
  if new.status = 'COMPLETED' and old.status <> 'COMPLETED' and new.schedule_id is not null then
    select case p.frequency_type
             when 'DAILY'       then interval '1 day'
             when 'WEEKLY'      then interval '7 days'
             when 'MONTHLY'     then interval '1 month'
             when 'QUARTERLY'   then interval '3 months'
             when 'HALF_YEARLY' then interval '6 months'
             when 'YEARLY'      then interval '1 year'
             when '2_YEARLY'    then interval '2 years'
             when '3_YEARLY'    then interval '3 years'
             when '5_YEARLY'    then interval '5 years'
             else interval '1 year'
           end
      into v_interval
      from maintenance_schedules s join maintenance_plans p on p.id = s.plan_id
     where s.id = new.schedule_id;

    update maintenance_schedules
       set last_done_on = coalesce(new.completed_at, now())::date,
           next_due_on  = (coalesce(new.completed_at, now())::date + v_interval)::date
     where id = new.schedule_id;
  end if;
  return null;
end;
$$;

create trigger trg_work_orders_after_complete after update of status on work_orders
  for each row execute function work_orders_after_complete();

-- Maintenance due under any unit (substation, division, zone …): subtree query.
create function get_overdue_maintenance(p_org_unit_id uuid, p_days_ahead integer default 7)
returns table (schedule_id uuid, equipment_id uuid, equipment_name text, org_unit_id uuid,
               plan_title text, last_done_on date, next_due_on date, days_overdue integer)
language sql stable security invoker set search_path = public, extensions as $$
  select s.id, e.id, e.name, e.org_unit_id, p.title, s.last_done_on, s.next_due_on,
         (current_date - s.next_due_on)::integer
  from maintenance_schedules s
  join equipment e         on e.id = s.equipment_id
  join maintenance_plans p on p.id = s.plan_id
  join org_units u         on u.id = e.org_unit_id
  where s.is_active
    and u.path <@ (select path from org_units where id = p_org_unit_id)
    and s.next_due_on <= current_date + p_days_ahead
  order by s.next_due_on;
$$;

revoke execute on function defects_number() from public, anon, authenticated;
revoke execute on function work_orders_number() from public, anon, authenticated;
revoke execute on function work_orders_after_complete() from public, anon, authenticated;

alter table maintenance_plans     enable row level security;
alter table maintenance_schedules enable row level security;
alter table defects               enable row level security;
alter table work_orders           enable row level security;

create policy maint_plans_read on maintenance_plans for select to authenticated
  using (tenant_id is null or tenant_id = current_tenant_id());
create policy maint_plans_insert on maintenance_plans for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('MAINT_PLAN_ADMIN'));
create policy maint_plans_update on maintenance_plans for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('MAINT_PLAN_ADMIN'))
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('MAINT_PLAN_ADMIN'));

create policy maint_schedules_read on maintenance_schedules for select to authenticated
  using (exists (select 1 from equipment e where e.id = equipment_id
                 and e.tenant_id = current_tenant_id() and can_read_org_unit(e.org_unit_id)));
create policy maint_schedules_insert on maintenance_schedules for insert to authenticated
  with check (exists (select 1 from equipment e where e.id = equipment_id
                      and e.tenant_id = current_tenant_id() and user_has_permission('MAINT_PLAN_ADMIN', e.org_unit_id)));
create policy maint_schedules_update on maintenance_schedules for update to authenticated
  using (exists (select 1 from equipment e where e.id = equipment_id
                 and e.tenant_id = current_tenant_id() and user_has_permission('MAINT_PLAN_ADMIN', e.org_unit_id)))
  with check (exists (select 1 from equipment e where e.id = equipment_id
                      and e.tenant_id = current_tenant_id() and user_has_permission('MAINT_PLAN_ADMIN', e.org_unit_id)));

create policy defects_read on defects for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy defects_insert on defects for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('DEFECT_CREATE', org_unit_id));
create policy defects_update on defects for update to authenticated
  using (tenant_id = current_tenant_id() and (user_has_permission('DEFECT_CREATE', org_unit_id)
                                           or user_has_permission('DEFECT_CLOSE', org_unit_id)))
  with check (tenant_id = current_tenant_id()
              and (status <> 'CLOSED' or user_has_permission('DEFECT_CLOSE', org_unit_id)));

create policy wo_read on work_orders for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy wo_insert on work_orders for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('WO_CREATE', org_unit_id));
create policy wo_update on work_orders for update to authenticated
  using (tenant_id = current_tenant_id() and (user_has_permission('WO_CREATE', org_unit_id)
                                           or user_has_permission('WO_ASSIGN', org_unit_id)
                                           or user_has_permission('WO_COMPLETE', org_unit_id)))
  with check (tenant_id = current_tenant_id()
              and (status <> 'COMPLETED' or user_has_permission('WO_COMPLETE', org_unit_id)));

-- ── Product templates: preventive maintenance plans ────────────────────────
-- TRANSFORMER
insert into maintenance_plans (id, tenant_id, equipment_type, title, frequency_type, task_checklist, is_active) values

(gen_random_uuid(), null, 'TRANSFORMER', 'Transformer Daily Check', 'DAILY', '[
  {"step":1,"description":"Check Winding Temperature (WTI) — alarm >90°C, trip >105°C","pass_criteria":"WTI < 90°C"},
  {"step":2,"description":"Check Oil Temperature (OTI) — alarm >85°C, trip >95°C","pass_criteria":"OTI < 85°C"},
  {"step":3,"description":"Check oil level in conservator — should match temperature mark on MOG","pass_criteria":"Level normal"},
  {"step":4,"description":"Silica gel colour in breather — must be blue","pass_criteria":"Blue colour"},
  {"step":5,"description":"Oil level in breather oil cup — at marked level","pass_criteria":"At mark"},
  {"step":6,"description":"Diaphragm of relief vent pipe — must be intact","pass_criteria":"Intact"},
  {"step":7,"description":"Fan/pump operation at rated temperature","pass_criteria":"Operational"},
  {"step":8,"description":"Abnormal sound or vibration","pass_criteria":"No abnormality"},
  {"step":9,"description":"OLTC position (tap) — record in logsheet","pass_criteria":"Recorded"},
  {"step":10,"description":"Check load % vs rated capacity","pass_criteria":"≤ 100% rated"}
]', true),

(gen_random_uuid(), null, 'TRANSFORMER', 'Transformer Quarterly Maintenance', 'QUARTERLY', '[
  {"step":1,"description":"External inspection: oil samples from drain valve","pass_criteria":"No water, sludge"},
  {"step":2,"description":"Bushing visual: cracks, flashover marks, contamination","pass_criteria":"Clean, no damage"},
  {"step":3,"description":"Gasket condition at all flanges","pass_criteria":"No seepage"},
  {"step":4,"description":"Radiator fins: not blocked, clean","pass_criteria":"Clean"},
  {"step":5,"description":"Terminal connection tightness","pass_criteria":"All tight"},
  {"step":6,"description":"Cooling fan: contamination, moisture, bearing noise, rotation","pass_criteria":"All OK"},
  {"step":7,"description":"Oil pump: rotation, vibration, connections","pass_criteria":"No abnormality"},
  {"step":8,"description":"Marshalling kiosk: door seal, lights, heater, annunciator","pass_criteria":"All functional"}
]', true),

(gen_random_uuid(), null, 'TRANSFORMER', 'Transformer Yearly Maintenance', 'YEARLY', '[
  {"step":1,"description":"Oil BDV test (IEC 60156) — 2.5mm gap, stirred sample","pass_criteria":"≥ 50 kV (132kV+); ≥ 40 kV (33/66kV)","unit":"kV"},
  {"step":2,"description":"Insulation Resistance (IR) — HV to LV+Earth, LV to HV+Earth","pass_criteria":"PI > 1.5 (10-min/1-min)","unit":"MΩ"},
  {"step":3,"description":"Turns Ratio Test (TTR) — all tap positions","pass_criteria":"Deviation < 0.5% from nameplate","unit":"%"},
  {"step":4,"description":"Winding Resistance — compare with commissioning values","pass_criteria":"No significant deviation"},
  {"step":5,"description":"Bushing Tan Delta / Capacitance (OIP type)","pass_criteria":"Tan δ < 0.7% (new), < 1.0% (service)","unit":"%"},
  {"step":6,"description":"Buchholz relay: trip and alarm contact function test","pass_criteria":"Both contacts operate correctly"},
  {"step":7,"description":"PRD / Relief vent pipe inspection","pass_criteria":"Intact, no leakage"},
  {"step":8,"description":"WTI/OTI calibration check","pass_criteria":"Within ±2°C of reference"}
]', true),

(gen_random_uuid(), null, 'TRANSFORMER', 'Transformer DGA Analysis', '5_YEARLY', '[
  {"step":1,"description":"Oil sample from bottom drain valve (IEC 60599)","pass_criteria":""},
  {"step":2,"description":"H2 (Hydrogen) ppm","pass_criteria":"Normal < 100 ppm","unit":"ppm"},
  {"step":3,"description":"CH4 (Methane) ppm","pass_criteria":"Normal < 30 ppm","unit":"ppm"},
  {"step":4,"description":"C2H2 (Acetylene) ppm — arcing indicator","pass_criteria":"< 5 ppm; > 5 ppm = investigate","unit":"ppm"},
  {"step":5,"description":"C2H4 (Ethylene) ppm","pass_criteria":"Normal < 30 ppm","unit":"ppm"},
  {"step":6,"description":"C2H6 (Ethane) ppm","pass_criteria":"Normal < 35 ppm","unit":"ppm"},
  {"step":7,"description":"CO (Carbon Monoxide) ppm","pass_criteria":"Normal < 700 ppm","unit":"ppm"},
  {"step":8,"description":"CO2 (Carbon Dioxide) ppm","pass_criteria":"CO2/CO ratio < 7 = cellulose degradation","unit":"ppm"},
  {"step":9,"description":"TDCG (Total Dissolved Combustible Gas)","pass_criteria":"< 720 normal; 720-1920 caution; > 1920 action","unit":"ppm"},
  {"step":10,"description":"Oil moisture content (IEC 60422)","pass_criteria":"< 15 ppm; > 20 ppm = mandatory reconditioning","unit":"ppm"}
]', true),

-- CIRCUIT BREAKER
(gen_random_uuid(), null, 'CB', 'Circuit Breaker Monthly Check', 'MONTHLY', '[
  {"step":1,"description":"Record operation counter reading","pass_criteria":"Recorded"},
  {"step":2,"description":"Control cubicle: clean, tighten all connections","pass_criteria":"No loose connections"}
]', true),

(gen_random_uuid(), null, 'CB', 'Circuit Breaker Quarterly Maintenance', 'QUARTERLY', '[
  {"step":1,"description":"IR between upper and lower terminals same pole (VCB, open position)","pass_criteria":"> 50 GΩ","unit":"GΩ"},
  {"step":2,"description":"Air leakage from storage tank and pipe joints (pneumatic CBs)","pass_criteria":"No leakage"},
  {"step":3,"description":"Alarm and indication circuit check","pass_criteria":"All circuits healthy"},
  {"step":4,"description":"Control and relay panel wiring: check, clean, tighten","pass_criteria":"No loose wiring"},
  {"step":5,"description":"CB operation check if not operated in last 3 months","pass_criteria":"Operates correctly"}
]', true),

(gen_random_uuid(), null, 'CB', 'Circuit Breaker Yearly Maintenance', 'YEARLY', '[
  {"step":1,"description":"Pole discrepancy relay check (220kV+)","pass_criteria":"Trip after 1.5 sec timer"},
  {"step":2,"description":"Operation times C, O, C-O (timing test)","pass_criteria":"Pole discrepancy ≤ 5 ms (in-service)","unit":"ms"},
  {"step":3,"description":"All operational lockouts: SF6 gas, pneumatic, hydraulic","pass_criteria":"All lockouts function"},
  {"step":4,"description":"Contact resistance measurement (100A DC micro-ohm meter)","pass_criteria":"Per manufacturer spec","unit":"μΩ"},
  {"step":5,"description":"Clamp, fixture, jumper, linkage tightening","pass_criteria":"All tight"}
]', true),

(gen_random_uuid(), null, 'CB', 'SF6 Gas Dew Point (CB)', '2_YEARLY', '[
  {"step":1,"description":"SF6 gas dew point measurement (IEC 60480)","pass_criteria":"≥ -5°C at rated pressure","unit":"°C"},
  {"step":2,"description":"Gas pressure: alarm and lockout settings within 0.1 bar of set value","pass_criteria":"Within spec","unit":"bar"}
]', true),

-- BATTERY
(gen_random_uuid(), null, 'BATTERY', 'Battery Daily Check', 'DAILY', '[
  {"step":1,"description":"Float charge voltage — per cell and overall","pass_criteria":"VRLA: 2.25 V/cell; Flooded: 2.23 V/cell","unit":"V"},
  {"step":2,"description":"Overall DC bus voltage (110V or 220V DC system)","pass_criteria":"Within ±5% of rated","unit":"V"},
  {"step":3,"description":"Charger: AC input, DC output voltage and current","pass_criteria":"Within spec"},
  {"step":4,"description":"Pilot cell specific gravity (flooded type)","pass_criteria":"1.200–1.215 @ 27°C","unit":"SG"}
]', true),

(gen_random_uuid(), null, 'BATTERY', 'Battery Monthly Check', 'MONTHLY', '[
  {"step":1,"description":"Individual cell voltage — all cells","pass_criteria":"No cell < 1.95 V under float","unit":"V"},
  {"step":2,"description":"Specific gravity all cells (flooded)","pass_criteria":"1.200–1.215 @ 27°C","unit":"SG"},
  {"step":3,"description":"Electrolyte level (flooded) — top up with distilled water if low","pass_criteria":"At marked level"},
  {"step":4,"description":"Inter-cell connectors: corrosion, tightness","pass_criteria":"Clean and tight"},
  {"step":5,"description":"Charger alarm contacts and boost charge settings","pass_criteria":"All functional"}
]', true),

(gen_random_uuid(), null, 'BATTERY', 'Battery Capacity Discharge Test', 'YEARLY', '[
  {"step":1,"description":"10-hour rate (C10) discharge test","pass_criteria":"≥ 80% of rated Ah capacity","unit":"Ah"},
  {"step":2,"description":"Full specific gravity and voltage measurement before test","pass_criteria":"Recorded"},
  {"step":3,"description":"Full specific gravity and voltage measurement after test","pass_criteria":"Recorded"},
  {"step":4,"description":"Battery room ventilation check (H2 build-up hazard)","pass_criteria":"Adequate ventilation"},
  {"step":5,"description":"Battery room temperature","pass_criteria":"15–30°C"}
]', true),

-- PROTECTIVE RELAY
(gen_random_uuid(), null, 'RELAY', 'Relay Monthly Check', 'MONTHLY', '[
  {"step":1,"description":"Trip circuit healthiness for ALL panels after assuming shift","pass_criteria":"All healthy"},
  {"step":2,"description":"Annunciation panel lamp test — all windows must light up","pass_criteria":"All windows light"}
]', true),

(gen_random_uuid(), null, 'RELAY', 'Relay Secondary Injection Test', 'YEARLY', '[
  {"step":1,"description":"Overcurrent relay: pickup value and time-multiplier","pass_criteria":"Within ±5% of setting"},
  {"step":2,"description":"Earth fault relay: setting verification","pass_criteria":"Within ±5% of setting"},
  {"step":3,"description":"Distance relay: Zone 1, 2, 3 reach verification","pass_criteria":"Within ±5% of setting"},
  {"step":4,"description":"Differential relay: operate and restrain zone","pass_criteria":"Correct operation"},
  {"step":5,"description":"Buchholz relay: alarm and trip contacts","pass_criteria":"Both operate"},
  {"step":6,"description":"OTI/WTI: alarm and trip settings","pass_criteria":"Operate at set values"},
  {"step":7,"description":"Auto-reclose relay: timing and functional test","pass_criteria":"Per scheme design"},
  {"step":8,"description":"Pole discrepancy relay (220kV+): trip timer","pass_criteria":"1.5 sec timer"}
]', true),

-- EARTHING
(gen_random_uuid(), null, 'EARTHING', 'Earth Resistance Annual Test', 'YEARLY', '[
  {"step":1,"description":"Main earth mat resistance (fall-of-potential method, IS 3043)","pass_criteria":"< 1 Ω","unit":"Ω"},
  {"step":2,"description":"All earth bonds of surge arrestors, structures, equipment tanks","pass_criteria":"All bonded"},
  {"step":3,"description":"Earth pit condition: dryness, salt treatment","pass_criteria":"Moist, treated"}
]', true),

-- LIGHTNING ARRESTOR
(gen_random_uuid(), null, 'LA', 'LA Yearly Maintenance', 'YEARLY', '[
  {"step":1,"description":"IR test: HV to earth","pass_criteria":"≥ 1000 MΩ (dry)","unit":"MΩ"},
  {"step":2,"description":"Leakage current measurement (online) — resistive component","pass_criteria":"< 1 mA resistive","unit":"mA"},
  {"step":3,"description":"Porcelain/polymer condition, flange, mounting","pass_criteria":"No damage"},
  {"step":4,"description":"Pressure relief vent condition","pass_criteria":"Intact"},
  {"step":5,"description":"Earthing connection","pass_criteria":"Tight, no corrosion"}
]', true);
