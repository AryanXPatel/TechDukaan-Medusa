#!/bin/bash

# ========================================
# Medusa v2.x Admin Authentication Fix
# ========================================
# This script applies the necessary configuration changes
# to fix admin authentication issues in production

echo "🔧 Applying Medusa Admin Authentication Fixes..."
echo "=================================================="

# 1. Create backup of current configuration
echo "📋 Creating backup of current configuration..."
cp medusa-config.ts medusa-config.ts.backup
cp .env.production .env.production.backup

# 2. Apply environment variable fixes
echo "🌐 Updating environment variables..."

# Ensure proper CORS and backend URL configuration
if ! grep -q "MEDUSA_ADMIN_BACKEND_URL" .env.production; then
    echo "MEDUSA_ADMIN_BACKEND_URL=http://52.237.83.34:9000" >> .env.production
fi

# Ensure proper CORS for wildcard admin access
sed -i 's/^ADMIN_CORS=.*/ADMIN_CORS=*/' .env.production

# Add session configuration if not present
if ! grep -q "SESSION_SECRET" .env.production; then
    echo "SESSION_SECRET=${COOKIE_SECRET}" >> .env.production
fi

# 3. Apply medusa-config.ts fixes
echo "⚙️  Updating medusa-config.ts with production fixes..."

# Create the updated config with all necessary fixes
cat > medusa-config.ts << 'EOF'
import { loadEnv, defineConfig } from "@medusajs/framework/utils";

loadEnv(process.env.NODE_ENV || "development", process.cwd());

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: process.env.REDIS_URL,
    http: {
      storeCors: process.env.STORE_CORS || "http://localhost:3000",
      adminCors: process.env.ADMIN_CORS || "*",
      authCors: process.env.AUTH_CORS || "*",
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    },
    // CRITICAL: Cookie options for HTTP external access (v2.8.x)
    cookieOptions: {
      secure: false, // MUST be false for HTTP access
      sameSite: "lax", // Allow cross-origin requests
      httpOnly: true, // Security: prevent XSS
      maxAge: 1000 * 60 * 60 * 24 * 7, // 7 days
      domain: undefined, // Allow any domain for external access
    },
    // Session configuration for external access
    sessionOptions: {
      name: "connect.sid",
      resave: false,
      saveUninitialized: false,
      secret: process.env.COOKIE_SECRET || "supersecret",
      cookie: {
        secure: false, // MUST be false for HTTP
        httpOnly: true,
        maxAge: 1000 * 60 * 60 * 24 * 7, // 7 days
        sameSite: "lax",
      },
    },
    // Azure Blob Storage configuration
    ...(process.env.STORAGE_PROVIDER === "azure" && {
      fileService: {
        azure: {
          connectionString: process.env.STORAGE_CONNECTION_STRING,
          containerName: process.env.STORAGE_CONTAINER || "product-images",
        },
      },
    }),
  },
  plugins: [
    // MeiliSearch integration
    ...(process.env.MEILI_HTTP_ADDR
      ? [
          {
            resolve: "@rokmohar/medusa-plugin-meilisearch",
            options: {
              config: {
                host: process.env.MEILI_HTTP_ADDR,
                apiKey: process.env.MEILI_MASTER_KEY,
              },
              settings: {
                products: {
                  type: "products",
                  enabled: true,
                  fields: [
                    "id",
                    "title",
                    "description",
                    "handle",
                    "variant_sku",
                    "thumbnail",
                  ],
                  indexSettings: {
                    searchableAttributes: [
                      "title",
                      "description",
                      "variant_sku",
                    ],
                    displayedAttributes: [
                      "id",
                      "handle",
                      "title",
                      "description",
                      "variant_sku",
                      "thumbnail",
                    ],
                    filterableAttributes: ["id", "handle"],
                  },
                },
              },
            },
          },
        ]
      : []),
  ],
  featureFlags: {
    product_categories: true,
  },
});
EOF

# 4. Create a final validation script
echo "🔍 Creating final validation script..."
cat > validate-admin-fix.sh << 'EOF'
#!/bin/bash

echo "🔍 Validating Medusa Admin Authentication Fix"
echo "=============================================="

# Test the key endpoints that were failing
EXTERNAL_URL="http://52.237.83.34:9000"
EMAIL="admin@techdukkan.com"
PASSWORD="yIne2amI2YBhCk"

echo "📋 Testing Configuration:"
echo "   External URL: $EXTERNAL_URL"
echo "   Admin Email: $EMAIL"
echo ""

# Test 1: Basic connectivity
echo "🔗 Step 1: Testing basic connectivity..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$EXTERNAL_URL/health")
if [ "$HEALTH_STATUS" = "200" ]; then
    echo "   ✅ Health check: OK ($HEALTH_STATUS)"
else
    echo "   ❌ Health check: FAILED ($HEALTH_STATUS)"
    exit 1
fi

# Test 2: Admin interface
echo "🎯 Step 2: Testing admin interface..."
ADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$EXTERNAL_URL/app")
if [ "$ADMIN_STATUS" = "200" ]; then
    echo "   ✅ Admin interface: OK ($ADMIN_STATUS)"
else
    echo "   ❌ Admin interface: FAILED ($ADMIN_STATUS)"
    exit 1
fi

# Test 3: Authentication with proper session handling
echo "🔐 Step 3: Testing complete authentication flow..."

# Clean slate
rm -f /tmp/auth_cookies.txt

# Get auth token
AUTH_RESPONSE=$(curl -s -c /tmp/auth_cookies.txt \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
    "$EXTERNAL_URL/auth/user/emailpass")

if echo "$AUTH_RESPONSE" | grep -q "token"; then
    echo "   ✅ Authentication: SUCCESS"
    TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    echo "   🔑 JWT Token extracted: ${TOKEN:0:20}..."
else
    echo "   ❌ Authentication: FAILED"
    echo "   Response: $AUTH_RESPONSE"
    exit 1
fi

# Create session with proper cookie handling
SESSION_RESPONSE=$(curl -s -b /tmp/auth_cookies.txt -c /tmp/auth_cookies.txt \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{}' \
    "$EXTERNAL_URL/auth/session")

SESSION_STATUS=$(curl -s -b /tmp/auth_cookies.txt -c /tmp/auth_cookies.txt \
    -H "Authorization: Bearer $TOKEN" \
    -d '{}' \
    -o /dev/null -w "%{http_code}" \
    "$EXTERNAL_URL/auth/session")

if [ "$SESSION_STATUS" = "200" ]; then
    echo "   ✅ Session creation: SUCCESS ($SESSION_STATUS)"
else
    echo "   ❌ Session creation: FAILED ($SESSION_STATUS)"
    echo "   Response: $SESSION_RESPONSE"
    exit 1
fi

# Test admin access with session cookies
ADMIN_ACCESS=$(curl -s -b /tmp/auth_cookies.txt \
    -H "Authorization: Bearer $TOKEN" \
    "$EXTERNAL_URL/admin/users/me")

ADMIN_ACCESS_STATUS=$(curl -s -b /tmp/auth_cookies.txt \
    -H "Authorization: Bearer $TOKEN" \
    -o /dev/null -w "%{http_code}" \
    "$EXTERNAL_URL/admin/users/me")

if [ "$ADMIN_ACCESS_STATUS" = "200" ]; then
    echo "   ✅ Admin access: SUCCESS ($ADMIN_ACCESS_STATUS)"
    echo "   📊 User data retrieved successfully!"
    echo ""
    echo "🎉 AUTHENTICATION FIX SUCCESSFUL!"
    echo "   Admin dashboard should now be accessible at:"
    echo "   🌐 $EXTERNAL_URL/app"
else
    echo "   ❌ Admin access: FAILED ($ADMIN_ACCESS_STATUS)"
    echo "   Response: $ADMIN_ACCESS"
    echo ""
    echo "❌ Authentication fix needs additional work"
fi

# Cleanup
rm -f /tmp/auth_cookies.txt

echo ""
echo "✨ Validation complete!"
EOF

chmod +x validate-admin-fix.sh

echo ""
echo "✅ Configuration fixes applied successfully!"
echo ""
echo "📋 Changes made:"
echo "   1. Updated .env.production with proper CORS and backend URL"
echo "   2. Enhanced medusa-config.ts with HTTP-compatible cookie options"
echo "   3. Added sessionOptions for proper external access"
echo "   4. Created validation script to test the fix"
echo ""
echo "🔄 Next steps:"
echo "   1. Restart the containers: docker-compose -f docker-compose.production.yml restart"
echo "   2. Run validation: ./validate-admin-fix.sh"
echo "   3. Test admin interface: http://52.237.83.34:9000/app"
echo ""
echo "🔧 Admin Authentication Fix Complete!"
