-- ============================================================================
-- 1300 SEMANTIC LAYER  (owner: Data & AI team)
-- Plain-language descriptions of every business table and key column.
-- They are read by: AI assistants (natural-language → SQL / tool calls),
-- report builders, API documentation generators and new developers.
-- Rule for all teams: a new table or business column is not done until it
-- has a comment here.
-- AI access always runs as the signed-in user (their JWT), so RLS and org
-- scope apply to every AI-generated query exactly as they do to the app.
-- ============================================================================

comment on schema public is 'GridERP: operations and maintenance ERP for power utilities. Multi-tenant: every business row has tenant_id. Org-scoped: most rows have org_unit_id pointing into a tenant-defined hierarchy (org_units). Statutory registers follow Indian regulations (CEA, CERC, IEGC, state O&M manuals).';

-- Platform
comment on table tenants is 'A licensed utility company (e.g. a state transmission or distribution company). Top of all data.';
comment on table audit_logs is 'Immutable change history: who (actor_id) changed which row (entity_type, entity_id), when, with before/after JSON.';
comment on table document_sequences is 'Internal counters for document numbers such as PTW-2026-000001. Not for reporting.';

-- Org hierarchy
comment on table org_levels is 'Tenant-defined hierarchy levels, e.g. Zone, Circle, Division, Substation, Bay. rank 1 is the top level.';
comment on column org_levels.is_operational is 'True for levels where field operations happen (shifts, logsheets, permits), usually the substation level.';
comment on table org_units is 'Nodes of the organisation tree (a zone, a circle, a substation, a bay …). Use path for subtree queries: child.path <@ parent.path.';
comment on column org_units.path is 'Materialized ltree path from the root. "All units under X" = path <@ (path of X).';
comment on column org_units.total_consumers is 'Number of consumers served, used as the denominator for SAIDI/SAIFI.';
comment on column org_units.voltage_kv is 'Highest voltage class at this unit, e.g. 132, 220, 400.';
comment on table org_unit_shares is 'Grants users scoped at target_org_unit_id read access to data of source_org_unit_id and everything below it.';
comment on view org_tree is 'Org units joined with their level name and depth. Preferred source for listing or naming units.';

-- IAM
comment on table user_profiles is 'People who can sign in. designation is the job title; home_org_unit_id is their primary posting.';
comment on table user_certificates is 'Statutory competency certificates of staff with validity dates.';
comment on table permissions is 'Catalog of permission codes (what a user may do), grouped by module.';
comment on table roles is 'Named bundles of permissions. tenant_id null = standard template shipped with the product.';
comment on table role_permissions is 'Which permission codes each role contains.';
comment on table user_role_assignments is 'Who has which role where: user_id holds role_id at org_unit_id (and below it when include_descendants), between valid_from and valid_to.';

-- Experience
comment on table app_catalog is 'Micro-apps (transaction codes) such as SU01 users or OP01 logsheet, with the permission needed to open each.';
comment on table tenant_app_settings is 'Per-tenant switches and renames for micro-apps.';
comment on table ui_forms is 'JSON form definitions rendered by the app (dynamic UI). Tenant rows override the standard form with the same code.';

-- Assets
comment on table equipment is 'Equipment register: transformers, circuit breakers, CTs, PTs, lightning arrestors, batteries, relays, isolators. Located at org_unit_id.';
comment on column equipment.equipment_type is 'Category code such as TRANSFORMER, CB, CT, PT, LA, BATTERY, RELAY, ISOLATOR.';
comment on column equipment.technical_params is 'Type-specific nameplate data as JSON, e.g. {"rating_mva":100,"voltage_hv_kv":220}.';
comment on table equipment_history is 'Plant History Register: commissioning, overhauls, replacements, incidents and tests per equipment.';

-- Operations
comment on table shift_logs is 'One row per shift per operational unit (Daily Log Sheet). shift_in_charge is the responsible engineer.';
comment on table shift_readings is 'Periodic (usually hourly) readings of an equipment during a shift: currents, voltage, MW, MVAr, temperatures, breaker status, alarms.';
comment on column shift_readings.wti_c is 'Transformer winding temperature in °C. Typical alarm 90, trip 105 (tenant forms may differ).';
comment on column shift_readings.oti_c is 'Transformer oil temperature in °C. Typical alarm 85, trip 95.';
comment on column shift_readings.extra is 'Additional readings captured by tenant-specific dynamic forms.';
comment on table tripping_events is 'Tripping Register: each breaker trip with fault type, relay flags, restoration time and root cause.';
comment on table stoppages is 'Stoppage Register: every interruption (TRIPPING, BREAKDOWN, SHUTDOWN, ROSTERING) with duration and consumers affected. Source for availability and SAIDI/SAIFI.';
comment on column stoppages.duration_min is 'Interruption length in minutes; null while still ongoing.';

-- PTW
comment on table ptw_requests is 'Permits to Work and shutdown requests. Lifecycle: DRAFT, PENDING_SLDC, SLDC_APPROVED, ISOLATION_DONE, ISSUED, WORK_IN_PROGRESS, RETURNED, CLOSED or CANCELLED.';
comment on column ptw_requests.issued_by is 'Engineer who issued the permit. Must differ from workman_user_id.';
comment on column ptw_requests.workman_user_id is 'Person in charge of the work under the permit.';

-- Maintenance
comment on table defects is 'Defect Register: abnormalities found on equipment, with priority and compliance date.';
comment on table work_orders is 'Maintenance jobs: preventive (from schedules), corrective (from defects), breakdown or inspection.';
comment on column work_orders.schedule_id is 'Set when the work order was generated from a preventive maintenance schedule.';
comment on table maintenance_plans is 'Preventive maintenance templates per equipment type with frequency and checklist. tenant_id null = product template.';
comment on table maintenance_schedules is 'Next due date of each maintenance plan for each equipment.';

-- Energy
comment on table energy_readings is 'Energy Account Register: daily cumulative meter readings per meter point. net_energy_kwh = (reading − previous) × multiplying_factor.';

-- Safety
comment on table accident_reports is 'Accident and dangerous occurrence register. ceig_notified_at must be within 24 hours of occurred_at.';

-- Notifications
comment on table notifications is 'Alerts for users: statutory deadlines, permit overruns and similar, targeted at a user or an org unit.';

-- Functions most useful to an AI assistant or report builder
comment on function get_dashboard_kpis(uuid, integer, integer) is 'All headline KPIs for any org unit and its subtree. month 0 = whole year.';
comment on function compute_energy_balance(uuid, integer, integer) is 'Import, export, loss kWh and loss % for an org unit subtree. month 0 = whole year.';
comment on function compute_saidi_saifi(uuid, integer, integer) is 'SAIDI, SAIFI, CAIDI for an org unit subtree. month 0 = whole year.';
comment on function compute_availability(uuid, integer, integer) is 'Availability % of one org unit from forced outages. month 0 = whole year.';
comment on function get_overdue_maintenance(uuid, integer) is 'Maintenance overdue or due within N days anywhere under an org unit.';
comment on function get_my_access() is 'The signed-in user''s profile, tenant and role assignments with permissions.';
comment on function get_accessible_org_units(boolean) is 'Org units the signed-in user can see; pass true for operational units only.';
