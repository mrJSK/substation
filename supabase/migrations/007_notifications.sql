-- ============================================================
-- Migration 007 — Notifications table
-- Written by Edge Function notify-deadlines; read by Flutter app.
-- Offline-friendly: app pulls on login and caches locally.
-- ============================================================

create table notifications (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id),
  org_unit_id  uuid not null references org_units(id),
  type         text not null,           -- CEIG_DEADLINE | ENERGY_STATEMENT_DUE | PTW_OVERRUN
  priority     text not null default 'HIGH' check (priority in ('CRITICAL','HIGH','MEDIUM','LOW')),
  title        text not null,
  body         text not null,
  entity_type  text,                    -- table name: ptw_requests, accident_reports, etc.
  entity_id    uuid,
  is_read      boolean not null default false,
  read_at      timestamptz,
  read_by      uuid references auth.users(id),
  created_at   timestamptz not null default now()
);

create index notifications_tenant_unread on notifications(tenant_id, org_unit_id, is_read)
  where is_read = false;

create index notifications_entity on notifications(entity_type, entity_id);

-- RLS
alter table notifications enable row level security;

create policy notifications_select on notifications for select
  using (tenant_id = current_tenant_id());

create policy notifications_update on notifications for update
  using (tenant_id = current_tenant_id())
  with check (tenant_id = current_tenant_id());

-- Edge Function writes via service role (bypasses RLS) — no insert policy needed for client
