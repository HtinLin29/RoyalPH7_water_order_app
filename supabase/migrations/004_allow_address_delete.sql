-- Allow deleting addresses when only completed/cancelled orders reference them.
-- Snapshot delivery details on orders so history remains intact.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_recipient_name TEXT,
  ADD COLUMN IF NOT EXISTS delivery_phone TEXT,
  ADD COLUMN IF NOT EXISTS delivery_full_address TEXT,
  ADD COLUMN IF NOT EXISTS delivery_landmark_note TEXT;

UPDATE orders o
SET
  delivery_recipient_name = a.recipient_name,
  delivery_phone = a.phone,
  delivery_full_address = a.full_address,
  delivery_landmark_note = a.landmark_note
FROM addresses a
WHERE o.address_id = a.id
  AND o.delivery_full_address IS NULL;

ALTER TABLE orders
  ALTER COLUMN address_id DROP NOT NULL;
