-- ============================================================
-- SubERP — Supabase PostgreSQL Schema
-- Multi-tenant power utility O&M ERP
-- Run in Supabase SQL Editor (or via supabase db push)
-- ============================================================

-- Enable required extensions
create extension if not exists "pgcrypto";
create extension if not exists "ltree";

-- ============================================================
-- TENANTS (utility companies — top of every hierarchy)
-- ============================================================
create table tenants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,            -- e.g. "UPTCL", "MSEDCL"
  short_code  text not null unique,     -- e.g. "UPTCL"
  utility_type text not null check (utility_type in ('TRANSCO','DISCOM','GENCO','SLDC')),
  state       text not null,            -- e.g. "Uttar Pradesh"
  created_at  timestamptz default now(),
  is_active   boolean default true
);

-- ============================================================
-- ORG UNITS (self-referential hierarchy)
-- level: 1=Zone, 2=Circle, 3=Division, 4=Subdivision, 5=Substation, 6=Bay
-- ============================================================
create table org_units (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants(id),
  parent_id   uuid references org_units(id),
  name        text not null,
  code        text not null,            -- short code for SLDC reporting
  level       smallint not null check (level between 1 and 6),
  voltage_kv       numeric,             -- for substations (132, 220, 400 kV)
  total_consumers  integer default 0,   -- consumers served (used for SAIDI/SAIFI)
  latitude         numeric,
  longitude        numeric,
  created_at       timestamptz default now(),
  is_active        boolean default true,
  unique (tenant_id, code)
);

-- Materialized path for fast ancestor queries (e.g., "all substations under Circle X")
alter table org_units add column path ltree;
create index org_units_path_gist on org_units using gist(path);

-- ============================================================
-- USERS (profile layer on top of Supabase Auth)
-- ============================================================
create table user_profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  tenant_id       uuid not null references tenants(id),
  full_name       text not null,
  employee_id     text,
  designation     text,                 -- Shift Engineer, AE(M), JE(O), SSO, etc.
  phone           text,
  valid_from      date default current_date,
  valid_to        date,                 -- null = no expiry
  is_active       boolean default true,
  created_at      timestamptz default now()
);

-- CEA staff qualification certificates
create table user_certificates (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references user_profiles(id),
  cert_type       text not null,        -- 'CEA_COMPETENCY_EHV', 'ELECTRICIAN_LICENSE', etc.
  cert_number     text,
  issued_by       text,
  valid_from      date,
  valid_to        date,
  document_url    text,                 -- Supabase Storage URL
  created_at      timestamptz default now()
);

-- ============================================================
-- ROLES & PERMISSIONS (SAP-style authorization)
-- ============================================================
create table roles (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid references tenants(id),  -- null = system-wide role
  name        text not null,
  description text,
  is_system   boolean default false,
  unique (tenant_id, name)
);

-- Fine-grained permission predicates (SAP Authorization Objects)
create table permissions (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,     -- 'PTW_ISSUE', 'LOGSHEET_WRITE', 'ENERGY_APPROVE'
  module      text not null,            -- 'PTW', 'OPERATIONS', 'ENERGY', 'IAM', etc.
  description text
);

create table role_permissions (
  role_id       uuid not null references roles(id) on delete cascade,
  permission_id uuid not null references permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

-- User → Role assignment scoped to an org unit
create table user_role_assignments (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references user_profiles(id) on delete cascade,
  role_id     uuid not null references roles(id),
  org_unit_id uuid not null references org_units(id),  -- scope: user has this role at this node and below
  valid_from  date default current_date,
  valid_to    date,
  assigned_by uuid references user_profiles(id),
  created_at  timestamptz default now(),
  unique (user_id, role_id, org_unit_id)
);

-- ============================================================
-- EQUIPMENT (Asset Master — SAP PM Functional Location + Equipment)
-- ============================================================
create table equipment (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id),
  org_unit_id     uuid not null references org_units(id),   -- substation or bay
  parent_id       uuid references equipment(id),            -- sub-component
  asset_tag       text not null,
  name            text not null,
  equipment_type  text not null,        -- 'TRANSFORMER','CB','CT','PT','LA','BATTERY','ISOLATOR'
  manufacturer    text,
  model           text,
  serial_number   text,
  year_of_mfg     smallint,
  commissioned_at date,
  warranty_expiry date,
  -- Technical parameters (JSONB for flexibility per equipment type)
  technical_params jsonb default '{}',
  -- e.g. {"rating_mva":315,"voltage_hv_kv":220,"voltage_lv_kv":132,"oil_volume_litres":47000}
  is_active       boolean default true,
  created_at      timestamptz default now()
);

create index equipment_org_unit_idx on equipment(org_unit_id);
create index equipment_type_idx on equipment(equipment_type);

-- Plant History Register (Reg 2) — all events on each equipment
create table equipment_history (
  id              uuid primary key default gen_random_uuid(),
  equipment_id    uuid not null references equipment(id),
  event_type      text not null,    -- 'COMMISSIONING','OVERHAUL','REPLACEMENT','INCIDENT','READING'
  event_at        timestamptz not null,
  description     text not null,
  done_by         uuid references user_profiles(id),
  document_urls   text[],           -- Supabase Storage URLs (test reports, photos)
  created_at      timestamptz default now()
);

-- ============================================================
-- SHIFT LOGS — Daily Log Sheet (Reg 19)
-- ============================================================
create table shift_logs (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id),
  substation_id   uuid not null references org_units(id),
  shift_date      date not null,
  shift_type      text not null check (shift_type in ('MORNING','EVENING','NIGHT','GENERAL')),
  shift_in_charge uuid references user_profiles(id),
  started_at      timestamptz,
  ended_at        timestamptz,
  handover_notes  text,
  is_completed    boolean default false,
  created_at      timestamptz default now(),
  unique (substation_id, shift_date, shift_type)
);

-- Hourly readings within a shift
create table shift_readings (
  id              uuid primary key default gen_random_uuid(),
  shift_log_id    uuid not null references shift_logs(id) on delete cascade,
  equipment_id    uuid not null references equipment(id),   -- transformer/feeder/bay
  recorded_at     timestamptz not null,
  -- EHV parameters
  current_r_a     numeric,     -- Phase R current (A)
  current_y_a     numeric,
  current_b_a     numeric,
  voltage_kv      numeric,
  mw              numeric,
  mvar            numeric,
  mva             numeric,
  power_factor    numeric,
  frequency_hz    numeric,
  tap_position    smallint,    -- OLTC tap
  wti_c           numeric,     -- Winding temperature (°C)
  oti_c           numeric,     -- Oil temperature (°C)
  breaker_status  text,        -- 'OPEN','CLOSED'
  isolator_status text,
  earth_sw_status text,
  -- Alarms
  has_alarm       boolean default false,
  alarm_details   text,
  remarks         text,
  recorded_by     uuid references user_profiles(id)
);

create index shift_readings_shift_idx on shift_readings(shift_log_id);
create index shift_readings_equipment_idx on shift_readings(equipment_id, recorded_at);

-- ============================================================
-- PERMIT TO WORK (Reg 9a — Shutdown Form, Reg 9b — PTW)
-- ============================================================
create type ptw_status as enum (
  'DRAFT','PENDING_SLDC','SLDC_APPROVED','ISOLATION_DONE',
  'ISSUED','WORK_IN_PROGRESS','RETURNED','CLOSED','CANCELLED'
);

create table ptw_requests (
  id                uuid primary key default gen_random_uuid(),
  ptw_number        text not null unique,               -- machine-sequential
  tenant_id         uuid not null references tenants(id),
  substation_id     uuid not null references org_units(id),
  equipment_id      uuid not null references equipment(id),
  status            ptw_status default 'DRAFT',
  work_description  text not null,
  -- SLDC coordination (Reg 9a)
  sldc_reference    text,
  sldc_approved_at  timestamptz,
  planned_start     timestamptz not null,
  planned_end       timestamptz not null,
  -- Isolation details
  isolation_points  jsonb default '[]',                 -- [{cb_id, isolator_id, action}]
  earthing_points   jsonb default '[]',                 -- [{location, rod_count, applied_at}]
  safety_precautions text,
  -- Workflow timestamps
  issued_at         timestamptz,
  issued_by         uuid references user_profiles(id),  -- Shift Engineer
  workman_user_id   uuid references user_profiles(id),  -- person in charge of work
  returned_at       timestamptz,
  restored_at       timestamptz,
  cancelled_at      timestamptz,
  cancel_reason     text,
  -- SoD enforcement: issuer ≠ workman (enforced in app + DB trigger)
  created_at        timestamptz default now(),
  created_by        uuid references user_profiles(id)
);

create index ptw_substation_status_idx on ptw_requests(substation_id, status);

-- ============================================================
-- DEFECT REGISTER (Reg 7)
-- ============================================================
create type defect_status as enum ('OPEN','WO_RAISED','IN_PROGRESS','CLOSED');
create type defect_priority as enum ('CRITICAL','HIGH','NORMAL','LOW');

create table defects (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id),
  substation_id   uuid not null references org_units(id),
  equipment_id    uuid references equipment(id),
  defect_number   text not null unique,
  status          defect_status default 'OPEN',
  priority        defect_priority default 'NORMAL',
  description     text not null,
  reported_at     timestamptz default now(),
  reported_by     uuid references user_profiles(id),
  compliance_date date,
  closed_at       timestamptz,
  closed_by       uuid references user_profiles(id),
  photo_urls      text[],
  work_order_id   uuid                                  -- FK to work_orders (circular, added after)
);

-- ============================================================
-- WORK ORDERS (derived from Reg 6 Testing + Reg 7 Defects + Maintenance Plans)
-- ============================================================
create type wo_type as enum ('PREVENTIVE','CORRECTIVE','CONDITION_BASED','BREAKDOWN','INSPECTION');
create type wo_status as enum ('PLANNED','ASSIGNED','IN_PROGRESS','PENDING_PTW','COMPLETED','CANCELLED');

create table work_orders (
  id              uuid primary key default gen_random_uuid(),
  wo_number       text not null unique,
  tenant_id       uuid not null references tenants(id),
  substation_id   uuid not null references org_units(id),
  equipment_id    uuid references equipment(id),
  defect_id       uuid references defects(id),
  type            wo_type not null,
  status          wo_status default 'PLANNED',
  title           text not null,
  description     text,
  scheduled_date  date,
  assigned_to     uuid references user_profiles(id),
  started_at      timestamptz,
  completed_at    timestamptz,
  -- Test results stored as JSONB (schema varies by equipment type)
  test_results    jsonb default '{}',
  findings        text,
  next_due_date   date,
  created_at      timestamptz default now(),
  created_by      uuid references user_profiles(id)
);

-- Add FK from defects to work_orders
alter table defects add constraint defects_wo_fk
  foreign key (work_order_id) references work_orders(id);

-- ============================================================
-- ENERGY ACCOUNT REGISTER (Reg 8)
-- ============================================================
create table energy_readings (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id),
  substation_id   uuid not null references org_units(id),
  equipment_id    uuid not null references equipment(id),   -- feeder/transformer
  reading_date    date not null,                            -- 8:00 AM reading date
  reading_type    text not null check (reading_type in ('IMPORT','EXPORT')),
  meter_reading   numeric not null,                         -- cumulative kWh/MWh
  multiplying_factor numeric not null default 1,
  net_energy_kwh  numeric,                                  -- (current - previous) × MF
  recorded_by     uuid references user_profiles(id),
  created_at      timestamptz default now(),
  unique (equipment_id, reading_date, reading_type)
);

-- Monthly energy balance computed view
create view monthly_energy_balance as
select
  substation_id,
  date_trunc('month', reading_date) as month,
  sum(case when reading_type = 'IMPORT' then net_energy_kwh else 0 end) as total_import_kwh,
  sum(case when reading_type = 'EXPORT' then net_energy_kwh else 0 end) as total_export_kwh,
  sum(case when reading_type = 'IMPORT' then net_energy_kwh else 0 end)
    - sum(case when reading_type = 'EXPORT' then net_energy_kwh else 0 end) as loss_kwh,
  round(
    100.0 * (
      sum(case when reading_type = 'IMPORT' then net_energy_kwh else 0 end)
      - sum(case when reading_type = 'EXPORT' then net_energy_kwh else 0 end)
    ) / nullif(sum(case when reading_type = 'IMPORT' then net_energy_kwh else 0 end), 0),
    2
  ) as loss_percent
from energy_readings
group by substation_id, month;

-- ============================================================
-- TRIPPING REGISTER (Reg 10)
-- ============================================================
create table tripping_events (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  substation_id     uuid not null references org_units(id),
  equipment_id      uuid not null references equipment(id),
  tripped_at        timestamptz not null,
  restored_at       timestamptz,
  fault_type        text,              -- 'EARTH_FAULT','OC','DIFF','DISTANCE','BUS_PROT'
  relay_flags_local jsonb,             -- {panel: 'REL_PANEL_3', flags: ['EF_R', 'OC_Y']}
  relay_flags_remote jsonb,
  fault_distance_km numeric,
  root_cause        text,
  analysis_remarks  text,
  recorded_by       uuid references user_profiles(id),
  created_at        timestamptz default now()
);

-- Stoppage Register (Reg 11) — all interruptions including shutdown/rostering
create table stoppages (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id),
  substation_id   uuid not null references org_units(id),
  equipment_id    uuid not null references equipment(id),
  stoppage_type   text not null check (stoppage_type in ('TRIPPING','BREAKDOWN','SHUTDOWN','ROSTERING')),
  started_at      timestamptz not null,
  ended_at        timestamptz,
  duration_min    numeric generated always as (
    extract(epoch from (ended_at - started_at)) / 60
  ) stored,
  cause           text,
  consumers_affected integer,
  ptw_id          uuid references ptw_requests(id),
  tripping_id     uuid references tripping_events(id),
  created_at      timestamptz default now()
);

-- ============================================================
-- MAINTENANCE PLANS (auto-generates WOs)
-- ============================================================
create table maintenance_plans (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id),
  equipment_type  text not null,        -- applies to all equipment of this type
  title           text not null,
  frequency_type  text not null check (frequency_type in ('DAILY','MONTHLY','QUARTERLY','HALF_YEARLY','YEARLY','2_YEARLY','3_YEARLY','5_YEARLY','COUNTER_BASED')),
  counter_limit   integer,              -- for COUNTER_BASED (e.g., 2000 operations)
  task_checklist  jsonb default '[]',   -- [{step, description, pass_criteria}]
  is_active       boolean default true,
  created_at      timestamptz default now()
);

-- Next due dates per equipment per plan
create table maintenance_schedules (
  id              uuid primary key default gen_random_uuid(),
  plan_id         uuid not null references maintenance_plans(id),
  equipment_id    uuid not null references equipment(id),
  last_done_at    date,
  next_due_at     date not null,
  last_wo_id      uuid references work_orders(id),
  unique (plan_id, equipment_id)
);

-- ============================================================
-- ACCIDENT / DANGEROUS OCCURRENCE REGISTER (CEA Safety Reg 46)
-- ============================================================
create table accident_reports (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id),
  substation_id   uuid not null references org_units(id),
  report_number   text not null unique,
  occurred_at     timestamptz not null,
  accident_type   text not null check (accident_type in ('FATAL','INJURY','DANGEROUS_OCCURRENCE','NEAR_MISS')),
  description     text not null,
  equipment_id    uuid references equipment(id),
  persons_involved text,
  immediate_cause text,
  root_cause      text,
  corrective_action text,
  -- Statutory reporting
  ceig_notified_at  timestamptz,        -- Must be within 24 hrs (CEA Reg 46)
  ceig_reference    text,
  report_submitted_at timestamptz,      -- Written report within 48 hrs
  created_at      timestamptz default now(),
  created_by      uuid references user_profiles(id)
);

-- ============================================================
-- AUDIT LOG (immutable — RLS prevents update/delete)
-- ============================================================
create table audit_logs (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants(id),
  user_id     uuid references user_profiles(id),
  action      text not null,            -- 'PTW_ISSUED','LOGSHEET_ENTRY','WO_COMPLETED'
  entity_type text not null,            -- table name
  entity_id   uuid,
  old_data    jsonb,
  new_data    jsonb,
  ip_address  inet,
  created_at  timestamptz default now()
);

-- No update or delete on audit logs
create policy audit_log_insert_only on audit_logs
  for insert with check (true);
create policy audit_log_no_update on audit_logs
  for update using (false);
create policy audit_log_no_delete on audit_logs
  for delete using (false);

alter table audit_logs enable row level security;

-- ============================================================
-- ROW LEVEL SECURITY (multi-tenant isolation)
-- ============================================================

-- Enable RLS on all tenant-scoped tables
alter table tenants enable row level security;
alter table org_units enable row level security;
alter table user_profiles enable row level security;
alter table equipment enable row level security;
alter table shift_logs enable row level security;
alter table shift_readings enable row level security;
alter table ptw_requests enable row level security;
alter table defects enable row level security;
alter table work_orders enable row level security;
alter table energy_readings enable row level security;
alter table stoppages enable row level security;
alter table tripping_events enable row level security;
alter table accident_reports enable row level security;

-- Helper function: get current user's tenant_id
create or replace function current_tenant_id()
returns uuid language sql stable
as $$
  select tenant_id from user_profiles where id = auth.uid()
$$;

-- Generic tenant isolation policy (apply to all tables with tenant_id)
-- Each table gets: "users can only see rows belonging to their tenant"
create policy tenant_isolation on org_units
  using (tenant_id = current_tenant_id());

create policy tenant_isolation on equipment
  using (tenant_id = current_tenant_id());

create policy tenant_isolation on shift_logs
  using (tenant_id = current_tenant_id());

create policy tenant_isolation on ptw_requests
  using (tenant_id = current_tenant_id());

create policy tenant_isolation on defects
  using (tenant_id = current_tenant_id());

create policy tenant_isolation on work_orders
  using (tenant_id = current_tenant_id());

create policy tenant_isolation on energy_readings
  using (tenant_id = current_tenant_id());

create policy tenant_isolation on accident_reports
  using (tenant_id = current_tenant_id());

-- Users can only see their own profile and profiles in their tenant
create policy user_profile_isolation on user_profiles
  using (tenant_id = current_tenant_id());

-- ============================================================
-- SEED: Core permissions
-- ============================================================
insert into permissions (code, module, description) values
  -- Operations
  ('LOGSHEET_READ',     'OPERATIONS', 'View shift logsheets'),
  ('LOGSHEET_WRITE',    'OPERATIONS', 'Create/update shift logsheet entries'),
  ('TRIPPING_WRITE',    'OPERATIONS', 'Enter tripping events'),
  ('STOPPAGE_WRITE',    'OPERATIONS', 'Enter stoppage records'),
  ('MESSAGE_WRITE',     'OPERATIONS', 'Send/receive SLDC messages'),
  -- PTW
  ('PTW_REQUEST',       'PTW',        'Create PTW/shutdown requests'),
  ('PTW_ISSUE',         'PTW',        'Issue a Work Permit (Shift Engineer)'),
  ('PTW_APPROVE_SLDC',  'PTW',        'Record SLDC approval for shutdown'),
  ('PTW_CANCEL',        'PTW',        'Cancel an issued PTW'),
  -- Work Orders
  ('WO_CREATE',         'MAINTENANCE','Create work orders'),
  ('WO_ASSIGN',         'MAINTENANCE','Assign work orders to staff'),
  ('WO_COMPLETE',       'MAINTENANCE','Mark work orders complete with test results'),
  -- Defects
  ('DEFECT_CREATE',     'MAINTENANCE','Report a defect (Reg 7)'),
  ('DEFECT_CLOSE',      'MAINTENANCE','Close a defect'),
  -- Energy
  ('ENERGY_READ',       'ENERGY',     'View energy account data'),
  ('ENERGY_WRITE',      'ENERGY',     'Enter energy meter readings (Reg 8)'),
  ('ENERGY_APPROVE',    'ENERGY',     'Approve monthly energy balance'),
  -- Assets
  ('ASSET_READ',        'ASSETS',     'View equipment master data'),
  ('ASSET_WRITE',       'ASSETS',     'Create/update equipment master'),
  -- Safety
  ('ACCIDENT_REPORT',   'SAFETY',     'File accident/dangerous occurrence report'),
  -- IAM
  ('USER_ADMIN',        'IAM',        'Create, edit, deactivate users'),
  ('ROLE_ADMIN',        'IAM',        'Manage roles and permissions'),
  -- Reports
  ('REPORT_VIEW',       'REPORTS',    'View all reports and dashboards');
