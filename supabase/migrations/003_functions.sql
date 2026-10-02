-- ============================================================
-- Migration 003 — PostgreSQL functions (called via supabase.rpc())
-- These compute KPIs server-side so the app never pulls raw rows.
-- ============================================================

-- ── Permission check ──────────────────────────────────────────────────────
-- Returns the set of permission codes a user has at a given org unit.
-- The app caches this result locally (8hr TTL).

create or replace function get_user_permissions(
  p_user_id     uuid,
  p_org_unit_id uuid   -- the substation/bay the user is operating at
) returns text[] language sql stable security definer as $$
  select array_agg(distinct pe.code)
  from user_role_assignments ura
  join role_permissions rp on rp.role_id = ura.role_id
  join permissions pe on pe.id = rp.permission_id
  join org_units target on target.id = p_org_unit_id
  join org_units scope  on scope.id  = ura.org_unit_id
  where ura.user_id = p_user_id
    and (ura.valid_from is null or ura.valid_from <= current_date)
    and (ura.valid_to   is null or ura.valid_to   >= current_date)
    -- The user's scope must be an ancestor-or-equal of the target
    and (target.path <@ scope.path or target.id = scope.id);
$$;

-- ── Availability % ────────────────────────────────────────────────────────
-- CERC formula: (scheduled_hours - forced_outage_hours) / scheduled_hours × 100

create or replace function compute_availability(
  p_substation_id uuid,
  p_year          smallint,
  p_month         smallint   -- 0 = full year
) returns numeric language sql stable security definer as $$
  with params as (
    select
      case when p_month = 0
        then make_date(p_year, 1, 1)::timestamptz
        else make_date(p_year, p_month, 1)::timestamptz
      end as period_start,
      case when p_month = 0
        then make_date(p_year + 1, 1, 1)::timestamptz
        else (make_date(p_year, p_month, 1) + interval '1 month')::timestamptz
      end as period_end
  ),
  hours as (
    select
      extract(epoch from (p.period_end - p.period_start)) / 3600 as scheduled_hours,
      coalesce(sum(
        extract(epoch from (
          least(s.ended_at, p.period_end)
          - greatest(s.started_at, p.period_start)
        )) / 3600
      ), 0) filter (where s.stoppage_type = 'TRIPPING' or s.stoppage_type = 'BREAKDOWN') as forced_outage_hours
    from params p
    left join stoppages s on s.substation_id = p_substation_id
      and s.started_at < p.period_end
      and (s.ended_at is null or s.ended_at > p.period_start)
  )
  select round(
    100.0 * (h.scheduled_hours - h.forced_outage_hours) / nullif(h.scheduled_hours, 0),
    2
  )
  from hours h;
$$;

-- ── SAIDI / SAIFI ─────────────────────────────────────────────────────────

create or replace function compute_saidi_saifi(
  p_substation_id uuid,
  p_year          smallint,
  p_month         smallint
) returns jsonb language sql stable security definer as $$
  with params as (
    select
      case when p_month = 0
        then make_date(p_year, 1, 1)::timestamptz
        else make_date(p_year, p_month, 1)::timestamptz
      end as period_start,
      case when p_month = 0
        then make_date(p_year + 1, 1, 1)::timestamptz
        else (make_date(p_year, p_month, 1) + interval '1 month')::timestamptz
      end as period_end
  ),
  totals as (
    select
      -- total consumers served by this substation (stored in org_units.technical_params)
      (select (technical_params->>'total_consumers')::int
       from org_units where id = p_substation_id) as total_consumers,
      coalesce(sum(s.consumers_affected * extract(epoch from (s.ended_at - s.started_at)) / 3600), 0) as sum_ri_ui,
      coalesce(sum(s.consumers_affected), 0) as sum_lambda_ni
    from params p, stoppages s
    where s.substation_id = p_substation_id
      and s.stoppage_type in ('TRIPPING', 'BREAKDOWN')
      and s.started_at >= p.period_start
      and s.started_at < p.period_end
      and s.consumers_affected is not null
  )
  select jsonb_build_object(
    'saidi', round((t.sum_ri_ui / nullif(t.total_consumers, 0))::numeric, 4),
    'saifi', round((t.sum_lambda_ni::numeric / nullif(t.total_consumers, 0))::numeric, 4),
    'caidi', round(
      (t.sum_ri_ui / nullif(t.sum_lambda_ni, 0))::numeric,
      4
    ),
    'total_consumers', t.total_consumers,
    'period_year', p_year,
    'period_month', p_month
  )
  from totals t;
$$;

-- ── Energy balance ────────────────────────────────────────────────────────

create or replace function compute_energy_balance(
  p_substation_id uuid,
  p_year          smallint,
  p_month         smallint
) returns jsonb language sql stable security definer as $$
  with readings as (
    select
      reading_type,
      sum(net_energy_kwh) as total_kwh
    from energy_readings
    where substation_id = p_substation_id
      and extract(year from reading_date)  = p_year
      and (p_month = 0 or extract(month from reading_date) = p_month)
    group by reading_type
  ),
  pivot as (
    select
      coalesce(max(total_kwh) filter (where reading_type = 'IMPORT'), 0) as import_kwh,
      coalesce(max(total_kwh) filter (where reading_type = 'EXPORT'), 0) as export_kwh
    from readings
  )
  select jsonb_build_object(
    'import_kwh',   round(p.import_kwh::numeric, 2),
    'export_kwh',   round(p.export_kwh::numeric, 2),
    'loss_kwh',     round((p.import_kwh - p.export_kwh)::numeric, 2),
    'loss_percent', round(
      (100.0 * (p.import_kwh - p.export_kwh) / nullif(p.import_kwh, 0))::numeric,
      2
    )
  )
  from pivot p;
$$;

-- ── Substation dashboard KPIs ─────────────────────────────────────────────
-- Single RPC call to get everything the dashboard needs.
-- Avoids multiple round-trips from the app.

create or replace function get_dashboard_kpis(
  p_substation_id uuid,
  p_year          smallint,
  p_month         smallint
) returns jsonb language sql stable security definer as $$
  select jsonb_build_object(
    'availability',    compute_availability(p_substation_id, p_year, p_month),
    'energy_balance',  compute_energy_balance(p_substation_id, p_year, p_month),
    'saidi_saifi',     compute_saidi_saifi(p_substation_id, p_year, p_month),
    'open_ptw_count',  (
      select count(*) from ptw_requests
      where substation_id = p_substation_id
        and status in ('ISSUED','WORK_IN_PROGRESS')
    ),
    'open_wo_count',   (
      select count(*) from work_orders
      where substation_id = p_substation_id
        and status in ('PLANNED','ASSIGNED','IN_PROGRESS','PENDING_PTW')
    ),
    'open_defect_count', (
      select count(*) from defects
      where substation_id = p_substation_id
        and status in ('OPEN','WO_RAISED')
    ),
    'overdue_wo_count', (
      select count(*) from work_orders
      where substation_id = p_substation_id
        and status not in ('COMPLETED','CANCELLED')
        and scheduled_date < current_date
    ),
    'critical_defect_count', (
      select count(*) from defects
      where substation_id = p_substation_id
        and status = 'OPEN'
        and priority = 'CRITICAL'
    )
  );
$$;

-- ── Org hierarchy helpers ─────────────────────────────────────────────────

-- Returns the full ancestor chain for an org unit (for breadcrumbs)
create or replace function get_org_ancestors(p_org_unit_id uuid)
returns table(id uuid, name text, level smallint) language sql stable security definer as $$
  with recursive ancestors as (
    select ou.id, ou.name, ou.level, ou.parent_id
    from org_units ou where ou.id = p_org_unit_id
    union all
    select ou.id, ou.name, ou.level, ou.parent_id
    from org_units ou
    join ancestors a on ou.id = a.parent_id
  )
  select id, name, level from ancestors order by level;
$$;

-- Returns all substations a user can access (for substation picker)
create or replace function get_accessible_substations(p_user_id uuid)
returns table(
  id uuid, name text, code text, voltage_kv numeric,
  parent_name text, parent_id uuid
) language sql stable security definer as $$
  select distinct
    ss.id, ss.name, ss.code, ss.voltage_kv,
    parent.name as parent_name, parent.id as parent_id
  from user_role_assignments ura
  join org_units scope  on scope.id  = ura.org_unit_id
  join org_units ss     on ss.level  = 5   -- substation level
                        and (ss.path <@ scope.path or ss.id = scope.id)
  left join org_units parent on parent.id = ss.parent_id
  where ura.user_id = p_user_id
    and (ura.valid_from is null or ura.valid_from <= current_date)
    and (ura.valid_to   is null or ura.valid_to   >= current_date);
$$;

-- ── Shift log helpers ─────────────────────────────────────────────────────

-- Returns or creates the active shift for today
create or replace function get_or_create_shift(
  p_substation_id uuid,
  p_shift_date    date,
  p_shift_type    text,
  p_user_id       uuid
) returns shift_logs language plpgsql security definer as $$
declare
  v_shift shift_logs;
  v_tenant_id uuid;
begin
  -- Try to find existing
  select * into v_shift
  from shift_logs
  where substation_id = p_substation_id
    and shift_date    = p_shift_date
    and shift_type    = p_shift_type;

  if not found then
    select tenant_id into v_tenant_id from org_units where id = p_substation_id;

    insert into shift_logs (tenant_id, substation_id, shift_date, shift_type, shift_in_charge, started_at)
    values (v_tenant_id, p_substation_id, p_shift_date, p_shift_type, p_user_id, now())
    returning * into v_shift;
  end if;

  return v_shift;
end;
$$;

-- ── Maintenance overdue check ─────────────────────────────────────────────

create or replace function get_overdue_maintenance(
  p_substation_id uuid,
  p_days_ahead    int default 7   -- also flag items due within N days
) returns table(
  equipment_id    uuid,
  equipment_name  text,
  plan_title      text,
  last_done_at    date,
  next_due_at     date,
  days_overdue    int
) language sql stable security definer as $$
  select
    e.id,
    e.name,
    mp.title,
    ms.last_done_at,
    ms.next_due_at,
    (current_date - ms.next_due_at)::int as days_overdue
  from maintenance_schedules ms
  join equipment e on e.id = ms.equipment_id
  join maintenance_plans mp on mp.id = ms.plan_id
  where e.org_unit_id = p_substation_id
    and ms.next_due_at <= current_date + p_days_ahead
  order by ms.next_due_at;
$$;
