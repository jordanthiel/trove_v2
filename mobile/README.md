# Trove iOS

Native SwiftUI gift registry for iPhone and iPad, targeting iOS 17+. No third-party iOS packages are required.

## Run

1. Put the shared project's public anon key and URL in `.env` (see `.env.example`). This checkout is already configured for the hosted shared project.
2. Run `python3 scripts/configure.py`.
3. Open `Trove.xcodeproj`, select the Trove scheme and an iOS simulator, and press Run.

For a physical iPhone, select your Apple development team in Signing & Capabilities. The default bundle ID is `com.jordanthiel.trove-rn`.

The Xcode project is saved. `scripts/generate-project.py` regenerates it when adding source files. `scripts/make-icon.swift` generates the vector-drawn app icon.

## Functionality

Email/password accounts; dated events with server-generated six-character codes; joining by code; wish lists shared across several events; gift items with notes, optional USD prices, product links, and imported photos; atomic purchase claims with undo for the purchaser; and thank-you drafts through the iOS share sheet.

Claims apply across every event sharing the item. List owners cannot read purchase fields, including through the raw API. Claims reveal the day after all linked event dates, in their respective time zones. Each claim preserves its original reveal deadline so removing or shortening an event cannot reveal a surprise early. No thank-you message is sent automatically.

Owned items, lists, and events can be deleted; members can leave events and sign out.

## Architecture

`SupabaseClient.swift` uses Supabase Auth and PostgREST through URLSession. Tokens live in Keychain and refresh automatically. The ignored `Configuration.plist` bundles only public credentials. `TroveStore.swift` manages data; the other Swift files define models and SwiftUI screens.

Database migrations belong to `../../shared-database`. The app uses hosted project `wcobniubsmvvrggzrkhh`; local shared development uses port 57421. Never bundle service-role keys or reset the shared hosted database.

## Backend tests

With the local shared Supabase stack running and migrations applied:

```sh
python3 Tests/backend_integration.py
```

The test checks Auth, codes, joining, list sharing, claim races, privacy, date reveal, preserved deadlines, and undo. Disposable local accounts and their cascaded data are removed afterward. It refuses hosted URLs.

This mobile directory is an independent local Git repository. No remote has been created or pushed.

## Product links

Pasting a full product URL automatically looks up the title, description, price, and image through the authenticated `product-preview` Edge Function. JSON-LD Product data takes precedence over Open Graph metadata. If a store blocks cloud traffic, an ephemeral, cookie-free device request can load the page for the same authenticated parser. Users can review/edit details, remove the photo, or retry the lookup. A late lookup cannot replace text edited while it was loading. Unsupported/blocked stores fall back to manual entry. Non-USD prices are kept in the notes instead of being mislabeled as USD.

Photos persist in the existing `list_items.image_url` field and appear on wish-list cards. No database migration is required.

Amazon imports read desktop/mobile product titles, feature bullets, the main high-resolution photo, and the current buy-box price. Tracking URLs normalize to the ASIN while retaining variant parameters; short share links follow redirects. The bounded page limit is 6 MB to accommodate Amazon product pages. Challenge pages are rejected instead of importing an Amazon logo or generic title.

Function tests: `deno test --no-config --no-lock ../supabase/functions/product-preview/metadata_test.ts`.

### App Store archives

Marketing version and build number are set in the Xcode target settings (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`); `Info.plist` resolves those values when building. Current release: 1.1.0 (2026100301). Increment the build number for each upload. Both configurations and the project generator use the same values. iPad supports all four orientations for multitasking; iPhone uses portrait.

Create a new archive after changing these values. Existing archives retain their original bundle metadata and cannot be fixed by editing the project afterward.
