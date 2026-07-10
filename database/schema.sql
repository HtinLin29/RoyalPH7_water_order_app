-- Royal Ph7 — Complete Supabase Database Schema
-- Generated from lib/models/ and lib/services/
--
-- Usage: paste into Supabase Dashboard → SQL Editor on a new project.
-- Requires Supabase Auth (auth.users) and Storage enabled.

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- HELPER: admin role check (avoids RLS recursion on profiles)
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon, service_role;

-- ============================================================
-- 1. PROFILES
-- ============================================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY
    REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT DEFAULT '',
  role TEXT NOT NULL DEFAULT 'customer'
    CHECK (role IN ('customer', 'driver', 'admin')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  shift_status TEXT NOT NULL DEFAULT 'off'
    CHECK (shift_status IN ('off', 'available', 'on_delivery')),
  vehicle_note TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. PRODUCTS
-- ============================================================
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  price DECIMAL(10, 2) NOT NULL,
  image_url TEXT,
  is_available BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 3. ADDRESSES
-- ============================================================
CREATE TABLE public.addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  label TEXT NOT NULL DEFAULT 'Home',
  recipient_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  full_address TEXT NOT NULL,
  landmark_note TEXT,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_addresses_user_id ON public.addresses(user_id);

-- ============================================================
-- 4. ORDERS
-- ============================================================
CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  driver_id UUID
    REFERENCES public.profiles(id) ON DELETE SET NULL,
  address_id UUID
    REFERENCES public.addresses(id) ON DELETE SET NULL,
  delivery_recipient_name TEXT,
  delivery_phone TEXT,
  delivery_full_address TEXT,
  delivery_landmark_note TEXT,
  order_reference TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'placed'
    CHECK (status IN ('placed', 'confirmed', 'on_the_way', 'delivered', 'cancelled')),
  delivery_date DATE NOT NULL,
  time_slot TEXT NOT NULL
    CHECK (time_slot IN ('morning', 'afternoon', 'evening')),
  payment_method TEXT NOT NULL DEFAULT 'cod',
  total_price DECIMAL(10, 2) NOT NULL,
  delivery_note TEXT,
  placed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ,
  on_the_way_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_customer_id ON public.orders(customer_id);
CREATE INDEX idx_orders_driver_id ON public.orders(driver_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_delivery_date ON public.orders(delivery_date);
CREATE INDEX idx_orders_placed_at ON public.orders(placed_at);

-- ============================================================
-- 5. ORDER ITEMS
-- ============================================================
CREATE TABLE public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL
    REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL
    REFERENCES public.products(id),
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10, 2) NOT NULL,
  subtotal DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);

-- ============================================================
-- 6. NOTIFICATIONS
-- ============================================================
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  order_id UUID
    REFERENCES public.orders(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);

-- ============================================================
-- 7. MESSAGES (customer ↔ admin chat)
-- ============================================================
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  sender_role TEXT NOT NULL
    CHECK (sender_role IN ('customer', 'admin')),
  content TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_customer_created_at
  ON public.messages(customer_id, created_at);

-- ============================================================
-- 8. CONVERSATION META (chat inbox summaries)
-- ============================================================
CREATE TABLE public.conversation_meta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL UNIQUE
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  unread_customer INT NOT NULL DEFAULT 0,
  unread_admin INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_conversation_meta_last_message_at
  ON public.conversation_meta(last_message_at DESC);

-- ============================================================
-- AUTH TRIGGER: auto-create profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role text;
BEGIN
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'customer');

  INSERT INTO public.profiles (
    id,
    full_name,
    phone,
    role,
    is_active,
    shift_status
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    user_role,
    true,
    'off'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT ALL ON public.profiles TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;

-- ============================================================
-- RPC: customer email change
-- ============================================================
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

-- ============================================================
-- RPC: customer account deletion
-- ============================================================
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

  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_meta ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles NO FORCE ROW LEVEL SECURITY;

-- profiles
CREATE POLICY "profiles_own" ON public.profiles
  FOR ALL
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_admin" ON public.profiles
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_auth_admin_insert" ON public.profiles
  FOR INSERT
  TO supabase_auth_admin
  WITH CHECK (true);

CREATE POLICY "profiles_service_role" ON public.profiles
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- products
CREATE POLICY "products_read" ON public.products
  FOR SELECT
  USING (true);

CREATE POLICY "products_admin_write" ON public.products
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- addresses
CREATE POLICY "addresses_own" ON public.addresses
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- orders
CREATE POLICY "orders_customer" ON public.orders
  FOR ALL
  USING (auth.uid() = customer_id)
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "orders_driver_select" ON public.orders
  FOR SELECT
  USING (auth.uid() = driver_id);

CREATE POLICY "orders_driver_update" ON public.orders
  FOR UPDATE
  USING (auth.uid() = driver_id)
  WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "orders_admin" ON public.orders
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- order_items
CREATE POLICY "order_items_access" ON public.order_items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.orders
      WHERE orders.id = order_items.order_id
        AND (orders.customer_id = auth.uid()
          OR orders.driver_id = auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders
      WHERE orders.id = order_items.order_id
        AND (orders.customer_id = auth.uid()
          OR orders.driver_id = auth.uid())
    )
  );

CREATE POLICY "order_items_admin" ON public.order_items
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- notifications
CREATE POLICY "notifications_own" ON public.notifications
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notifications_admin" ON public.notifications
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "notifications_driver_insert_customer" ON public.notifications
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders
      WHERE orders.id = order_id
        AND orders.driver_id = auth.uid()
        AND user_id = orders.customer_id
    )
  );

-- messages
CREATE POLICY "messages_customer_access" ON public.messages
  FOR ALL
  USING (auth.uid() = customer_id)
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "messages_admin_access" ON public.messages
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- conversation_meta
CREATE POLICY "conversation_meta_customer_access" ON public.conversation_meta
  FOR ALL
  USING (auth.uid() = customer_id)
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "conversation_meta_admin_access" ON public.conversation_meta
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ============================================================
-- STORAGE: driver avatar bucket
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-avatars', 'driver-avatars', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

CREATE POLICY "driver_avatars_public_read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'driver-avatars');

CREATE POLICY "driver_avatars_admin_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'driver-avatars'
    AND public.is_admin()
  );

CREATE POLICY "driver_avatars_admin_update" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'driver-avatars'
    AND public.is_admin()
  );

CREATE POLICY "driver_avatars_admin_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'driver-avatars'
    AND public.is_admin()
  );

-- ============================================================
-- REALTIME (used by .stream() in the Flutter app)
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_meta;

-- ============================================================
-- SEED DATA: default products
-- ============================================================
INSERT INTO public.products (name, description, price, is_available, sort_order)
VALUES
  (
    '350ml Bottle',
    'Small purified water bottle. Perfect for on-the-go hydration.',
    8.00,
    true,
    1
  ),
  (
    '1L Bottle',
    'Medium purified water bottle. Ideal for daily use at home or office.',
    15.00,
    true,
    2
  ),
  (
    '20L Bottle',
    'Large water jug for home and office dispensers. Our most popular size.',
    80.00,
    true,
    3
  );
