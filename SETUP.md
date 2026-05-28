# Quick Setup Guide for Trove

This guide will get you up and running with Trove in under 10 minutes.

## Step 1: Install Dependencies

```bash
cd mobile
npm install
```

## Step 2: Start Supabase

```bash
cd ../supabase
supabase start
```

**Important**: Copy the output values:
- `API URL` → Use for EXPO_PUBLIC_SUPABASE_URL
- `anon key` → Use for EXPO_PUBLIC_SUPABASE_ANON_KEY

## Step 3: Configure Environment

Create `mobile/.env`:

```env
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
```

## Step 4: Deploy Edge Function (Optional - for AI features)

Get an OpenAI API key from https://platform.openai.com

```bash
# Deploy function
cd ../supabase
supabase functions deploy add-item-with-ai --no-verify-jwt

# Set OpenAI key
supabase secrets set OPENAI_API_KEY=your_openai_api_key_here
```

## Step 5: Run the App

```bash
cd ../mobile
npm start
```

Press:
- `i` for iOS simulator
- `a` for Android emulator
- Scan QR code for physical device

## Testing the App

### Sign Up
1. Click "Don't have an account? Sign Up"
2. Enter your name, email, and password (min 6 characters)
3. Click "Sign Up"
4. Then sign in with your email and password

### Create an Event
1. Go to Events tab
2. Tap the blue `+` button
3. Enter event name and date
4. Note the 6-character sharing code

### Create a List
1. Go to Lists tab
2. Tap the `+` button
3. Enter list name
4. Open the list
5. Toggle events to share it with

### Add Items
- **Manual**: Tap the blue `+` button
- **AI**: Tap the orange sparkle button (requires OpenAI setup)

### Join as Another User
1. Sign out from Profile tab
2. Sign up with a different email and password
3. Go to Events tab
4. Tap the green join button
5. Enter the sharing code from earlier
6. Browse lists and claim items

## Production Setup

For production deployment:

1. **Configure Email** (optional):
   - In Supabase dashboard, go to Authentication → Email Templates
   - Customize confirmation and password reset emails
   - Enable email confirmation if desired in `supabase/config.toml`:
     ```toml
     [auth.email]
     enable_confirmations = true
     ```

2. **Set up custom SMTP** (optional):
   - By default, Supabase handles email sending
   - For production, configure your own SMTP in Supabase dashboard

## Common Issues

### "Can't connect to Supabase"
- Make sure Supabase is running: `supabase status`
- Check .env file has correct URL and key

### "Authentication not working"
- Make sure email confirmation is disabled for development
- Check password is at least 6 characters
- Verify email format is valid

### "AI not working"
- Check edge function is deployed: `supabase functions list`
- Verify OpenAI key: `supabase secrets list`
- Check function logs: `supabase functions logs add-item-with-ai`

### "Database errors"
- Reset database: `supabase db reset`
- Check migrations ran: Look for files in supabase/migrations

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Customize the app colors and branding
- Add more features like notifications or image uploads
- Deploy to production with Supabase Cloud

## Getting Help

- Check [Supabase docs](https://supabase.com/docs)
- Check [Expo docs](https://docs.expo.dev)
- Open an issue on GitHub

Happy coding! 🎁

