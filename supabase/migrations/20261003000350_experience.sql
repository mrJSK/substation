-- ============================================================================
-- 0350 EXPERIENCE — micro-apps (T-codes) and dynamic UI  (owner: Platform UX team)
--
-- Micro-apps: every screen family is an app with a short code, like an SAP
-- transaction (SU01, PFCG …). The launchpad, T-code command box and menus are
-- built from this catalog, filtered by the user's permissions. Tenants can
-- hide or rename apps without a release.
--
-- Dynamic UI: forms are JSON definitions rendered by the app's form engine.
-- Standard forms ship with tenant_id NULL; a tenant overrides by saving its
-- own version with the same code. Limits such as WTI alarm/trip live here,
-- so each utility can set its own without code changes.
-- ============================================================================

set search_path = public, extensions;  -- ltree lives in the extensions schema

create table app_catalog (
  code                 text primary key,           -- T-code, e.g. 'SU01'
  name                 text not null,
  module               text not null,              -- launchpad group
  description          text,
  icon                 text not null default 'apps',  -- Material icon name, mapped in the client
  required_permission  text references permissions(code),  -- null = any signed-in user with a role
  sort_order           smallint not null default 0,
  is_active            boolean not null default true
);

create table tenant_app_settings (
  tenant_id     uuid not null references tenants(id) on delete cascade,
  app_code      text not null references app_catalog(code) on delete cascade,
  is_enabled    boolean not null default true,
  display_name  text,
  sort_order    smallint,
  primary key (tenant_id, app_code)
);

create table ui_forms (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid references tenants(id) on delete cascade,   -- null = standard form
  code         text not null,
  version      integer not null default 1,
  title        text not null,
  description  text,
  schema       jsonb not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique nulls not distinct (tenant_id, code, version)
);

create trigger trg_ui_forms_updated_at before update on ui_forms
  for each row execute function set_updated_at();

-- Apps the caller may launch (held permission at any scope), tenant settings applied.
create function get_my_apps() returns jsonb
language sql stable security definer set search_path = public, extensions as $$
  with my_perms as (
    select distinct rp.permission_code
    from my_active_scopes() m
    join role_permissions rp on rp.role_id = m.role_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', a.code,
           'name', coalesce(s.display_name, a.name),
           'module', a.module,
           'description', a.description,
           'icon', a.icon,
           'required_permission', a.required_permission
         ) order by a.module, coalesce(s.sort_order, a.sort_order), a.code), '[]'::jsonb)
  from app_catalog a
  left join tenant_app_settings s on s.app_code = a.code and s.tenant_id = current_tenant_id()
  where a.is_active
    and coalesce(s.is_enabled, true)
    and exists (select 1 from my_active_scopes())
    and (a.required_permission is null
         or a.required_permission in (select permission_code from my_perms));
$$;

-- Latest active version of a form: tenant override first, else the standard one.
create function get_form(p_code text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', f.id, 'code', f.code, 'version', f.version,
                            'title', f.title, 'description', f.description,
                            'schema', f.schema, 'is_tenant_override', f.tenant_id is not null)
  from ui_forms f
  where f.code = p_code and f.is_active
    and (f.tenant_id is null or f.tenant_id = current_tenant_id())
  order by (f.tenant_id is not null) desc, f.version desc
  limit 1;
$$;

alter table app_catalog         enable row level security;
alter table tenant_app_settings enable row level security;
alter table ui_forms            enable row level security;

create policy app_catalog_read on app_catalog for select to authenticated using (true);

create policy tenant_apps_read on tenant_app_settings for select to authenticated
  using (tenant_id = current_tenant_id());
create policy tenant_apps_insert on tenant_app_settings for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('UI_ADMIN'));
create policy tenant_apps_update on tenant_app_settings for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('UI_ADMIN'))
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('UI_ADMIN'));
create policy tenant_apps_delete on tenant_app_settings for delete to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('UI_ADMIN'));

create policy ui_forms_read on ui_forms for select to authenticated
  using (tenant_id is null or tenant_id = current_tenant_id());
create policy ui_forms_insert on ui_forms for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('UI_ADMIN'));
create policy ui_forms_update on ui_forms for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('UI_ADMIN'))
  with check (tenant_id = current_tenant_id() and user_has_tenant_permission('UI_ADMIN'));
create policy ui_forms_delete on ui_forms for delete to authenticated
  using (tenant_id = current_tenant_id() and user_has_tenant_permission('UI_ADMIN'));

-- ── Standard micro-app catalog ─────────────────────────────────────────────
insert into app_catalog (code, name, module, description, icon, required_permission, sort_order) values
  ('OP01', 'Shift Logsheet',       'Operations',  'Hourly readings and shift handover (Reg 19)', 'menu_book',      'LOGSHEET_READ',    10),
  ('OP02', 'Tripping Register',    'Operations',  'Record and analyse trippings (Reg 10)',       'flash_on',       'TRIPPING_WRITE',   11),
  ('OP03', 'Stoppage Register',    'Operations',  'Interruptions and shutdowns (Reg 11)',        'pause_circle',   'STOPPAGE_WRITE',   12),
  ('OP04', 'SLDC Messages',        'Operations',  'Messages exchanged with SLDC (Reg 16)',       'forum',          'MESSAGE_WRITE',    13),
  ('PT01', 'Permit to Work',       'Safety',      'Shutdown requests and permits (Reg 9)',       'assignment',     'PTW_REQUEST',      20),
  ('SF01', 'Accident Register',    'Safety',      'Accidents and dangerous occurrences',         'health_and_safety','ACCIDENT_REPORT', 21),
  ('MT01', 'Work Orders',          'Maintenance', 'Plan, assign and complete work',              'build',          'WO_CREATE',        30),
  ('MT02', 'Defect Register',      'Maintenance', 'Report and track defects (Reg 7)',            'report_problem', 'DEFECT_CREATE',    31),
  ('MT03', 'Maintenance Plans',    'Maintenance', 'Preventive schedules per equipment type',     'event_repeat',   'MAINT_PLAN_ADMIN', 32),
  ('AS01', 'Equipment Master',     'Assets',      'Equipment register and plant history',        'precision_manufacturing','ASSET_READ', 40),
  ('EN01', 'Meter Readings',       'Energy',      'Daily energy meter readings (Reg 8)',         'speed',          'ENERGY_WRITE',     50),
  ('EN02', 'Energy Balance',       'Energy',      'Import, export and losses',                   'balance',        'ENERGY_READ',      51),
  ('RP01', 'Dashboard',            'Reports',     'Availability, reliability and open work',     'dashboard',      'REPORT_VIEW',      60),
  ('OR01', 'Org Structure',        'Administration','Hierarchy levels, units and data sharing',  'account_tree',   'ORG_ADMIN',        90),
  ('SU01', 'User Maintenance',     'Administration','Create users and assign roles',             'manage_accounts','USER_ADMIN',       91),
  ('PFCG', 'Role Maintenance',     'Administration','Roles and their permissions',               'admin_panel_settings','ROLE_ADMIN',  92),
  ('UI01', 'Forms and Apps',       'Administration','Dynamic forms and micro-app settings',      'dynamic_form',   'UI_ADMIN',         93),
  ('SM20', 'Audit Trail',          'Administration','Who changed what, and when',                'history',        'AUDIT_VIEW',       94);

-- ── Standard dynamic forms ─────────────────────────────────────────────────
-- Field types: text, textarea, number, integer, select, toggle, date, datetime, section
-- Optional: unit, required, hint, options, min, max, decimals,
--           limits {alarm_low, alarm_high, trip_low, trip_high}, visible_if {field, equals}
insert into ui_forms (tenant_id, code, version, title, description, schema) values
(null, 'TRANSFORMER_HOURLY', 1, 'Transformer hourly reading', 'Logsheet reading for a power transformer', '{
  "sections": [
    {"title": "Load", "fields": [
      {"key": "current_r_a", "label": "Current R", "type": "number", "unit": "A", "required": true, "min": 0},
      {"key": "current_y_a", "label": "Current Y", "type": "number", "unit": "A", "required": true, "min": 0},
      {"key": "current_b_a", "label": "Current B", "type": "number", "unit": "A", "required": true, "min": 0},
      {"key": "voltage_kv",  "label": "Voltage",   "type": "number", "unit": "kV", "required": true},
      {"key": "mw",          "label": "Active power",   "type": "number", "unit": "MW"},
      {"key": "mvar",        "label": "Reactive power", "type": "number", "unit": "MVAr"},
      {"key": "tap_position","label": "OLTC tap", "type": "integer", "min": 1, "max": 33}
    ]},
    {"title": "Temperatures", "fields": [
      {"key": "wti_c", "label": "Winding temperature (WTI)", "type": "number", "unit": "°C", "required": true,
       "limits": {"alarm_high": 90, "trip_high": 105}},
      {"key": "oti_c", "label": "Oil temperature (OTI)", "type": "number", "unit": "°C", "required": true,
       "limits": {"alarm_high": 85, "trip_high": 95}}
    ]},
    {"title": "Status", "fields": [
      {"key": "breaker_status", "label": "Breaker", "type": "select", "options": ["CLOSED", "OPEN"], "required": true},
      {"key": "has_alarm", "label": "Any alarm active", "type": "toggle"},
      {"key": "alarm_details", "label": "Alarm details", "type": "textarea", "required": true,
       "visible_if": {"field": "has_alarm", "equals": true}},
      {"key": "remarks", "label": "Remarks", "type": "textarea"}
    ]}
  ]
}'),
(null, 'BATTERY_DAILY', 1, 'Battery bank daily check', 'DC system daily readings', '{
  "sections": [
    {"title": "Voltages", "fields": [
      {"key": "bus_voltage_v",   "label": "DC bus voltage", "type": "number", "unit": "V", "required": true,
       "limits": {"alarm_low": 104.5, "alarm_high": 115.5}},
      {"key": "float_voltage_v", "label": "Float voltage per cell", "type": "number", "unit": "V", "decimals": 2,
       "limits": {"alarm_low": 2.18, "alarm_high": 2.30}},
      {"key": "pilot_cell_sg",   "label": "Pilot cell specific gravity", "type": "number", "decimals": 3,
       "limits": {"alarm_low": 1.200, "alarm_high": 1.215}}
    ]},
    {"title": "Charger", "fields": [
      {"key": "charger_mode", "label": "Charger mode", "type": "select", "options": ["FLOAT", "BOOST", "OFF"], "required": true},
      {"key": "earth_fault",  "label": "DC earth fault indicated", "type": "toggle"},
      {"key": "remarks", "label": "Remarks", "type": "textarea"}
    ]}
  ]
}');
