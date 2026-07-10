-- Driver management: profile fields + avatar storage

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS vehicle_note TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-avatars', 'driver-avatars', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

DROP POLICY IF EXISTS "driver_avatars_public_read" ON storage.objects;
CREATE POLICY "driver_avatars_public_read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'driver-avatars');

DROP POLICY IF EXISTS "driver_avatars_admin_insert" ON storage.objects;
CREATE POLICY "driver_avatars_admin_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'driver-avatars'
    AND public.is_admin()
  );

DROP POLICY IF EXISTS "driver_avatars_admin_update" ON storage.objects;
CREATE POLICY "driver_avatars_admin_update" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'driver-avatars'
    AND public.is_admin()
  );

DROP POLICY IF EXISTS "driver_avatars_admin_delete" ON storage.objects;
CREATE POLICY "driver_avatars_admin_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'driver-avatars'
    AND public.is_admin()
  );
