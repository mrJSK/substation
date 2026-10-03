-- ============================================================================
-- 1200 STORAGE  (owner: Platform team)
-- Object path convention for every bucket:
--   {tenant_id}/{org_unit_id}/{entity_id}/{file_name}
-- so access follows the same tenant + org-scope rules as the data.
-- ============================================================================

set search_path = public, extensions;  -- ltree lives in the extensions schema

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('documents',       'documents',       false, 52428800,
     array['application/pdf','image/jpeg','image/png','image/webp',
           'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('test-reports',    'test-reports',    false, 20971520, array['application/pdf','image/jpeg','image/png']),
  ('accident-photos', 'accident-photos', false, 10485760, array['image/jpeg','image/png','image/webp']),
  ('defect-photos',   'defect-photos',   false, 10485760, array['image/jpeg','image/png','image/webp']),
  ('signatures',      'signatures',      false, 1048576,  array['image/png']),
  ('certificates',    'certificates',    false, 5242880,  array['application/pdf','image/jpeg','image/png'])
on conflict (id) do nothing;

create function storage_path_allowed(p_name text) returns boolean
language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_parts text[] := storage.foldername(p_name);
  v_unit  uuid;
begin
  if array_length(v_parts, 1) < 2 or v_parts[1] <> current_tenant_id()::text then
    return false;
  end if;
  begin
    v_unit := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return can_read_org_unit(v_unit);
end;
$$;

create policy grid_objects_read on storage.objects for select to authenticated
  using (bucket_id in ('documents','test-reports','accident-photos','defect-photos','signatures','certificates')
         and storage_path_allowed(name));

create policy grid_objects_insert on storage.objects for insert to authenticated
  with check (bucket_id in ('documents','test-reports','accident-photos','defect-photos','signatures','certificates')
              and storage_path_allowed(name));
-- No update/delete: uploaded evidence is immutable. Replace by uploading a new object.
