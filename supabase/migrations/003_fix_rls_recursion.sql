-- Fix infinite recursion in profiles RLS policies
-- Error: "infinite recursion detected in policy for relation profiles"

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

-- Fix profiles policies
DROP POLICY IF EXISTS "profiles_admin" ON profiles;
CREATE POLICY "profiles_admin" ON profiles
  FOR ALL USING (public.is_admin());

-- Fix products admin policy (also queried profiles recursively)
DROP POLICY IF EXISTS "products_admin_write" ON products;
CREATE POLICY "products_admin_write" ON products
  FOR ALL USING (public.is_admin());

-- Fix orders admin policy
DROP POLICY IF EXISTS "orders_admin" ON orders;
CREATE POLICY "orders_admin" ON orders
  FOR ALL USING (public.is_admin());

-- Fix order_items admin policy
DROP POLICY IF EXISTS "order_items_admin" ON order_items;
CREATE POLICY "order_items_admin" ON order_items
  FOR ALL USING (public.is_admin());
