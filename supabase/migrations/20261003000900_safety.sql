-- ============================================================================
-- 0900 SAFETY  (owner: Safety team)
-- Accident / Dangerous Occurrence Register. CEA Safety Regulations require
-- notification to the Electrical Inspector (CEIG) within 24 hours.
-- ============================================================================

create table accident_reports (
  id                   uuid primary key default gen_random_uuid(),
  report_number        text unique,
  tenant_id            uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  org_unit_id          uuid not null references org_units(id) on delete restrict,
  equipment_id         uuid references equipment(id) on delete restrict,
  occurred_at          timestamptz not null,
  accident_type        text not null check (accident_type in ('FATAL','INJURY','DANGEROUS_OCCURRENCE','NEAR_MISS')),
  description          text not null,
  persons_involved     text,
  immediate_cause      text,
  root_cause           text,
  corrective_action    text,
  ceig_notified_at     timestamptz,
  ceig_reference       text,
  report_submitted_at  timestamptz,
  photo_paths          text[] not null default '{}',
  created_by           uuid default auth.uid() references user_profiles(id),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index accident_org_time_idx on accident_reports (org_unit_id, occurred_at desc);
create index accident_ceig_pending_idx on accident_reports (occurred_at) where ceig_notified_at is null;

create trigger trg_accident_updated_at before update on accident_reports
  for each row execute function set_updated_at();
create trigger trg_accident_audit after insert or update or delete on accident_reports
  for each row execute function audit_row_change();

create function accident_reports_number() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.report_number := next_document_number(new.tenant_id, 'ACCIDENT', 'ACC');
  return new;
end;
$$;
create trigger trg_accident_number before insert on accident_reports
  for each row execute function accident_reports_number();
revoke execute on function accident_reports_number() from public, anon, authenticated;

alter table accident_reports enable row level security;

create policy accident_read on accident_reports for select to authenticated
  using (tenant_id = current_tenant_id() and can_read_org_unit(org_unit_id));
create policy accident_insert on accident_reports for insert to authenticated
  with check (tenant_id = current_tenant_id() and user_has_permission('ACCIDENT_REPORT', org_unit_id));
create policy accident_update on accident_reports for update to authenticated
  using (tenant_id = current_tenant_id() and user_has_permission('ACCIDENT_REPORT', org_unit_id))
  with check (tenant_id = current_tenant_id() and user_has_permission('ACCIDENT_REPORT', org_unit_id));
