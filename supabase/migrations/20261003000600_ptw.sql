-- ============================================================================
-- 0600 PERMIT TO WORK  (owner: Safety / PTW team)
-- Shutdown form (Reg 9a) + Permit to Work (Reg 9b), CEA Safety Regulations.
-- The workflow is enforced in the database, not only in the app:
--   DRAFT → PENDING_SLDC → SLDC_APPROVED → ISOLATION_DONE → ISSUED
--         → WORK_IN_PROGRESS → RETURNED → CLOSED        (any open state → CANCELLED)
-- Each transition requires a specific permission at the permit's unit.
-- ============================================================================

create type ptw_status as enum (
  'DRAFT','PENDING_SLDC','SLDC_APPROVED','ISOLATION_DONE',
  'ISSUED','WORK_IN_PROGRESS','RETURNED','CLOSED','CANCELLED'
);

create table ptw_requests (
  id                  uuid primary key default gen_random_uuid(),
  ptw_number          text unique,                     -- assigned by trigger
  tenant_id           uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id         uuid not null references org_units(id) on delete restrict,
  equipment_id        uuid not null references equipment(id) on delete restrict,
  status              ptw_status not null default 'DRAFT',
  work_description    text not null,
  planned_start       timestamptz not null,
  planned_end         timestamptz not null,
  sldc_reference      text,
  sldc_approved_at    timestamptz,
  isolation_points    jsonb not null default '[]',
  earthing_points     jsonb not null default '[]',
  safety_precautions  text,
  issued_at           timestamptz,
  issued_by           uuid references user_profiles(id),
  workman_user_id     uuid references user_profiles(id),
  work_started_at     timestamptz,
  returned_at         timestamptz,
  closed_at           timestamptz,
  cancelled_at        timestamptz,
  cancel_reason       text,
  created_by          uuid default auth.uid() references user_profiles(id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (planned_end > planned_start)
);

create index ptw_org_status_idx on ptw_requests (org_unit_id, status);

alter table stoppages add constraint stoppages_ptw_fk foreign key (ptw_id) references ptw_requests(id);

create trigger trg_ptw_updated_at before update on ptw_requests
  for each row execute function set_updated_at();
create trigger trg_ptw_audit after insert or update or delete on ptw_requests
  for each row execute function audit_row_change();

create function ptw_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status <> 'DRAFT' then
    raise exception 'A permit must start as DRAFT';
  end if;
  new.ptw_number := next_document_number(new.tenant_id, 'PTW', 'PTW');
  return new;
end;
$$;

create trigger trg_ptw_before_insert before insert on ptw_requests
  for each row execute function ptw_before_insert();

create function ptw_before_update() returns trigger
language plpgsql set search_path = public as $$
declare
  v_required text;
begin
  -- Segregation of duties (CEA Safety Reg): issuer cannot be the workman
  if new.issued_by is not null and new.issued_by = new.workman_user_id then
    raise exception 'The permit issuer and the person in charge of work must be different people';
  end if;

  if new.ptw_number is distinct from old.ptw_number then
    raise exception 'Permit number cannot be changed';
  end if;

  if new.status = old.status then
    if old.status in ('CLOSED','CANCELLED') then
      raise exception 'A % permit cannot be edited', old.status;
    end if;
    return new;
  end if;

  v_required := case
    when new.status = 'CANCELLED' and old.status not in ('CLOSED','CANCELLED') then 'PTW_CANCEL'
    when old.status = 'DRAFT'            and new.status = 'PENDING_SLDC'     then 'PTW_REQUEST'
    when old.status = 'PENDING_SLDC'     and new.status = 'SLDC_APPROVED'    then 'PTW_APPROVE_SLDC'
    when old.status = 'SLDC_APPROVED'    and new.status = 'ISOLATION_DONE'   then 'PTW_ISSUE'
    when old.status = 'ISOLATION_DONE'   and new.status = 'ISSUED'           then 'PTW_ISSUE'
    when old.status = 'ISSUED'           and new.status = 'WORK_IN_PROGRESS' then 'PTW_ISSUE'
    when old.status = 'WORK_IN_PROGRESS' and new.status = 'RETURNED'         then 'PTW_ISSUE'
    when old.status = 'RETURNED'         and new.status = 'CLOSED'           then 'PTW_ISSUE'
  end;

  if v_required is null then
    raise exception 'Invalid permit transition % → %', old.status, new.status;
  end if;

  if auth.uid() is not null and not user_has_permission(v_required, new.org_unit_id) then
    raise exception 'Permission % is required for % → %', v_required, old.status, new.status;
  end if;

  case new.status
    when 'SLDC_APPROVED' then new.sldc_approved_at := coalesce(new.sldc_approved_at, now());
    when 'ISSUED' then
      if new.workman_user_id is null then
        raise exception 'Person in charge of work is required before issuing';
      end if;
      if jsonb_array_length(new.earthing_points) = 0 then
        raise exception 'Earthing points must be recorded before issuing';
      end if;
      new.issued_at := now();
      new.issued_by := coalesce(auth.uid(), new.issued_by);
      if new.issued_by = new.workman_user_id then
        raise exception 'The permit issuer and the person in charge of work must be different people';
      end if;
    when 'WORK_IN_PROGRESS' then new.work_started_at := now();
    when 'RETURNED'         then new.returned_at := now();
    when 'CLOSED'           then new.closed_at := now();
    when 'CANCELLED'        then
      if coalesce(trim(new.cancel_reason), '') = '' then
        raise exception 'A cancellation reason is required';
      end if;
      new.cancelled_at := now();
    else null;
  end case;

  return new;
end;
$$;

create trigger trg_ptw_before_update before update on ptw_requests
  for each row execute function ptw_before_update();

revoke execute on function ptw_before_insert() from public, anon, authenticated;
revoke execute on function ptw_before_update() from public, anon, authenticated;

alter table ptw_requests enable row level security;

create policy ptw_read on ptw_requests for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy ptw_insert on ptw_requests for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('PTW_REQUEST', org_unit_id));
-- Coarse gate here; the trigger enforces the exact permission per transition.
create policy ptw_update on ptw_requests for update to authenticated
  using (tenant_id = current_tenant_id() and (
           user_has_permission('PTW_REQUEST', org_unit_id) or user_has_permission('PTW_ISSUE', org_unit_id)
        or user_has_permission('PTW_APPROVE_SLDC', org_unit_id) or user_has_permission('PTW_CANCEL', org_unit_id)))
  with check (tenant_id = current_tenant_id());
