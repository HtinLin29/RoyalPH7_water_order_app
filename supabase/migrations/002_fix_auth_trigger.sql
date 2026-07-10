-- Fix: "Database error creating new user" in Supabase Auth
-- Safe to run on existing database (idempotent)
-- Run this ONCE in Supabase Dashboard → SQL Editor → Run

-- 1. Recreate trigger function with correct security settings
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

-- 2. Ensure trigger exists (drop + recreate)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 3. Grant permissions required by Supabase Auth admin
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT ALL ON public.profiles TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;

-- Ensure RLS does not block trigger inserts
ALTER TABLE public.profiles NO FORCE ROW LEVEL SECURITY;

-- 4. Fix RLS policies on profiles
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_auth_admin_insert" ON profiles;
CREATE POLICY "profiles_auth_admin_insert" ON profiles
  FOR INSERT TO supabase_auth_admin WITH CHECK (true);

DROP POLICY IF EXISTS "profiles_service_role" ON profiles;
CREATE POLICY "profiles_service_role" ON profiles
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 5. Backfill profiles for any existing auth users missing a profile
INSERT INTO public.profiles (id, full_name, phone, role)
SELECT
  id,
  COALESCE(raw_user_meta_data->>'full_name', 'New User'),
  COALESCE(raw_user_meta_data->>'phone', ''),
  COALESCE(raw_user_meta_data->>'role', 'customer')
FROM auth.users
WHERE id NOT IN (SELECT id FROM public.profiles)
ON CONFLICT (id) DO NOTHING;

-- 6. Verify
SELECT u.email, p.full_name, p.role
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
ORDER BY u.created_at;
