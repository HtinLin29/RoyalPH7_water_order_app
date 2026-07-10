-- Customer self-service: change email + delete account (no Edge Functions needed).
-- Run this once in Supabase Dashboard → SQL Editor.

-- 1) FK fixes so account deletion can cascade cleanly
ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_customer_id_fkey;

ALTER TABLE orders
  ADD CONSTRAINT orders_customer_id_fkey
  FOREIGN KEY (customer_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_address_id_fkey;

ALTER TABLE orders
  ALTER COLUMN address_id DROP NOT NULL;

ALTER TABLE orders
  ADD CONSTRAINT orders_address_id_fkey
  FOREIGN KEY (address_id)
  REFERENCES addresses(id)
  ON DELETE SET NULL;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_driver_id_fkey;

ALTER TABLE orders
  ADD CONSTRAINT orders_driver_id_fkey
  FOREIGN KEY (driver_id)
  REFERENCES profiles(id)
  ON DELETE SET NULL;

-- 2) Customer changes their own login email (immediate, no confirmation email)
CREATE OR REPLACE FUNCTION public.update_own_email(new_email text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  role text;
  cleaned text := lower(trim(new_email));
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT p.role INTO role FROM public.profiles p WHERE p.id = uid;
  IF role IS DISTINCT FROM 'customer' THEN
    RAISE EXCEPTION 'Only customers can change their email here';
  END IF;

  IF cleaned IS NULL OR cleaned = '' OR position('@' in cleaned) = 0 THEN
    RAISE EXCEPTION 'Enter a valid email address';
  END IF;

  IF EXISTS (
    SELECT 1 FROM auth.users u
    WHERE lower(u.email) = cleaned AND u.id <> uid
  ) THEN
    RAISE EXCEPTION 'An account with this email already exists';
  END IF;

  UPDATE auth.users
  SET
    email = cleaned,
    email_confirmed_at = COALESCE(email_confirmed_at, now()),
    updated_at = now()
  WHERE id = uid;

  UPDATE auth.identities
  SET
    identity_data = jsonb_set(
      jsonb_set(COALESCE(identity_data, '{}'::jsonb), '{email}', to_jsonb(cleaned)),
      '{email_verified}',
      'true'::jsonb
    ),
    provider_id = cleaned,
    updated_at = now()
  WHERE user_id = uid
    AND provider = 'email';

  RETURN cleaned;
END;
$$;

REVOKE ALL ON FUNCTION public.update_own_email(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_own_email(text) TO authenticated;

-- 3) Customer deletes their own account + related data
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  role text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT p.role INTO role FROM public.profiles p WHERE p.id = uid;
  IF role IS DISTINCT FROM 'customer' THEN
    RAISE EXCEPTION 'Only customers can delete their account here';
  END IF;

  DELETE FROM public.order_items
  WHERE order_id IN (SELECT id FROM public.orders WHERE customer_id = uid);

  DELETE FROM public.notifications
  WHERE user_id = uid
     OR order_id IN (SELECT id FROM public.orders WHERE customer_id = uid);

  DELETE FROM public.messages WHERE customer_id = uid;
  DELETE FROM public.conversation_meta WHERE customer_id = uid;
  DELETE FROM public.orders WHERE customer_id = uid;
  DELETE FROM public.addresses WHERE user_id = uid;

  -- Cascades to profiles via profiles.id → auth.users(id) ON DELETE CASCADE
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;
