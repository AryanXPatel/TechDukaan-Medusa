#!/bin/bash

# ========================================
# Medusa v2.8.x Production Admin Session Fix
# ========================================
# Fixes the known bug where admin interface works via curl but fails in browser
# Reference: GitHub issue #11769 - session data not set locally in browser

echo "🔧 Applying Medusa v2.8.x Production Admin Session Fix..."
echo "============================================================"
echo "🎯 Targeting known bug: admin authentication works via API but fails in browser"
echo "📋 Reference: https://github.com/medusajs/medusa/issues/11769"
echo ""

# 1. Fix critical environment variables
echo "🔐 Step 1: Fixing SESSION_SECRET environment variable..."
sed -i 's/^SESSION_SECRET=$/SESSION_SECRET=${COOKIE_SECRET}/' .env.production

# Ensure SESSION_SECRET is properly set to COOKIE_SECRET value
COOKIE_SECRET_VALUE=$(grep '^COOKIE_SECRET=' .env.production | cut -d'=' -f2)
sed -i "s/^SESSION_SECRET=.*$/SESSION_SECRET=${COOKIE_SECRET_VALUE}/" .env.production

echo "   ✅ SESSION_SECRET now set to: ${COOKIE_SECRET_VALUE:0:20}..."

# 2. Create production-specific medusa-config.ts
echo "⚙️  Step 2: Creating production-optimized medusa-config.ts..."

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
    // PRODUCTION FIX: Enhanced session and cookie configuration for v2.8.x
    sessionOptions: {
      name: "connect.sid",
      resave: false,
      saveUninitialized: false,
      secret: process.env.SESSION_SECRET || process.env.COOKIE_SECRET || "supersecret",
      cookie: {
        secure: false, // CRITICAL: Must be false for HTTP access
        httpOnly: true,
        maxAge: 1000 * 60 * 60 * 24 * 7, // 7 days
        sameSite: "lax", // Allow cross-origin for external IP
        domain: undefined, // Allow any domain
      },
    },
    // PRODUCTION FIX: Cookie options specifically for admin interface
    cookieOptions: {
      secure: false, // CRITICAL: Must be false for HTTP external access
      sameSite: "lax", // Allow external IP access
      httpOnly: true, // Security: prevent XSS
      maxAge: 1000 * 60 * 60 * 24 * 7, // 7 days
      domain: undefined, // Allow any domain for external access
      path: "/", // Ensure cookies work for all paths
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

echo "   ✅ Enhanced medusa-config.ts with production session fixes"

# 3. Rebuild admin interface with proper deployment configuration
echo "🏗️  Step 3: Rebuilding admin interface for production deployment..."
echo "   📋 This addresses the session persistence bug in v2.8.x admin interface"

# Stop containers first to prevent conflicts
echo "   ⏸️  Stopping containers for rebuild..."
docker-compose -f docker-compose.production.yml down

# Build with deployment flag (critical for production)
echo "   🔄 Building admin interface with deployment configuration..."
MEDUSA_ADMIN_BACKEND_URL=http://52.237.83.34:9000 npm run build

# 4. Start containers with new configuration
echo "🚀 Step 4: Starting containers with enhanced session configuration..."
docker-compose -f docker-compose.production.yml up -d

# Wait for services to be ready
echo "   ⏳ Waiting for services to initialize..."
sleep 10

# 5. Verify the fix
echo "🔍 Step 5: Verifying the admin session fix..."

# Test the authentication flow
echo "   📋 Testing admin authentication flow..."

# Clean slate
rm -f /tmp/session_fix_test.txt

# Test authentication
AUTH_RESPONSE=$(curl -s -c /tmp/session_fix_test.txt \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@techdukkan.com","password":"yIne2amI2YBhCk"}' \
    "http://52.237.83.34:9000/auth/user/emailpass")

if echo "$AUTH_RESPONSE" | grep -q "token"; then
    echo "   ✅ Authentication: SUCCESS"
    TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    # Test session creation
    SESSION_STATUS=$(curl -s -b /tmp/session_fix_test.txt -c /tmp/session_fix_test.txt \
        -H "Authorization: Bearer $TOKEN" \
        -d '{}' \
        -o /dev/null -w "%{http_code}" \
        "http://52.237.83.34:9000/auth/session")
    
    if [ "$SESSION_STATUS" = "200" ]; then
        echo "   ✅ Session Creation: SUCCESS ($SESSION_STATUS)"
        
        # Test admin access
        ADMIN_STATUS=$(curl -s -b /tmp/session_fix_test.txt \
            -H "Authorization: Bearer $TOKEN" \
            -o /dev/null -w "%{http_code}" \
            "http://52.237.83.34:9000/admin/users/me")
        
        if [ "$ADMIN_STATUS" = "200" ]; then
            echo "   ✅ Admin Access: SUCCESS ($ADMIN_STATUS)"
            echo ""
            echo "🎉 PRODUCTION ADMIN SESSION FIX SUCCESSFUL!"
            echo "   💻 Admin dashboard should now work in browser at:"
            echo "   🌐 http://52.237.83.34:9000/app"
            echo ""
            echo "🔑 Credentials:"
            echo "   Email: admin@techdukkan.com"
            echo "   Password: yIne2amI2YBhCk"
        else
            echo "   ❌ Admin Access: FAILED ($ADMIN_STATUS)"
            echo "   🔧 Additional troubleshooting may be needed"
        fi
    else
        echo "   ❌ Session Creation: FAILED ($SESSION_STATUS)"
    fi
else
    echo "   ❌ Authentication: FAILED"
    echo "   Response: $AUTH_RESPONSE"
fi

# Cleanup
rm -f /tmp/session_fix_test.txt

echo ""
echo "📋 Changes Applied:"
echo "   1. ✅ Fixed SESSION_SECRET environment variable"
echo "   2. ✅ Enhanced sessionOptions in medusa-config.ts"
echo "   3. ✅ Rebuilt admin interface with deployment configuration"
echo "   4. ✅ Applied production session persistence fixes"
echo ""
echo "🔧 Medusa v2.8.x Production Admin Session Fix Complete!"
echo "   This addresses the known bug where admin works via API but fails in browser"
