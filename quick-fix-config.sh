#!/bin/bash

# ========================================
# Quick Fix for medusa-config.ts TypeScript Error
# ========================================
# Fixes the sessionOptions TypeScript error and continues the build

echo "🔧 Quick Fix: Correcting medusa-config.ts TypeScript Error..."
echo "============================================================="

# Create corrected medusa-config.ts without invalid sessionOptions
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
    // PRODUCTION FIX: Cookie options for HTTP external access (valid for v2.8.x)
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

echo "✅ Corrected medusa-config.ts (removed invalid sessionOptions)"

# Now rebuild with the corrected configuration
echo "🔨 Rebuilding admin interface with corrected configuration..."
export MEDUSA_ADMIN_BACKEND_URL=http://52.237.83.34:9000
export NODE_ENV=production

npm run build

if [ $? -eq 0 ]; then
    echo "✅ Admin interface build completed successfully!"
    
    # Verify the build output
    if [ -d ".medusa/admin" ]; then
        echo "✅ Admin build directory found: .medusa/admin"
        echo "📊 Build size: $(du -sh .medusa/admin | cut -f1)"
        
        # Rebuild Docker image with new admin build
        echo "🐳 Rebuilding Docker image with corrected admin interface..."
        docker-compose -f docker-compose.production.yml build --no-cache medusa-server
        
        # Start containers
        echo "🚀 Starting containers with fixed admin interface..."
        docker-compose -f docker-compose.production.yml up -d
        
        # Wait for services
        echo "⏳ Waiting for services to initialize..."
        sleep 15
        
        # Test the fix
        echo "🔍 Testing admin interface fix..."
        
        AUTH_RESPONSE=$(curl -s -c /tmp/quick_fix_test.txt \
            -H "Content-Type: application/json" \
            -d '{"email":"admin@techdukkan.com","password":"yIne2amI2YBhCk"}' \
            "http://52.237.83.34:9000/auth/user/emailpass")
        
        if echo "$AUTH_RESPONSE" | grep -q "token"; then
            echo "✅ Authentication: SUCCESS"
            TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
            
            SESSION_STATUS=$(curl -s -b /tmp/quick_fix_test.txt -c /tmp/quick_fix_test.txt \
                -H "Authorization: Bearer $TOKEN" \
                -d '{}' \
                -o /dev/null -w "%{http_code}" \
                "http://52.237.83.34:9000/auth/session")
            
            if [ "$SESSION_STATUS" = "200" ]; then
                echo "✅ Session Creation: SUCCESS ($SESSION_STATUS)"
                
                ADMIN_STATUS=$(curl -s -b /tmp/quick_fix_test.txt \
                    -H "Authorization: Bearer $TOKEN" \
                    -o /dev/null -w "%{http_code}" \
                    "http://52.237.83.34:9000/admin/users/me")
                
                if [ "$ADMIN_STATUS" = "200" ]; then
                    echo "✅ Admin Access: SUCCESS ($ADMIN_STATUS)"
                    echo ""
                    echo "🎉 ADMIN INTERFACE FIX SUCCESSFUL!"
                    echo "   💻 Browser admin interface should now work properly"
                    echo "   🌐 Test at: http://52.237.83.34:9000/app"
                    echo ""
                    echo "🔑 Login Credentials:"
                    echo "   Email: admin@techdukkan.com"
                    echo "   Password: yIne2amI2YBhCk"
                else
                    echo "❌ Admin Access: FAILED ($ADMIN_STATUS)"
                fi
            else
                echo "❌ Session Creation: FAILED ($SESSION_STATUS)"
            fi
        else
            echo "❌ Authentication: FAILED"
        fi
        
        rm -f /tmp/quick_fix_test.txt
        
    else
        echo "❌ Admin build directory not found"
        exit 1
    fi
else
    echo "❌ Admin interface build failed again"
    exit 1
fi

echo ""
echo "🔧 Quick Fix Complete!"
echo "   The TypeScript error has been resolved and admin interface rebuilt"
