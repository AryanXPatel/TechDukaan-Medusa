#!/bin/bash

echo "🕵️ Medusa Admin Authentication Debugging Script"
echo "=============================================="

echo "📋 Current Environment Configuration:"
echo "-----------------------------------"
grep -E "(ADMIN_CORS|AUTH_CORS|STORE_CORS|MEDUSA_ADMIN_BACKEND_URL|SESSION.*|CORS.*)" .env.production

echo ""
echo "🐳 Container Environment Variables:"
echo "---------------------------------"
docker-compose -f docker-compose.production.yml exec medusa-server env | grep -E "(ADMIN_CORS|AUTH_CORS|STORE_CORS|MEDUSA_ADMIN_BACKEND_URL|SESSION|CORS)"

echo ""
echo "📊 Container Status:"
echo "-------------------"
docker-compose -f docker-compose.production.yml ps

echo ""
echo "🔗 Network Test:"
echo "---------------"
echo "Testing API endpoint accessibility..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:9000/health || echo "Local connection failed"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://52.237.83.34:9000/health || echo "External connection failed"

echo ""
echo "🍪 Session Test:"
echo "---------------"
echo "Testing auth endpoint with session creation..."
AUTH_RESPONSE=$(curl -s -c cookies.txt -X POST http://52.237.83.34:9000/auth/user/emailpass \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@techdukkan.com","password":"yIne2amI2YBhCk"}' \
  -w "HTTP_STATUS:%{http_code}")

echo "Auth Response: $AUTH_RESPONSE"

if [ -f cookies.txt ]; then
    echo "Cookies saved:"
    cat cookies.txt
    
    echo ""
    echo "Testing admin endpoint with cookies..."
    ADMIN_RESPONSE=$(curl -s -b cookies.txt http://52.237.83.34:9000/admin/users/me -w "HTTP_STATUS:%{http_code}")
    echo "Admin Response: $ADMIN_RESPONSE"
    
    rm -f cookies.txt
else
    echo "No cookies saved - session creation failed"
fi

echo ""
echo "📝 Recent Logs (last 20 lines):"
echo "-------------------------------"
docker-compose -f docker-compose.production.yml logs --tail=20 medusa-server

echo ""
echo "🎯 Debugging Complete!"
echo "====================="
echo ""
echo "If you see 'GET /admin/users/me → 401' in logs, the issue is session persistence."
echo "If you see 'POST /auth/user/emailpass → 200' but 'GET /admin/users/me → 401', it's a CORS/session domain issue."
echo ""
echo "💡 Recommended fixes to try:"
echo "1. Run: ./fix-admin-auth.sh (basic wildcard CORS fix)"
echo "2. Run: ./fix-admin-auth-alternative.sh (comprehensive session/cookie fix)"
echo "3. Check if domain-specific session configuration is needed"
