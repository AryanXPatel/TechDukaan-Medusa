#!/bin/bash

echo "🔧 Alternative Fix: Adding CORS Credentials and Session Domain Settings..."

# Backup current .env.production
cp .env.production .env.production.backup

# Add additional environment variables for external domain session handling
cat >> .env.production << EOF

# Additional session configuration for external domain access
CORS_CREDENTIALS=true
SESSION_COOKIE_SECURE=false
SESSION_COOKIE_SAMESITE=lax
SESSION_COOKIE_HTTPONLY=true
SESSION_COOKIE_DOMAIN=52.237.83.34
EOF

echo "✅ Added additional session/cookie configuration"

# Restart container
echo "🔄 Restarting container..."
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d

echo "⏳ Waiting for services..."
sleep 15

# Test the configuration
echo "🧪 Testing configuration..."
echo "Check logs: docker-compose -f docker-compose.production.yml logs -f medusa-server"
echo "Test login: http://52.237.83.34:9000/app"

echo "✨ Alternative fix applied!"
