#!/bin/bash

# DrillSergeant HabitOS Environment Setup Script
# This script helps you set up the required environment variables

echo "🚀 DrillSergeant HabitOS Environment Setup"
echo "=========================================="
echo ""

# Check if .env already exists
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Setup cancelled."
        exit 1
    fi
fi

# Copy .env.example to .env if it doesn't exist
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✅ Created .env file from .env.example"
    else
        echo "❌ .env.example file not found!"
        exit 1
    fi
fi

echo ""
echo "📝 Next steps:"
echo "1. Edit the .env file with your actual API keys and credentials"
echo "2. Get your API keys from:"
echo "   - OpenAI: https://platform.openai.com/api-keys"
echo "   - ElevenLabs: https://elevenlabs.io/"
echo "   - Firebase: https://console.firebase.google.com/"
echo "   - Stripe: https://dashboard.stripe.com/apikeys"
echo "   - S3: AWS S3, DigitalOcean Spaces, or any S3-compatible service"
echo ""
echo "3. Set up your databases:"
echo "   - PostgreSQL database"
echo "   - Redis instance"
echo ""
echo "4. Test your setup by running:"
echo "   npm run dev"
echo ""
echo "5. Check the startup status at:"
echo "   http://localhost:8080/startup-check"
echo ""
echo "✅ Environment setup complete!"
echo "📖 See ENVIRONMENT_SETUP.md for detailed instructions"