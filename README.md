# Trove

A native iOS gift registry built with SwiftUI and the existing shared Supabase backend.

Create an event, share its six-character code, and invite friends and family to join. Everyone can create wish lists and reuse them across multiple events. Other members can mark gifts as purchased to avoid duplicates, while the list owner gets to keep the surprise.

Purchase details are protected on the server and reveal after the last linked event date has passed. The Thank you tab then shows the gift giver and helps draft a thank-you message.

## Run

Open `mobile/Trove.xcodeproj` in Xcode, choose the Trove scheme and an iOS simulator, and run. The app is configured for the shared hosted Supabase project. See [mobile/README.md](mobile/README.md) for configuration, signing, and tests.

## Layout

- `mobile/`: independent native iOS repository with SwiftUI sources and Xcode project.
- `supabase/migrations`: symlink to the canonical history in `../shared-database`.
- `supabase/functions/add-item-with-ai`: retained deployed AI function; the native app supports manual entry and automatic product-link import.

The missing Expo mobile source has been rebuilt in place as a native iOS app.

## Backend

Shared hosted project: `wcobniubsmvvrggzrkhh`. Core tables: `profiles`, `events`, `event_members`, `lists`, `event_lists`, and `list_items`.

List owners cannot query raw purchase fields. The claim RPC serializes competing purchases. Original reveal deadlines persist even if events are removed or shortened. Public app credentials and Keychain tokens stay out of Git; no server key is bundled.
