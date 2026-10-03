-- ============================================================
-- Migration 005 — Seed data
-- Default roles, role→permission assignments, maintenance plan templates
-- These are GLOBAL (no tenant_id) system defaults.
-- Each new tenant gets a copy of system roles on signup (via Edge Function).

-- Allow null tenant_id on roles for system-wide roles
alter table roles alter column tenant_id drop not null;
-- ============================================================

-- ── System role definitions ───────────────────────────────────────────────
-- Note: tenant_id is NULL for system roles.
-- On tenant creation, clone these with the tenant's id (see Edge Function).

-- We use a temporary table to hold system role IDs for FK references below.
create temp table _system_roles (name text, id uuid);

with inserted as (
  insert into roles (id, tenant_id, name, description, is_system) values
    (gen_random_uuid(), null, 'SHIFT_ENGINEER',   'Shift In-Charge — EHV substation operations, PTW issuer', true),
    (gen_random_uuid(), null, 'JE_OPERATIONS',    'Junior Engineer (Operations) — logsheet, tripping entries', true),
    (gen_random_uuid(), null, 'SSO',               'Sub-Station Operator — shift readings, defect reporting', true),
    (gen_random_uuid(), null, 'JE_MAINTENANCE',    'Junior Engineer (Maintenance) — work orders, testing', true),
    (gen_random_uuid(), null, 'AE_MAINTENANCE',    'Assistant Engineer (Maintenance) — WO assign, energy approve', true),
    (gen_random_uuid(), null, 'AE_OPERATIONS',     'Assistant Engineer (Operations) — reports, stoppage review', true),
    (gen_random_uuid(), null, 'EE',                'Executive Engineer — circle-level oversight, approvals', true),
    (gen_random_uuid(), null, 'TENANT_ADMIN',      'Tenant Administrator — full access including IAM', true)
  returning id, name
)
insert into _system_roles select name, id from inserted;

-- ── Role → Permission assignments ────────────────────────────────────────

-- Helper: map permission codes to their IDs
create temp table _perm_ids as
  select code, id from permissions;

-- SHIFT_ENGINEER permissions
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from _system_roles r, _perm_ids p
where r.name = 'SHIFT_ENGINEER'
  and p.code in (
    'LOGSHEET_READ','LOGSHEET_WRITE',
    'TRIPPING_WRITE','STOPPAGE_WRITE','MESSAGE_WRITE',
    'PTW_REQUEST','PTW_ISSUE','PTW_APPROVE_SLDC','PTW_CANCEL',
    'DEFECT_CREATE',
    'ASSET_READ',
    'ENERGY_READ',
    'REPORT_VIEW'
  );

-- JE_OPERATIONS permissions
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from _system_roles r, _perm_ids p
where r.name = 'JE_OPERATIONS'
  and p.code in (
    'LOGSHEET_READ','LOGSHEET_WRITE',
    'TRIPPING_WRITE','STOPPAGE_WRITE','MESSAGE_WRITE',
    'PTW_REQUEST',
    'DEFECT_CREATE',
    'ASSET_READ','ENERGY_READ','REPORT_VIEW'
  );

-- SSO permissions (most limited — field operator)
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from _system_roles r, _perm_ids p
where r.name = 'SSO'
  and p.code in (
    'LOGSHEET_READ','LOGSHEET_WRITE',
    'DEFECT_CREATE',
    'ASSET_READ'
  );

-- JE_MAINTENANCE permissions
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from _system_roles r, _perm_ids p
where r.name = 'JE_MAINTENANCE'
  and p.code in (
    'LOGSHEET_READ',
    'DEFECT_CREATE','DEFECT_CLOSE',
    'WO_CREATE','WO_COMPLETE',
    'ASSET_READ',
    'ENERGY_READ','REPORT_VIEW'
  );

-- AE_MAINTENANCE permissions
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from _system_roles r, _perm_ids p
where r.name = 'AE_MAINTENANCE'
  and p.code in (
    'LOGSHEET_READ',
    'DEFECT_CREATE','DEFECT_CLOSE',
    'WO_CREATE','WO_ASSIGN','WO_COMPLETE',
    'ASSET_READ','ASSET_WRITE',
    'ENERGY_READ','ENERGY_WRITE','ENERGY_APPROVE',
    'REPORT_VIEW'
  );

-- AE_OPERATIONS permissions
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from _system_roles r, _perm_ids p
where r.name = 'AE_OPERATIONS'
  and p.code in (
    'LOGSHEET_READ','LOGSHEET_WRITE',
    'TRIPPING_WRITE','STOPPAGE_WRITE','MESSAGE_WRITE',
    'PTW_REQUEST','PTW_APPROVE_SLDC',
    'DEFECT_CREATE','DEFECT_CLOSE',
    'ASSET_READ',
    'ENERGY_READ','ENERGY_WRITE',
    'ACCIDENT_REPORT',
    'REPORT_VIEW'
  );

-- EE: everything except IAM
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from _system_roles r, _perm_ids p
where r.name = 'EE'
  and p.code not in ('USER_ADMIN','ROLE_ADMIN');

-- TENANT_ADMIN: all permissions
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from _system_roles r, _perm_ids p
where r.name = 'TENANT_ADMIN';

drop table _system_roles;
drop table _perm_ids;

-- Allow null tenant_id on maintenance_plans for global templates
alter table maintenance_plans alter column tenant_id drop not null;

-- ── Maintenance Plan Templates ────────────────────────────────────────────
-- These are global templates (tenant_id=NULL).
-- On tenant creation, clone these for the tenant.

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
