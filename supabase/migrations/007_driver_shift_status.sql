-- Driver shift status: tracks daily availability separate from is_active account flag
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS shift_status text DEFAULT 'off'
  CHECK (shift_status IN ('off', 'available', 'on_delivery'));

-- Enable realtime updates for admin Drivers tab
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
  END IF;
END $$;
