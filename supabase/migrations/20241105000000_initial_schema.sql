-- Enable UUID extension (pgcrypto is pre-installed on Supabase)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create events table
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  date DATE NOT NULL,
  sharing_code TEXT UNIQUE NOT NULL,
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_over BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create event_members table (junction table for users and events)
CREATE TABLE event_members (
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (event_id, user_id)
);

-- Create lists table
CREATE TABLE lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create event_lists table (junction table for events and lists - many-to-many)
CREATE TABLE event_lists (
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
  PRIMARY KEY (event_id, list_id)
);

-- Create list_items table
CREATE TABLE list_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  link TEXT,
  image_url TEXT,
  purchased_by_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  purchased_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_events_sharing_code ON events(sharing_code);
CREATE INDEX idx_events_owner_id ON events(owner_id);
CREATE INDEX idx_event_members_user_id ON event_members(user_id);
CREATE INDEX idx_event_members_event_id ON event_members(event_id);
CREATE INDEX idx_lists_user_id ON lists(user_id);
CREATE INDEX idx_list_items_list_id ON list_items(list_id);
CREATE INDEX idx_list_items_purchased_by ON list_items(purchased_by_user_id);

-- Function to generate a unique 6-character sharing code
CREATE OR REPLACE FUNCTION generate_sharing_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Exclude similar looking chars
  result TEXT := '';
  i INTEGER;
  code_exists BOOLEAN;
BEGIN
  LOOP
    result := '';
    FOR i IN 1..6 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    
    -- Check if code already exists
    SELECT EXISTS(SELECT 1 FROM events WHERE sharing_code = result) INTO code_exists;
    
    IF NOT code_exists THEN
      EXIT;
    END IF;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user is member of an event (to avoid RLS recursion)
CREATE OR REPLACE FUNCTION is_event_member(p_event_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM event_members 
    WHERE event_id = p_event_id 
    AND user_id = p_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to automatically add event owner as member
CREATE OR REPLACE FUNCTION add_owner_as_member()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO event_members (event_id, user_id)
  VALUES (NEW.id, NEW.owner_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to add event owner as member
CREATE TRIGGER trigger_add_owner_as_member
AFTER INSERT ON events
FOR EACH ROW
EXECUTE FUNCTION add_owner_as_member();

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- RLS Policies for events
CREATE POLICY "Events are viewable by members or owners"
  ON events FOR SELECT
  USING (
    -- Event owners can always see their events
    auth.uid() = owner_id
    OR
    -- Users can see events they're members of
    -- Using SECURITY DEFINER function to avoid recursion
    is_event_member(id, auth.uid())
  );

CREATE POLICY "Users can create events"
  ON events FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Event owners can update their events"
  ON events FOR UPDATE
  USING (auth.uid() = owner_id);

CREATE POLICY "Event owners can delete their events"
  ON events FOR DELETE
  USING (auth.uid() = owner_id);

-- RLS Policies for event_members
CREATE POLICY "Event members are viewable by members of same event"
  ON event_members FOR SELECT
  USING (
    -- Users can see members of events they belong to
    -- Using SECURITY DEFINER function to avoid recursion
    is_event_member(event_id, auth.uid())
  );

CREATE POLICY "Users can join events"
  ON event_members FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave events"
  ON event_members FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for lists
CREATE POLICY "Lists are viewable by owner"
  ON lists FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own lists"
  ON lists FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own lists"
  ON lists FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own lists"
  ON lists FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for event_lists
CREATE POLICY "Event lists are viewable by event members"
  ON event_lists FOR SELECT
  USING (
    -- Users can see lists for events they're members of
    is_event_member(event_id, auth.uid())
  );

CREATE POLICY "List owners can assign their lists to events they're members of"
  ON event_lists FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM lists 
      WHERE lists.id = event_lists.list_id 
      AND lists.user_id = auth.uid()
    )
    AND
    is_event_member(event_id, auth.uid())
  );

CREATE POLICY "List owners can remove their lists from events"
  ON event_lists FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM lists 
      WHERE lists.id = event_lists.list_id 
      AND lists.user_id = auth.uid()
    )
  );

-- RLS Policies for list_items
-- Complex visibility rules based on ownership and event status
CREATE POLICY "List items are viewable with privacy rules"
  ON list_items FOR SELECT
  USING (
    -- List owner can always see their items
    EXISTS (
      SELECT 1 FROM lists 
      WHERE lists.id = list_items.list_id 
      AND lists.user_id = auth.uid()
    )
    OR
    -- Event members can see items from lists in their events
    EXISTS (
      SELECT 1 FROM event_lists
      WHERE event_lists.list_id = list_items.list_id
      AND is_event_member(event_lists.event_id, auth.uid())
    )
  );

CREATE POLICY "List owners can add items to their lists"
  ON list_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM lists 
      WHERE lists.id = list_items.list_id 
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "List owners can update their own items"
  ON list_items FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM lists 
      WHERE lists.id = list_items.list_id 
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "List owners can delete their items"
  ON list_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM lists 
      WHERE lists.id = list_items.list_id 
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "Event members can mark items as purchased"
  ON list_items FOR UPDATE
  USING (
    -- User is a member of an event that has this list
    EXISTS (
      SELECT 1 FROM event_lists
      WHERE event_lists.list_id = list_items.list_id
      AND is_event_member(event_lists.event_id, auth.uid())
    )
    -- And user is not the list owner
    AND NOT EXISTS (
      SELECT 1 FROM lists 
      WHERE lists.id = list_items.list_id 
      AND lists.user_id = auth.uid()
    )
  )
  WITH CHECK (
    -- User is a member of an event that has this list
    EXISTS (
      SELECT 1 FROM event_lists
      WHERE event_lists.list_id = list_items.list_id
      AND is_event_member(event_lists.event_id, auth.uid())
    )
    -- And user is not the list owner
    AND NOT EXISTS (
      SELECT 1 FROM lists 
      WHERE lists.id = list_items.list_id 
      AND lists.user_id = auth.uid()
    )
  );

-- Create a view for items with privacy-filtered purchase information
-- This view hides purchaser info from list owners until the event is over
CREATE OR REPLACE VIEW list_items_with_privacy AS
SELECT 
  li.id,
  li.list_id,
  li.name,
  li.description,
  li.link,
  li.image_url,
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

