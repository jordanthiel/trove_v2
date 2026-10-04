# Trove setup

The rebuilt app is native SwiftUI in `mobile/`. Open `mobile/Trove.xcodeproj`, select the Trove scheme and an iOS simulator, and press Run. See [mobile/README.md](mobile/README.md) for configuration and tests.

The app is configured for shared hosted Supabase project `wcobniubsmvvrggzrkhh`. Public client credentials live in ignored `mobile/.env`; run `python3 mobile/scripts/configure.py` after changing them. Select your Apple development team in Xcode to run on a physical device.

Migrations are owned by `../shared-database`; `supabase/migrations` links to the canonical history. Run database commands from that repository; do not reset hosted data. Local shared Supabase is at `http://127.0.0.1:57421`.

The product-preview Edge Function automatically imports public product-page metadata and photos. The original AI assistant function remains deployed.
