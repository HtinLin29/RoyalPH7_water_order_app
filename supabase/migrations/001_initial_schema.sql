-- Royal Ph7 — Complete Database Migration
-- Paste this entire file into Supabase SQL Editor and run.

-- ============================================================
-- 1. PROFILES TABLE
-- ============================================================
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id)
    ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'customer'
    CHECK (role IN ('customer','driver','admin')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 2. PRODUCTS TABLE
-- ============================================================
CREATE TABLE products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  image_url TEXT,
  is_available BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. ADDRESSES TABLE
-- ============================================================
CREATE TABLE addresses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id)
    ON DELETE CASCADE NOT NULL,
  label TEXT DEFAULT 'Home',
  recipient_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  full_address TEXT NOT NULL,
  landmark_note TEXT,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. ORDERS TABLE
-- ============================================================
CREATE TABLE orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID REFERENCES profiles(id) NOT NULL,
  driver_id UUID REFERENCES profiles(id),
  address_id UUID REFERENCES addresses(id) NOT NULL,
  order_reference TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'placed'
    CHECK (status IN ('placed','confirmed','on_the_way','delivered','cancelled')),
  delivery_date DATE NOT NULL,
  time_slot TEXT NOT NULL
    CHECK (time_slot IN ('morning','afternoon','evening')),
  payment_method TEXT DEFAULT 'cod',
  total_price DECIMAL(10,2) NOT NULL,
  delivery_note TEXT,
  placed_at TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ,
  on_the_way_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. ORDER ITEMS TABLE
-- ============================================================
CREATE TABLE order_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID REFERENCES orders(id)
    ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES products(id) NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. NOTIFICATIONS TABLE
-- ============================================================
CREATE TABLE notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id)
    ON DELETE CASCADE NOT NULL,
  order_id UUID REFERENCES orders(id),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Profiles: users see own profile, admin sees all
CREATE POLICY "profiles_own" ON profiles
  FOR ALL USING (auth.uid() = id);

CREATE POLICY "profiles_admin" ON profiles
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin')
  );

-- Products: everyone can read, only admin can write
CREATE POLICY "products_read" ON products
  FOR SELECT USING (true);

CREATE POLICY "products_admin_write" ON products
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin')
  );

-- Addresses: users see own addresses only
CREATE POLICY "addresses_own" ON addresses
  FOR ALL USING (auth.uid() = user_id);

-- Orders: customer sees own orders, driver sees assigned, admin sees all
CREATE POLICY "orders_customer" ON orders
  FOR ALL USING (auth.uid() = customer_id);

CREATE POLICY "orders_driver" ON orders
  FOR SELECT USING (auth.uid() = driver_id);

CREATE POLICY "orders_driver_update" ON orders
  FOR UPDATE USING (auth.uid() = driver_id);

CREATE POLICY "orders_admin" ON orders
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin')
  );

-- Order items: follow order access
CREATE POLICY "order_items_access" ON order_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND (orders.customer_id = auth.uid()
        OR orders.driver_id = auth.uid()))
  );

CREATE POLICY "order_items_admin" ON order_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin')
  );

-- Notifications: users see own only
CREATE POLICY "notifications_own" ON notifications
  FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 8. SEED DATA — 3 products
-- ============================================================
INSERT INTO products (name, description, price, is_available, sort_order)
VALUES
  ('350ml Bottle',
   'Small purified water bottle. Perfect for on-the-go hydration.',
   8.00, true, 1),
  ('1L Bottle',
   'Medium purified water bottle. Ideal for daily use at home or office.',
   15.00, true, 2),
  ('20L Bottle',
   'Large water jug for home and office dispensers. Our most popular size.',
   80.00, true, 3);
