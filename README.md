# Trove - Gift Registry Mobile App

A mobile gift registry application for holidays and special occasions. Create events, share wish lists, and coordinate gift giving with family and friends.

## Features

- 🔐 **Email Authentication** - Sign in with email and password
- 🎉 **Event Management** - Create holiday events with shareable 6-character codes
- 📝 **Wish Lists** - Create and manage gift wish lists
- 🔄 **Cross-Event Sharing** - Share the same list across multiple events
- 🎁 **Gift Tracking** - Claim gifts with privacy controls
- 🤖 **AI-Powered Suggestions** - Chat with AI to help describe and add gift items
- 🔒 **Privacy Controls** - List owners can't see who purchased items until event ends

## Tech Stack

- **Frontend**: Expo (React Native) with TypeScript
- **Backend**: Supabase (PostgreSQL + Auth + Edge Functions)
- **AI**: GPT-3.5-turbo via Supabase Edge Functions
- **Authentication**: Email and password

## Project Structure

```
trove_v2/
├── mobile/                    # Expo React Native app
│   ├── app/                   # App screens (Expo Router)
│   │   ├── (auth)/           # Authentication screens
│   │   ├── (tabs)/           # Main tab screens
│   │   ├── events/           # Event management
│   │   ├── lists/            # List management
│   │   └── items/            # Item management
│   ├── components/           # Reusable components
│   ├── contexts/             # React contexts (Auth)
│   ├── lib/                  # Utilities (Supabase client)
│   └── package.json
└── supabase/
    ├── migrations/           # Database migrations
    ├── functions/            # Edge functions
    └── config.toml           # Supabase configuration
```

## Setup Instructions

### Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- Expo CLI
- Supabase CLI
- OpenAI API key (for AI features)

### 1. Clone and Install Dependencies

```bash
cd mobile
npm install
```

### 2. Set Up Supabase

#### Local Development

```bash
# Initialize Supabase (if not already done)
cd ../supabase
supabase start

# The command will output:
# - API URL (use for EXPO_PUBLIC_SUPABASE_URL)
# - anon key (use for EXPO_PUBLIC_SUPABASE_ANON_KEY)
```

#### Run Migrations

```bash
# Migrations are automatically applied when running supabase start
# To manually apply:
supabase db reset
```

### 3. Configure Environment Variables

Create `mobile/.env`:

```env
# For local development
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_ANON_KEY=your_local_anon_key

# For production
# EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
# EXPO_PUBLIC_SUPABASE_ANON_KEY=your_production_anon_key
```

Create `.env` in the supabase directory (for edge functions):

```env
OPENAI_API_KEY=your_openai_api_key
```

### 4. Deploy Edge Functions

```bash
# Deploy the AI function
supabase functions deploy add-item-with-ai --no-verify-jwt

# Set the OpenAI API key secret
supabase secrets set OPENAI_API_KEY=your_openai_api_key
```

### 5. Run the Mobile App

```bash
cd mobile

# Start Expo
npm start

# Run on iOS
npm run ios

# Run on Android
npm run android
```

## Database Schema

### Core Tables

- **profiles** - User profiles with email and display names
- **events** - Holiday/occasion events with sharing codes
- **event_members** - Junction table for users in events
- **lists** - User wish lists
- **event_lists** - Junction table for lists shared across events
- **list_items** - Gift items in lists with purchase tracking

### Key Features

- **Row Level Security (RLS)** - All tables have RLS policies
- **Privacy View** - `list_items_with_privacy` view hides purchaser info from list owners until event ends
- **Auto-generated Codes** - `generate_sharing_code()` function creates unique 6-character event codes

## Usage Flow

### For Event Organizers

1. Sign up or sign in with email and password
2. Create an event with name and date
3. Share the 6-character code with family/friends
4. Create your wish list and assign it to the event
5. Add items manually or with AI assistance
6. Mark event as "over" when the day comes to reveal gift givers

### For Gift Givers

1. Sign up or sign in with email and password
2. Join event using the shared code
3. Browse wish lists from all event members
4. Claim items you plan to purchase
5. List owners won't see who claimed what until event ends

## Privacy Features

- **Before Event Ends**: List owners see if items are claimed but NOT by whom
- **Before Event Ends**: Other members CAN see who claimed what (to avoid duplicates)
- **After Event Ends**: List owners can see who gave them what (for thank-you cards)

## Development Tips

### Testing Authentication Locally

For development, email confirmation is disabled by default. You can sign up and immediately sign in with any email/password combination.

### Debugging Edge Functions

```bash
# View edge function logs
supabase functions serve add-item-with-ai

# Test locally
curl -i --location --request POST 'http://localhost:54321/functions/v1/add-item-with-ai' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"message":"I want wireless headphones"}'
```

### Database Management

```bash
# View database in browser
supabase db studio

# Generate TypeScript types
supabase gen types typescript --local > mobile/lib/database.types.ts
```

## Troubleshooting

### Authentication Issues

- Verify email confirmation is disabled in development: `supabase/config.toml` → `enable_confirmations = false`
- Check password meets minimum requirements (6 characters)
- Clear app data and try again

### Edge Function Fails

- Check OpenAI API key is set: `supabase secrets list`
- View function logs: `supabase functions logs add-item-with-ai`
- Verify function is deployed: `supabase functions list`

### Database Errors

- Ensure migrations have run: `supabase db reset`
- Check RLS policies: `supabase db studio` → Policies tab
- View logs: `supabase logs`

## Production Deployment

### Deploy to Supabase Cloud

1. Create a project at [supabase.com](https://supabase.com)
2. Configure email settings in Supabase dashboard if you want email confirmation
3. Link your project:
   ```bash
   supabase link --project-ref your-project-ref
   ```
4. Push migrations:
   ```bash
   supabase db push
   ```
5. Deploy functions:
   ```bash
   supabase functions deploy add-item-with-ai
   supabase secrets set OPENAI_API_KEY=your_key
   ```
6. Update `mobile/.env` with production URLs

### Build Mobile App

```bash
# Build for iOS
eas build --platform ios

# Build for Android
eas build --platform android
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License - feel free to use this for your own projects!

## Support

For issues or questions, please open an issue on GitHub.

