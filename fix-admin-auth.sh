#!/bin/bash

echo "🔧 Fixing Medusa Admin Authentication for Azure VM..."

# Update .env.production with proper configuration
echo "📝 Updating .env.production with wildcard CORS and session settings..."

# Ensure ADMIN_CORS is set to wildcard
sed -i 's/^ADMIN_CORS=.*/ADMIN_CORS=*/' .env.production

# Add session configuration if not exists
if ! grep -q "SESSION_SECRET" .env.production; then
    echo "SESSION_SECRET=eb57634bf9dd7338a655b17adf17c156" >> .env.production
fi

if ! grep -q "MEDUSA_ADMIN_BACKEND_URL" .env.production; then
    echo "MEDUSA_ADMIN_BACKEND_URL=http://52.237.83.34:9000" >> .env.production
fi

echo "✅ Configuration updated:"
echo "   - ADMIN_CORS=* (wildcard for external access)"
echo "   - SESSION_SECRET configured"
echo "   - MEDUSA_ADMIN_BACKEND_URL set to Azure VM IP"

# Restart the container to apply changes
echo "🔄 Restarting Medusa container..."
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d

echo "⏳ Waiting for services to start..."
sleep 10

# Check container status
echo "📊 Container Status:"
docker-compose -f docker-compose.production.yml ps

# Verify environment variables are loaded
echo "🔍 Verifying ADMIN_CORS configuration in container:"
docker-compose -f docker-compose.production.yml exec medusa-server env | grep ADMIN_CORS

echo "🧪 Testing admin authentication..."
echo "   1. Go to: http://52.237.83.34:9000/app"
echo "   2. Login with: admin@techdukkan.com / yIne2amI2YBhCk"
echo "   3. Monitor logs: docker-compose -f docker-compose.production.yml logs -f medusa-server"
echo ""
echo "🎯 Success indicators:"
echo "   - POST /auth/user/emailpass → 200"
echo "   - POST /auth/session → 200"
echo "   - GET /admin/users/me → 200 (NOT 401)"

echo "✨ Fix applied! Test admin login now."
