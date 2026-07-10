-- Customer <-> Admin chat feature

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sender_role TEXT NOT NULL CHECK (sender_role IN ('customer', 'admin')),
  content TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS conversation_meta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  unread_customer INT NOT NULL DEFAULT 0,
  unread_admin INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_customer_created_at
  ON messages(customer_id, created_at);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'conversation_meta'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE conversation_meta;
  END IF;
END $$;

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_meta ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_customer_access" ON messages;
CREATE POLICY "messages_customer_access" ON messages
  FOR ALL
  USING (auth.uid() = customer_id)
  WITH CHECK (auth.uid() = customer_id);

DROP POLICY IF EXISTS "messages_admin_access" ON messages;
CREATE POLICY "messages_admin_access" ON messages
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "conversation_meta_customer_access" ON conversation_meta;
CREATE POLICY "conversation_meta_customer_access" ON conversation_meta
  FOR ALL
  USING (auth.uid() = customer_id)
  WITH CHECK (auth.uid() = customer_id);

DROP POLICY IF EXISTS "conversation_meta_admin_access" ON conversation_meta;
CREATE POLICY "conversation_meta_admin_access" ON conversation_meta
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
