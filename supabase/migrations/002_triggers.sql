-- ============================================================
-- Migration 002 — Triggers: sequences, updated_at, audit log
-- Run after 001_initial_schema.sql
-- ============================================================

-- ── updated_at automation ─────────────────────────────────────────────────

create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Add updated_at column + trigger to mutable tables
do $$
declare
  t text;
begin
  foreach t in array array[
    'org_units','user_profiles','equipment','shift_logs',
    'ptw_requests','defects','work_orders','maintenance_schedules','accident_reports'
  ] loop
    execute format('alter table %I add column if not exists updated_at timestamptz default now()', t);
    execute format('
      create or replace trigger trg_%I_updated_at
      before update on %I
      for each row execute function set_updated_at()', t, t);
  end loop;
end;
$$;

-- ── Sequential number generators ─────────────────────────────────────────
-- Format: PTW-YYYY-NNNNNN (per tenant per year)

create table if not exists sequences (
  tenant_id  uuid not null references tenants(id),
  seq_type   text not null,   -- 'PTW', 'WO', 'DEFECT', 'ACCIDENT'
  year       smallint not null,
  last_val   integer not null default 0,
  primary key (tenant_id, seq_type, year)
);

create or replace function next_sequence(
  p_tenant_id uuid,
  p_type      text
) returns text language plpgsql as $$
declare
  v_year   smallint := extract(year from now())::smallint;
  v_next   integer;
  v_prefix text;
begin
  insert into sequences (tenant_id, seq_type, year, last_val)
  values (p_tenant_id, p_type, v_year, 1)
  on conflict (tenant_id, seq_type, year)
  do update set last_val = sequences.last_val + 1
  returning last_val into v_next;

  v_prefix := case p_type
    when 'PTW'      then 'PTW'
    when 'WO'       then 'WO'
    when 'DEFECT'   then 'DEF'
    when 'ACCIDENT' then 'ACC'
    else p_type
  end;

  return format('%s-%s-%s', v_prefix, v_year, lpad(v_next::text, 6, '0'));
end;
$$;

-- Auto-assign PTW number on insert
create or replace function trg_ptw_number_fn()
returns trigger language plpgsql as $$
begin
  if new.ptw_number is null or new.ptw_number = '' then
    new.ptw_number := next_sequence(new.tenant_id, 'PTW');
  end if;
  return new;
end;
$$;

create trigger trg_ptw_number
before insert on ptw_requests
for each row execute function trg_ptw_number_fn();

-- Auto-assign WO number
create or replace function trg_wo_number_fn()
returns trigger language plpgsql as $$
begin
  if new.wo_number is null or new.wo_number = '' then
    new.wo_number := next_sequence(new.tenant_id, 'WO');
  end if;
  return new;
end;
$$;

create trigger trg_wo_number
before insert on work_orders
for each row execute function trg_wo_number_fn();

-- Auto-assign defect number
create or replace function trg_defect_number_fn()
returns trigger language plpgsql as $$
begin
  if new.defect_number is null or new.defect_number = '' then
    new.defect_number := next_sequence(new.tenant_id, 'DEFECT');
  end if;
  return new;
end;
$$;

create trigger trg_defect_number
before insert on defects
for each row execute function trg_defect_number_fn();

-- Auto-assign accident report number
create or replace function trg_accident_number_fn()
returns trigger language plpgsql as $$
begin
  if new.report_number is null or new.report_number = '' then
    new.report_number := next_sequence(new.tenant_id, 'ACCIDENT');
  end if;
  return new;
end;
$$;

create trigger trg_accident_number
before insert on accident_reports
for each row execute function trg_accident_number_fn();

-- ── PTW Segregation of Duties enforcement ────────────────────────────────
-- Issuer cannot also be the workman (CEA Safety Regs)

create or replace function trg_ptw_sod_fn()
returns trigger language plpgsql as $$
begin
  if new.issued_by is not null
     and new.workman_user_id is not null
     and new.issued_by = new.workman_user_id then
    raise exception 'PTW SoD violation: issuer and workman cannot be the same person (CEA Safety Reg 30)';
  end if;
  return new;
end;
$$;

create trigger trg_ptw_sod
before insert or update on ptw_requests
for each row execute function trg_ptw_sod_fn();

-- ── Audit log trigger ─────────────────────────────────────────────────────
-- Fires on every INSERT/UPDATE on all key tables

create or replace function trg_audit_fn()
returns trigger language plpgsql security definer as $$
declare
  v_tenant_id uuid;
begin
  -- Extract tenant_id from the row (all audited tables have it)
  v_tenant_id := coalesce(
    (new::jsonb->>'tenant_id')::uuid,
    (old::jsonb->>'tenant_id')::uuid
  );

  insert into audit_logs (
    tenant_id, user_id, action, entity_type, entity_id,
    old_data, new_data
  ) values (
    v_tenant_id,
    auth.uid(),
    tg_op,        -- 'INSERT' | 'UPDATE' | 'DELETE'
    tg_table_name,
    coalesce((new::jsonb->>'id')::uuid, (old::jsonb->>'id')::uuid),
    case when tg_op = 'UPDATE' or tg_op = 'DELETE' then to_jsonb(old) else null end,
    case when tg_op = 'INSERT' or tg_op = 'UPDATE' then to_jsonb(new) else null end
  );
  return coalesce(new, old);
end;
$$;

-- Attach audit trigger to all safety-critical tables
do $$
declare
  t text;
begin
  foreach t in array array[
    'ptw_requests','work_orders','defects','accident_reports',
    'user_role_assignments','shift_logs','energy_readings'
  ] loop
    execute format('
      create or replace trigger trg_%I_audit
      after insert or update or delete on %I
      for each row execute function trg_audit_fn()', t, t);
  end loop;
end;
$$;

-- ── Maintenance schedule updater ──────────────────────────────────────────
-- When a WO is completed, advance the next_due_at on the schedule

create or replace function trg_wo_completed_fn()
returns trigger language plpgsql as $$
declare
  v_plan     maintenance_plans;
  v_interval interval;
begin
  -- Only act when status transitions to COMPLETED
  if old.status <> 'COMPLETED' and new.status = 'COMPLETED' then
    -- Find the plan that generated this WO (match by equipment + type)
    select mp.* into v_plan
    from maintenance_schedules ms
    join maintenance_plans mp on mp.id = ms.plan_id
    where ms.last_wo_id = new.id or ms.equipment_id = new.equipment_id
    limit 1;

    if found then
      v_interval := case v_plan.frequency_type
        when 'DAILY'       then interval '1 day'
        when 'MONTHLY'     then interval '1 month'
        when 'QUARTERLY'   then interval '3 months'
        when 'HALF_YEARLY' then interval '6 months'
        when 'YEARLY'      then interval '1 year'
        when '2_YEARLY'    then interval '2 years'
        when '3_YEARLY'    then interval '3 years'
        when '5_YEARLY'    then interval '5 years'
        else interval '1 year'
      end;

      update maintenance_schedules
      set last_done_at = new.completed_at::date,
          next_due_at  = (new.completed_at::date + v_interval),
          last_wo_id   = new.id
      where equipment_id = new.equipment_id
        and plan_id      = v_plan.id;
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_wo_completed
after update on work_orders
for each row execute function trg_wo_completed_fn();
