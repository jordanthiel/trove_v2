-- Add policy to allow event members to view lists shared in their events
CREATE POLICY "Lists are viewable by event members"
  ON lists FOR SELECT
  USING (
    -- List owner can see their own lists
    auth.uid() = user_id
    OR
    -- Event members can see lists that are shared in events they belong to
    EXISTS (
      SELECT 1 FROM event_lists
      WHERE event_lists.list_id = lists.id
      AND is_event_member(event_lists.event_id, auth.uid())
    )
  );

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Lists are viewable by owner" ON lists;

