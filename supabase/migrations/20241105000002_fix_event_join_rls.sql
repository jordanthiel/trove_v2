-- Fix RLS policy to allow joining events by sharing code
-- The issue: users can't view events to join them because they're not members yet

-- Create a secure function to join an event by sharing code
-- This function bypasses RLS using SECURITY DEFINER
CREATE OR REPLACE FUNCTION join_event_by_code(p_sharing_code TEXT, p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_event events%ROWTYPE;
  v_already_member BOOLEAN;
BEGIN
  -- Find the event by sharing code (bypasses RLS because SECURITY DEFINER)
  SELECT * INTO v_event
  FROM events
  WHERE sharing_code = UPPER(TRIM(p_sharing_code));
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Event not found. Please check the code.'
    );
  END IF;
  
  -- Check if user is already a member
  SELECT EXISTS(
    SELECT 1 FROM event_members 
    WHERE event_id = v_event.id 
    AND user_id = p_user_id
  ) INTO v_already_member;
  
  IF v_already_member THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Already a member',
      'event_id', v_event.id,
      'event_name', v_event.name
    );
  END IF;
  
  -- Add user as member
  INSERT INTO event_members (event_id, user_id)
  VALUES (v_event.id, p_user_id);
  
  -- Return success with event details
  RETURN json_build_object(
    'success', true,
    'event_id', v_event.id,
    'event_name', v_event.name,
    'event_date', v_event.date
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

