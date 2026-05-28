-- Add price field to list_items
ALTER TABLE list_items ADD COLUMN price DECIMAL(10, 2);

-- Drop and recreate the privacy view to include price
DROP VIEW IF EXISTS list_items_with_privacy;

CREATE VIEW list_items_with_privacy AS
SELECT 
  li.id,
  li.list_id,
  li.name,
  li.description,
  li.link,
  li.image_url,
  li.price,
  li.created_at,
  l.user_id as list_owner_id,
  -- Show purchased_by_user_id only if:
  -- 1. The viewer is not the list owner, OR
  -- 2. The event is over
  CASE 
    WHEN auth.uid() != l.user_id THEN li.purchased_by_user_id
    WHEN EXISTS (
      SELECT 1 FROM event_lists el
      JOIN events e ON e.id = el.event_id
      WHERE el.list_id = li.list_id
      AND e.is_over = true
    ) THEN li.purchased_by_user_id
    ELSE NULL
  END as purchased_by_user_id,
  -- Show purchased_at with same logic
  CASE 
    WHEN auth.uid() != l.user_id THEN li.purchased_at
    WHEN EXISTS (
      SELECT 1 FROM event_lists el
      JOIN events e ON e.id = el.event_id
      WHERE el.list_id = li.list_id
      AND e.is_over = true
    ) THEN li.purchased_at
    ELSE NULL
  END as purchased_at,
  -- Show if item is purchased (boolean), visible to everyone
  CASE 
    WHEN li.purchased_by_user_id IS NOT NULL THEN true
    ELSE false
  END as is_purchased
FROM list_items li
JOIN lists l ON l.id = li.list_id;

-- Grant access to the view
GRANT SELECT ON list_items_with_privacy TO authenticated;

