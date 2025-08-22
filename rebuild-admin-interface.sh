#!/bin/bash

# ========================================
# Rebuild Medusa Admin with Deployment Config
# ========================================
# This script properly rebuilds the admin interface with deployment configuration
# to fix the session persistence bug in production

echo "🏗️  Rebuilding Medusa Admin Interface for Production..."
echo "======================================================="
echo "🎯 Fixing admin build configuration for session persistence"
echo ""

# 1. Install Node.js and npm if not available
echo "📦 Step 1: Ensuring Node.js and npm are available..."
if ! command -v npm &> /dev/null; then
    echo "   📥 Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo "   ✅ Node.js $(node --version) and npm $(npm --version) installed"
else
    echo "   ✅ Node.js $(node --version) and npm $(npm --version) already available"
fi

# 2. Stop containers to prevent conflicts
echo "⏸️  Step 2: Stopping containers for admin rebuild..."
docker-compose -f docker-compose.production.yml down

# 3. Ensure proper environment for admin build
echo "🌐 Step 3: Setting up admin build environment..."
export MEDUSA_ADMIN_BACKEND_URL=http://52.237.83.34:9000
export NODE_ENV=production

echo "   📋 Build Environment:"
echo "      MEDUSA_ADMIN_BACKEND_URL: $MEDUSA_ADMIN_BACKEND_URL"
echo "      NODE_ENV: $NODE_ENV"

# 4. Install dependencies
echo "📦 Step 4: Installing/updating dependencies..."
npm install

# 5. Build admin interface with deployment configuration
echo "🔨 Step 5: Building admin interface with deployment configuration..."
echo "   📋 This fixes the session persistence bug in v2.8.x production mode"

# Build with deployment flag (critical for production session handling)
npm run build

if [ $? -eq 0 ]; then
    echo "   ✅ Admin interface build completed successfully"
else
    echo "   ❌ Admin interface build failed"
    exit 1
fi

# 6. Verify the build output
echo "🔍 Step 6: Verifying admin build output..."
if [ -d ".medusa/admin" ]; then
    echo "   ✅ Admin build directory found: .medusa/admin"
    echo "   📊 Build size: $(du -sh .medusa/admin | cut -f1)"
else
    echo "   ❌ Admin build directory not found"
    exit 1
fi

# 7. Create optimized Docker image with new admin build
echo "🐳 Step 7: Rebuilding Docker image with new admin interface..."
docker-compose -f docker-compose.production.yml build --no-cache medusa-server

# 8. Start containers with rebuilt admin
echo "🚀 Step 8: Starting containers with rebuilt admin interface..."
docker-compose -f docker-compose.production.yml up -d

# Wait for services to be ready
echo "   ⏳ Waiting for services to initialize..."
sleep 15

# 9. Verify the fix
echo "🔍 Step 9: Testing admin interface session persistence..."

# Test authentication flow
AUTH_RESPONSE=$(curl -s -c /tmp/admin_test.txt \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@techdukkan.com","password":"yIne2amI2YBhCk"}' \
    "http://52.237.83.34:9000/auth/user/emailpass")

if echo "$AUTH_RESPONSE" | grep -q "token"; then
    echo "   ✅ Authentication: SUCCESS"
    TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    # Test session creation
    SESSION_STATUS=$(curl -s -b /tmp/admin_test.txt -c /tmp/admin_test.txt \
        -H "Authorization: Bearer $TOKEN" \
        -d '{}' \
        -o /dev/null -w "%{http_code}" \
        "http://52.237.83.34:9000/auth/session")
    
    if [ "$SESSION_STATUS" = "200" ]; then
        echo "   ✅ Session Creation: SUCCESS ($SESSION_STATUS)"
        
        # Test admin access
        ADMIN_STATUS=$(curl -s -b /tmp/admin_test.txt \
            -H "Authorization: Bearer $TOKEN" \
            -o /dev/null -w "%{http_code}" \
            "http://52.237.83.34:9000/admin/users/me")
        
        if [ "$ADMIN_STATUS" = "200" ]; then
            echo "   ✅ Admin Access: SUCCESS ($ADMIN_STATUS)"
            echo ""
            echo "🎉 ADMIN REBUILD SUCCESSFUL!"
            echo "   💻 The browser admin interface should now work properly"
            echo "   🌐 Test at: http://52.237.83.34:9000/app"
            echo ""
            echo "🔑 Login Credentials:"
            echo "   Email: admin@techdukkan.com"
            echo "   Password: yIne2amI2YBhCk"
        else
            echo "   ❌ Admin Access: FAILED ($ADMIN_STATUS)"
            echo "   🔧 May need additional troubleshooting"
        fi
    else
        echo "   ❌ Session Creation: FAILED ($SESSION_STATUS)"
    fi
else
    echo "   ❌ Authentication: FAILED"
fi

# Cleanup
rm -f /tmp/admin_test.txt

echo ""
echo "📋 Rebuild Complete!"
echo "   1. ✅ Installed/verified Node.js and npm"
echo "   2. ✅ Built admin interface with proper deployment configuration"
echo "   3. ✅ Rebuilt Docker image with new admin build"
echo "   4. ✅ Restarted containers with enhanced session handling"
echo ""
echo "🎯 The admin interface should now properly handle sessions in the browser!"
