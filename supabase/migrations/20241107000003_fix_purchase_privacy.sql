-- Fix purchase privacy: list owners shouldn't see purchase status until latest event is over
-- Others can always see it (so they don't buy duplicate gifts)

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
  -- 2. All events linked to this list are over (checking the latest event by date)
  CASE 
    WHEN auth.uid() != l.user_id THEN li.purchased_by_user_id
    WHEN NOT EXISTS (
      -- Check if there are any events that are NOT over
      SELECT 1 FROM event_lists el
      JOIN events e ON e.id = el.event_id
      WHERE el.list_id = li.list_id
      AND e.is_over = false
    ) AND EXISTS (
      -- But make sure at least one event exists and is over
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
    WHEN NOT EXISTS (
      SELECT 1 FROM event_lists el
      JOIN events e ON e.id = el.event_id
      WHERE el.list_id = li.list_id
      AND e.is_over = false
    ) AND EXISTS (
      SELECT 1 FROM event_lists el
      JOIN events e ON e.id = el.event_id
      WHERE el.list_id = li.list_id
      AND e.is_over = true
    ) THEN li.purchased_at
    ELSE NULL
  END as purchased_at,
  -- Show if item is purchased (boolean)
  -- For list owners: only show if all linked events are over
  -- For others: always show
  CASE 
    WHEN auth.uid() != l.user_id THEN 
      -- Not the owner: show purchase status
      CASE WHEN li.purchased_by_user_id IS NOT NULL THEN true ELSE false END
    WHEN NOT EXISTS (
      -- Owner: only show if no active events remain
      SELECT 1 FROM event_lists el
      JOIN events e ON e.id = el.event_id
      WHERE el.list_id = li.list_id
      AND e.is_over = false
    ) AND EXISTS (
      -- And at least one event exists and is over
      SELECT 1 FROM event_lists el
      JOIN events e ON e.id = el.event_id
      WHERE el.list_id = li.list_id
      AND e.is_over = true
    ) THEN 
      CASE WHEN li.purchased_by_user_id IS NOT NULL THEN true ELSE false END
    ELSE false  -- Hide purchase status from owner if any event is still active
  END as is_purchased
FROM list_items li
JOIN lists l ON l.id = li.list_id;

-- Grant access to the view
GRANT SELECT ON list_items_with_privacy TO authenticated;

