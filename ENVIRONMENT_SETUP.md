# Environment Setup Guide

This guide will help you set up the required environment variables for the DrillSergeant HabitOS application.

## Required Environment Variables

The application requires the following environment variables to be set:

### Database Configuration
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string

### AI Services
- `OPENAI_API_KEY`: Your OpenAI API key
- `OPENAI_MODEL`: OpenAI model to use (e.g., "gpt-4")
- `ELEVENLABS_API_KEY`: Your ElevenLabs API key
- `ELEVENLABS_VOICE_MARCUS`: ElevenLabs voice ID for Marcus Aurelius
- `ELEVENLABS_VOICE_DRILL`: ElevenLabs voice ID for Drill Sergeant
- `ELEVENLABS_VOICE_CONFUCIUS`: ElevenLabs voice ID for Confucius
- `ELEVENLABS_VOICE_LINCOLN`: ElevenLabs voice ID for Abraham Lincoln
- `ELEVENLABS_VOICE_BUDDHA`: ElevenLabs voice ID for Buddha

### Firebase Configuration
- `FIREBASE_PROJECT_ID`: Your Firebase project ID
- `FIREBASE_CLIENT_EMAIL`: Firebase service account email
- `FIREBASE_PRIVATE_KEY`: Firebase service account private key

### Payment Processing
- `STRIPE_SECRET_KEY`: Your Stripe secret key
- `STRIPE_WEBHOOK_SECRET`: Stripe webhook secret

### File Storage
- `S3_ENDPOINT`: S3-compatible storage endpoint
- `S3_BUCKET`: S3 bucket name
- `S3_ACCESS_KEY`: S3 access key
- `S3_SECRET_KEY`: S3 secret key

### Server Configuration
- `PORT`: Server port (default: 8080)
- `HOST`: Server host (default: 0.0.0.0)
- `BACKEND_PUBLIC_URL`: Public URL for the backend
- `NODE_ENV`: Environment (development/production)

## Setup Instructions

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the .env file** with your actual values:
   ```bash
   nano .env
   ```

3. **Get your API keys:**

   **OpenAI:**
   - Visit [OpenAI Platform](https://platform.openai.com/api-keys)
   - Create a new API key
   - Set `OPENAI_API_KEY` to your key

   **ElevenLabs:**
   - Visit [ElevenLabs](https://elevenlabs.io/)
   - Get your API key from the profile page
   - Get voice IDs from the voices page
   - Set `ELEVENLABS_API_KEY` and voice IDs

   **Firebase:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings > Service Accounts
   - Generate a new private key
   - Set the Firebase variables

   **Stripe:**
   - Visit [Stripe Dashboard](https://dashboard.stripe.com/)
   - Get your secret key from API keys
   - Set up webhooks and get the webhook secret
   - Set the Stripe variables

   **S3 Storage:**
   - Use AWS S3, DigitalOcean Spaces, or any S3-compatible service
   - Create a bucket and get access credentials
   - Set the S3 variables

4. **Database Setup:**
   - Set up PostgreSQL database
   - Set up Redis instance
   - Update `DATABASE_URL` and `REDIS_URL`

## Development vs Production

- **Development**: Use test API keys and local databases
- **Production**: Use production API keys and hosted databases

## Security Notes

- Never commit your `.env` file to version control
- Use different API keys for development and production
- Rotate your API keys regularly
- Use environment-specific configuration files

## Troubleshooting

If you're still getting missing environment variable errors:

1. Check that your `.env` file is in the project root
2. Verify all required variables are set
3. Restart your development server
4. Check for typos in variable names
5. Ensure no extra spaces around the `=` sign

## Testing Your Setup

Run the startup check to verify all services are working:

```bash
curl http://localhost:8080/startup-check
```

This will test all your API connections and return the status of each service.