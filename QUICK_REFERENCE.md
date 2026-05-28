# Trove - Quick Reference Guide

## 🚀 Common Commands

### Starting Development

```bash
# Terminal 1: Start Supabase
cd supabase
supabase start

# Terminal 2: Start Mobile App
cd mobile
npm start
```

### Database Commands

```bash
# Reset database (re-run migrations)
supabase db reset

# View database in browser
supabase db studio

# Generate TypeScript types
supabase gen types typescript --local > mobile/lib/database.types.ts

# Check Supabase status
supabase status

# View logs
supabase logs
```

### Edge Function Commands

```bash
# Deploy function
supabase functions deploy add-item-with-ai --no-verify-jwt

# Serve locally
supabase functions serve add-item-with-ai

# View function logs
supabase functions logs add-item-with-ai

# List all functions
supabase functions list

# Set secrets
supabase secrets set OPENAI_API_KEY=your_key

# List secrets
supabase secrets list
```

### Mobile App Commands

```bash
# Start development server
npm start

# Run on iOS
npm run ios
# or press 'i' in the terminal

# Run on Android
npm run android
# or press 'a' in the terminal

# Clear cache
npm start --clear

# Install dependencies
npm install
```

## 🧪 Test Credentials (Development)

### Email Authentication
- Use any valid email format (e.g., `test@example.com`)
- Password must be at least 6 characters
- No email confirmation required in development mode

## 📁 Important File Locations

### Configuration
- Mobile environment: `mobile/.env`
- Supabase config: `supabase/config.toml`
- App config: `mobile/app.json`

### Database
- Migrations: `supabase/migrations/`
- Functions: `supabase/functions/`

### Mobile App
- Screens: `mobile/app/`
- Components: `mobile/components/`
- Contexts: `mobile/contexts/`
- Supabase client: `mobile/lib/supabase.ts`

## 🔧 Troubleshooting Quick Fixes

### "Can't connect to Supabase"
```bash
cd supabase
supabase status
# If not running:
supabase start
```

### "Email auth not working"
Check email confirmation is disabled for development in `supabase/config.toml`:
```toml
[auth.email]
enable_confirmations = false
```
Password must be at least 6 characters.

### "Edge function not working"
```bash
# Check if deployed
supabase functions list

# Check logs
supabase functions logs add-item-with-ai

# Verify OpenAI key
supabase secrets list
```

### "Database migration failed"
```bash
# Reset everything
supabase db reset

# If issues persist, check migration file syntax
```

### "Mobile app won't start"
```bash
cd mobile
# Clear cache and reinstall
rm -rf node_modules
npm install
npm start --clear
```

## 🌐 Environment Variables Reference

### Mobile App (.env)

**Local Development:**
```env
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_ANON_KEY=your_local_anon_key
```

**Production:**
```env
EXPO_PUBLIC_SUPABASE_URL=https://yourproject.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your_production_anon_key
```

### Supabase Secrets

```bash
# Set via CLI
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set TWILIO_ACCOUNT_SID=AC...
supabase secrets set TWILIO_AUTH_TOKEN=...
supabase secrets set TWILIO_MESSAGE_SERVICE_SID=MG...
```

## 📱 App Navigation Structure

```
Auth Flow
├── Login (phone entry)
└── Verify (OTP + profile creation)

Main App (Tabs)
├── Events
│   ├── Create Event (modal)
│   ├── Join Event (modal)
│   └── Event Detail
│       └── View Lists
├── Lists
│   ├── Create List (modal)
│   └── List Detail
│       ├── Assign to Events
│       ├── Add Item Manual (modal)
│       ├── Add Item AI (modal)
│       └── Item Detail
└── Profile
    └── Sign Out
```

## 🗄️ Database Quick Reference

### Tables
- `profiles` - User information
- `events` - Holiday events
- `event_members` - Who's in which event
- `lists` - User wish lists
- `event_lists` - Lists assigned to events
- `list_items` - Gift items

### Important Queries

**Get user's events:**
```sql
SELECT e.* FROM events e
JOIN event_members em ON em.event_id = e.id
WHERE em.user_id = 'user-uuid';
```

**Get lists for an event:**
```sql
SELECT l.* FROM lists l
JOIN event_lists el ON el.list_id = l.id
WHERE el.event_id = 'event-uuid';
```

**Get items with privacy:**
```sql
SELECT * FROM list_items_with_privacy
WHERE list_id = 'list-uuid';
```

## 🔑 Useful URLs (Local Development)

- **Supabase Studio**: http://localhost:54323
- **API URL**: http://localhost:54321
- **Inbucket (Email testing)**: http://localhost:54324
- **Edge Functions**: http://localhost:54321/functions/v1/

## 📞 Support Resources

- **Supabase Docs**: https://supabase.com/docs
- **Expo Docs**: https://docs.expo.dev
- **React Native Docs**: https://reactnative.dev
- **Expo Router Docs**: https://expo.github.io/router/docs

## 🎯 Common Development Tasks

### Add a new screen
1. Create file in `mobile/app/` directory
2. Use TypeScript + React
3. Import and use Supabase client
4. Add navigation as needed

### Add a new database table
1. Create migration file in `supabase/migrations/`
2. Add table definition with RLS
3. Run `supabase db reset`
4. Update TypeScript types

### Modify an existing table
1. Create new migration file (don't edit old ones)
2. Use ALTER TABLE statements
3. Run `supabase db reset`
4. Update TypeScript types

### Deploy updates
```bash
# Deploy database changes
supabase db push

# Deploy function changes
supabase functions deploy function-name

# Rebuild mobile app
eas build --platform all
```

## 💡 Pro Tips

1. **Always use the privacy view** for list items to respect privacy rules
2. **Use RLS policies** instead of manual permission checks
3. **Test with multiple users** using different test phone numbers
4. **Check Supabase Studio** for debugging database issues
5. **Use pull-to-refresh** instead of auto-polling to save resources
6. **Keep migrations immutable** - always create new ones for changes
7. **Use TypeScript types** from generated database types
8. **Test the full flow** from both owner and member perspectives

## 🚢 Pre-Deployment Checklist

- [ ] Test all features work locally
- [ ] Set up Twilio account and get credentials
- [ ] Get OpenAI API key
- [ ] Create Supabase Cloud project
- [ ] Deploy database migrations
- [ ] Deploy edge functions with secrets
- [ ] Update mobile .env with production URLs
- [ ] Test production auth flow
- [ ] Build mobile apps
- [ ] Test on physical devices
- [ ] Submit to app stores

---

**Quick Start**: Just run `supabase start` and `npm start` to begin! 🎉

