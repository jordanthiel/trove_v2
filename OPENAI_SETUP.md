# OpenAI API Key Setup for Trove

## 🔑 Setting Up Your OpenAI Key Locally

### Step 1: Create Environment File

In your terminal:

```bash
cd /Users/jordan/projects/trove_v2/supabase
touch .env
```

Or create the file manually in your editor at:
`/Users/jordan/projects/trove_v2/supabase/.env`

### Step 2: Add Your API Key

Edit the `.env` file and add:

```env
OPENAI_API_KEY=sk-proj-YOUR-ACTUAL-KEY-HERE
```

Replace `sk-proj-YOUR-ACTUAL-KEY-HERE` with your actual OpenAI project key.

### Step 3: Restart Supabase

```bash
cd /Users/jordan/projects/trove_v2/supabase
supabase stop
supabase start
```

### Step 4: Test It!

1. Open the Trove app
2. Create a list
3. Open the list
4. Tap the orange sparkle button (AI)
5. Try chatting or...
6. Tap the regular + button
7. Paste a product link (e.g., from Amazon)
8. Watch it auto-fill! 🎉

## 🧪 Verify Environment Variable is Loaded

After starting Supabase, check the logs:

```bash
cd /Users/jordan/projects/trove_v2/supabase
supabase functions logs add-item-with-ai --follow
```

Then trigger the function from the app. You should NOT see "OpenAI API key not configured" errors.

## ❗ Common Issues

### "Incorrect API key" Error

**Causes:**
1. **No billing set up** - Go to https://platform.openai.com/settings/organization/billing
2. **Key needs to be regenerated** - Old keys may be invalid
3. **Free tier exceeded** - OpenAI requires paid usage for GPT-3.5-turbo API

**Solution:**
- Ensure billing is set up with a payment method
- Make sure you have credits or auto-recharge enabled
- Try regenerating the key

### Environment Variable Not Loading

**Check:**
```bash
# Make sure .env file exists
ls -la /Users/jordan/projects/trove_v2/supabase/.env

# Make sure Supabase is using it
cd /Users/jordan/projects/trove_v2/supabase
supabase stop
supabase start
```

The key should be loaded when Supabase starts.

### Key Works in curl But Not in App

This means the environment variable isn't being passed to the edge function. Make sure:
- ✅ File is named `.env` (not `.env.local` or anything else)
- ✅ File is in the `supabase/` directory (not `mobile/`)
- ✅ Supabase was restarted after creating the file
- ✅ No typos in the environment variable name (`OPENAI_API_KEY`)

## 🔐 Security Note

The `.env` file is already in `.gitignore` - it won't be committed to version control. Your key stays private!

## 📝 For Production

When deploying to Supabase Cloud:

```bash
# Link your project
supabase link --project-ref your-project-ref

# Set the secret
supabase secrets set OPENAI_API_KEY=sk-proj-your-key

# Deploy the function
supabase functions deploy add-item-with-ai
```

---

**Quick Test Command:**

```bash
curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/add-item-with-ai' \
  --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
  --header 'Content-Type: application/json' \
  --data '{"message":"I want wireless headphones"}'
```

If this works, your setup is correct! 🎉

