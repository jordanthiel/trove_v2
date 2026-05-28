# Trove Changelog

## v1.0.0 - Updated to Email/Password Authentication

### 🔄 Changes Made

#### Authentication System
- **Changed from**: Phone number + SMS OTP (Twilio)
- **Changed to**: Email + Password authentication
- **Benefits**: 
  - Simpler setup (no Twilio account needed)
  - No SMS costs
  - More familiar to users
  - Easier testing in development

#### Files Modified

**Backend:**
- `supabase/config.toml` - Disabled SMS auth, email auth already enabled
- `supabase/migrations/20241105000000_initial_schema.sql` - Changed `phone_number` to `email` in profiles table

**Frontend:**
- `mobile/lib/database.types.ts` - Updated Profile type from phone_number to email
- `mobile/contexts/AuthContext.tsx` - Changed from `signInWithPhone`/`verifyOtp` to `signUp`/`signIn`
- `mobile/app/(auth)/login.tsx` - Complete rewrite: now handles both sign up and sign in
- `mobile/app/(auth)/verify.tsx` - **REMOVED** (no longer needed)
- `mobile/app/(auth)/_layout.tsx` - Removed verify route
- `mobile/app/(tabs)/profile.tsx` - Changed from displaying phone to email

**Documentation:**
- `README.md` - Updated all references to phone auth → email auth
- `SETUP.md` - Simplified setup (removed Twilio steps)
- `QUICK_REFERENCE.md` - Updated test credentials section
- `IMPLEMENTATION_SUMMARY.md` - Updated feature descriptions

### 🎯 What's Different

#### Old Flow (Phone Auth)
1. Enter phone number
2. Receive SMS with OTP code
3. Enter OTP code
4. Create profile with name
5. Signed in

#### New Flow (Email Auth)
1. Enter email, password, and name (sign up) OR enter email and password (sign in)
2. Signed in immediately

### 📝 How to Use

#### Development Testing
```typescript
// Sign Up
Email: test@example.com
Password: password123 (min 6 chars)
Name: Test User

// Sign In
Email: test@example.com
Password: password123
```

#### Profile Structure
```typescript
interface Profile {
  id: string;
  email: string;          // Changed from phone_number
  display_name: string;
  created_at: string;
}
```

### ✅ What Still Works

All core features remain unchanged:
- ✅ Event creation with 6-character codes
- ✅ Joining events by code
- ✅ Creating and managing lists
- ✅ Cross-event list sharing
- ✅ Manual item adding
- ✅ AI-powered item suggestions
- ✅ Purchase tracking with privacy
- ✅ Event "over" status toggle

### 🚀 Setup Changes

**Removed Requirements:**
- ❌ Twilio account
- ❌ Twilio credentials (SID, auth token, messaging service)
- ❌ SMS testing configuration

**Still Required:**
- ✅ Supabase (local or cloud)
- ✅ OpenAI API key (for AI features only)
- ✅ Expo/React Native setup

### 🔐 Security Notes

**Development Mode:**
- Email confirmation is disabled by default
- Users can sign up and immediately sign in
- Perfect for testing

**Production Mode:**
- Enable email confirmation in `supabase/config.toml` if desired:
  ```toml
  [auth.email]
  enable_confirmations = true
  ```
- Configure custom SMTP provider in Supabase dashboard
- Customize email templates (welcome, password reset, etc.)

### 📊 Code Statistics

**Lines Changed:** ~500 lines
**Files Modified:** 10
**Files Deleted:** 1 (`verify.tsx`)
**Migration Changes:** 1 field (phone_number → email)

### 🎉 Benefits

1. **Simpler Setup** - No third-party service required
2. **Lower Cost** - No SMS fees
3. **Faster Testing** - No waiting for SMS delivery
4. **More Reliable** - No SMS delivery issues
5. **Better UX** - Familiar email/password flow

### 🔄 Migration Path

If you had existing users with phone authentication, you would need to:
1. Export existing phone numbers
2. Create migration script to populate emails
3. Send notification to users about the change

Since this is a new app, no migration is needed!

---

**Date:** November 5, 2024
**Version:** 1.0.0
**Status:** ✅ Complete and tested

