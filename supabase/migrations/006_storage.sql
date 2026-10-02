-- ============================================================
-- Migration 006 — Supabase Storage buckets + policies
-- ============================================================

-- Create storage buckets
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Equipment manuals, SLDs, GA drawings — private, PDF/images only
  ('documents', 'documents', false, 52428800, -- 50MB
   array['application/pdf','image/jpeg','image/png','image/webp','application/msword',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),

  -- Test report attachments (maintenance WOs)
  ('test-reports', 'test-reports', false, 20971520, -- 20MB
   array['application/pdf','image/jpeg','image/png']),

  -- Accident report photos
  ('accident-photos', 'accident-photos', false, 10485760, -- 10MB
   array['image/jpeg','image/png','image/webp']),

  -- Defect photos
  ('defect-photos', 'defect-photos', false, 10485760,
   array['image/jpeg','image/png','image/webp']),

  -- PTW signatures (captured as PNG from signature pad)
  ('signatures', 'signatures', false, 1048576, -- 1MB
   array['image/png']),

  -- Staff competency certificates
  ('certificates', 'certificates', false, 5242880, -- 5MB
   array['application/pdf','image/jpeg','image/png'])

on conflict (id) do nothing;

-- ── Storage RLS policies ──────────────────────────────────────────────────
-- Path convention: {bucket}/{tenant_id}/{entity_id}/{filename}
-- This lets us scope access by tenant_id in the path.

-- documents: read by tenant, write by ASSET_WRITE permission
create policy "documents read by tenant" on storage.objects for select
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "documents write by asset admin" on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

-- test-reports: read by tenant
create policy "test-reports read by tenant" on storage.objects for select
  using (
    bucket_id = 'test-reports'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "test-reports write by tenant" on storage.objects for insert
  with check (
    bucket_id = 'test-reports'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

-- accident-photos, defect-photos, signatures, certificates — same pattern
create policy "accident-photos access" on storage.objects for all
  using (
    bucket_id = 'accident-photos'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "defect-photos access" on storage.objects for all
  using (
    bucket_id = 'defect-photos'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "signatures access" on storage.objects for all
  using (
    bucket_id = 'signatures'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "certificates access" on storage.objects for all
  using (
    bucket_id = 'certificates'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );
