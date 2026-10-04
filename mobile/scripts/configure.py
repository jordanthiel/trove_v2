#!/usr/bin/env python3
"""Write only public app connection details to an ignored bundled plist."""
from pathlib import Path
import plistlib
root = Path(__file__).resolve().parents[1]
values = dict(line.split('=', 1) for line in (root / '.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
url = values.get('EXPO_PUBLIC_SUPABASE_URL', '')
key = values.get('EXPO_PUBLIC_SUPABASE_ANON_KEY', '')
if not url or not key:
    raise SystemExit('Set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY in mobile/.env')
# Never bundle server secrets.
if key.startswith('sb_secret_'):
    raise SystemExit('A server secret cannot be used in an iOS app')
if key.count('.') == 2:
    import base64, json
    payload = json.loads(base64.urlsafe_b64decode(key.split('.')[1] + '=='))
    if payload.get('role') != 'anon':
        raise SystemExit('Only the anon JWT is permitted in the app')
with (root / 'Trove' / 'Configuration.plist').open('wb') as f:
    plistlib.dump({'SupabaseURL': url, 'SupabaseAnonKey': key}, f)
print('Configured Trove with public credentials for ' + url)
