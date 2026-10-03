-- ============================================================================
-- 1000 NOTIFICATIONS  (owner: Platform team)
-- Written by Edge Functions (deadlines, overruns) with the service role.
-- Targeted at one user (user_id) or at everyone who can see an org unit.
-- ============================================================================

create table notifications (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id) on delete cascade,
  org_unit_id  uuid references org_units(id) on delete cascade,
  user_id      uuid references user_profiles(id) on delete cascade,
  type         text not null,       -- CEIG_DEADLINE, ENERGY_STATEMENT_DUE, PTW_OVERRUN …
  priority     text not null default 'HIGH' check (priority in ('CRITICAL','HIGH','MEDIUM','LOW')),
  title        text not null,
  body         text not null,
  entity_type  text,
  entity_id    uuid,
  is_read      boolean not null default false,
  read_at      timestamptz,
  read_by      uuid references user_profiles(id),
  created_at   timestamptz not null default now(),
  check (org_unit_id is not null or user_id is not null)
);

create index notifications_unread_idx on notifications (tenant_id, org_unit_id) where not is_read;
create index notifications_user_idx   on notifications (user_id) where user_id is not null;
create index notifications_entity_idx on notifications (entity_type, entity_id, type, created_at desc);

alter table notifications enable row level security;

create policy notifications_read on notifications for select to authenticated
  using (tenant_id = current_tenant_id()
         and (user_id = (select auth.uid()) or (user_id is null and can_read_org_unit(org_unit_id))));
create policy notifications_mark_read on notifications for update to authenticated
  using (tenant_id = current_tenant_id()
         and (user_id = (select auth.uid()) or (user_id is null and can_read_org_unit(org_unit_id))))
  with check (tenant_id = current_tenant_id());
