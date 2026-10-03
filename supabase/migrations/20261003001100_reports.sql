-- ============================================================================
-- 1100 REPORTS  (owner: Analytics team)
-- KPI functions callable for ANY org unit; they aggregate over its subtree.
-- All are security invoker: the caller's RLS decides which rows count.
-- ============================================================================

set search_path = public, extensions;  -- ltree lives in the extensions schema

-- Availability % = (period hours − forced outage hours) / period hours × 100
-- Forced outages = TRIPPING + BREAKDOWN stoppages recorded at this unit.
create function compute_availability(p_org_unit_id uuid, p_year integer, p_month integer)
returns numeric
language sql stable security invoker set search_path = public as $$
  with p as (
    select case when p_month = 0 then make_date(p_year, 1, 1) else make_date(p_year, p_month, 1) end::timestamptz as s,
           case when p_month = 0 then make_date(p_year + 1, 1, 1)
                else (make_date(p_year, p_month, 1) + interval '1 month')::date end::timestamptz as e
  ), o as (
    select coalesce(sum(extract(epoch from (least(coalesce(st.ended_at, now()), p.e) - greatest(st.started_at, p.s))) / 3600), 0) as outage_h
    from p
    left join stoppages st on st.org_unit_id = p_org_unit_id
                          and st.stoppage_type in ('TRIPPING','BREAKDOWN')
                          and st.started_at < p.e
                          and coalesce(st.ended_at, now()) > p.s
  )
  select round(100.0 * (extract(epoch from (p.e - p.s)) / 3600 - o.outage_h)
               / nullif(extract(epoch from (p.e - p.s)) / 3600, 0), 2)
  from p, o;
$$;

-- SAIDI = Σ(customer-hours interrupted) / total customers
-- SAIFI = Σ(customers interrupted) / total customers
-- CAIDI = SAIDI / SAIFI. Aggregated over the unit's subtree.
create function compute_saidi_saifi(p_org_unit_id uuid, p_year integer, p_month integer)
returns jsonb
language sql stable security invoker set search_path = public, extensions as $$
  with root as (select path from org_units where id = p_org_unit_id),
  p as (
    select case when p_month = 0 then make_date(p_year, 1, 1) else make_date(p_year, p_month, 1) end::timestamptz as s,
           case when p_month = 0 then make_date(p_year + 1, 1, 1)
                else (make_date(p_year, p_month, 1) + interval '1 month')::date end::timestamptz as e
  ),
  consumers as (
    select coalesce(sum(u.total_consumers), 0) as n
    from org_units u, root where u.path <@ root.path
  ),
  events as (
    select coalesce(sum(st.consumers_affected * extract(epoch from (coalesce(st.ended_at, now()) - st.started_at)) / 3600), 0) as cust_hours,
           coalesce(sum(st.consumers_affected), 0) as cust_interrupted
    from stoppages st
    join org_units u on u.id = st.org_unit_id, root, p
    where u.path <@ root.path
      and st.stoppage_type in ('TRIPPING','BREAKDOWN')
      and st.started_at >= p.s and st.started_at < p.e
      and st.consumers_affected is not null
  )
  select jsonb_build_object(
    'saidi', round(events.cust_hours / nullif(consumers.n, 0), 4),
    'saifi', round(events.cust_interrupted::numeric / nullif(consumers.n, 0), 4),
    'caidi', round(events.cust_hours / nullif(events.cust_interrupted, 0), 4),
    'total_consumers', consumers.n
  )
  from events, consumers;
$$;

-- One call for the whole dashboard of any unit.
create function get_dashboard_kpis(p_org_unit_id uuid, p_year integer, p_month integer)
returns jsonb
language sql stable security invoker set search_path = public, extensions as $$
  with root as (select path from org_units where id = p_org_unit_id),
  units as (select u.id from org_units u, root where u.path <@ root.path)
  select jsonb_build_object(
    'availability',   compute_availability(p_org_unit_id, p_year, p_month),
    'energy_balance', compute_energy_balance(p_org_unit_id, p_year, p_month),
    'reliability',    compute_saidi_saifi(p_org_unit_id, p_year, p_month),
    'open_ptw',       (select count(*) from ptw_requests where org_unit_id in (select id from units)
                         and status in ('ISSUED','WORK_IN_PROGRESS')),
    'open_work_orders', (select count(*) from work_orders where org_unit_id in (select id from units)
                         and status not in ('COMPLETED','CANCELLED')),
    'overdue_work_orders', (select count(*) from work_orders where org_unit_id in (select id from units)
                         and status not in ('COMPLETED','CANCELLED') and scheduled_date < current_date),
    'open_defects',   (select count(*) from defects where org_unit_id in (select id from units)
                         and status <> 'CLOSED'),
    'critical_defects', (select count(*) from defects where org_unit_id in (select id from units)
                         and status <> 'CLOSED' and priority = 'CRITICAL')
  );
$$;
