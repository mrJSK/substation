-- Migration 008 — Add total_consumers to org_units
-- Required by compute_saidi_saifi() function in 003_functions.sql

alter table org_units
  add column if not exists total_consumers integer default 0;
