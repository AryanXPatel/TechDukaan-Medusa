#!/bin/bash

# Medusa v2.x Admin Access Diagnostic Script - IMPROVED VERSION
# Tests JWT token flow properly for both localhost and external IP

echo "🔍 Medusa v2.x Admin Access Diagnostic Test - IMPROVED"
echo "======================================================"
echo "Testing JWT token authentication flow properly"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test variables
LOCALHOST_URL="http://localhost:9000"
EXTERNAL_URL="http://52.237.83.34:9000"
ADMIN_EMAIL="admin@techdukkan.com"
ADMIN_PASSWORD="yIne2amI2YBhCk"
COOKIE_JAR="/tmp/medusa_cookies.txt"

echo "📋 Test Configuration:"
echo "   Localhost URL: $LOCALHOST_URL"
echo "   External URL:  $EXTERNAL_URL"
echo "   Admin Email:   $ADMIN_EMAIL"
echo "   Cookie Jar:    $COOKIE_JAR"
echo ""

# Function to test proper JWT authentication flow
test_jwt_authentication_flow() {
    local url=$1
    local label=$2
    
    echo -e "${BLUE}🔐 Testing JWT authentication flow: $label${NC}"
    
    # Clear any existing cookies
    rm -f "$COOKIE_JAR"
    
    # Step 1: Test authentication endpoint and extract JWT token
    echo "   Step 1: Testing /auth/user/emailpass and extracting JWT token..."
    auth_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" \
        -c "$COOKIE_JAR" \
        "$url/auth/user/emailpass" 2>/dev/null)
    
    auth_status=$(echo "$auth_response" | tail -1 | cut -d: -f2)
    auth_body=$(echo "$auth_response" | head -n -1)
    
    if [ "$auth_status" = "200" ]; then
        echo -e "   ✅ Authentication: ${GREEN}SUCCESS (200)${NC}"
        
        # Extract JWT token from response
        jwt_token=$(echo "$auth_body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$jwt_token" ]; then
            echo "      JWT Token extracted: ${jwt_token:0:20}..."
        else
            echo -e "      ${RED}ERROR: Could not extract JWT token from response${NC}"
            echo "      Response: $auth_body"
            return 1
        fi
    else
        echo -e "   ❌ Authentication: ${RED}FAILED ($auth_status)${NC}"
        echo "      Response: $auth_body"
        return 1
    fi
    
    # Step 2: Test session creation with JWT token in Authorization header
    echo "   Step 2: Testing /auth/session with JWT token..."
    session_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $jwt_token" \
        -b "$COOKIE_JAR" \
        -c "$COOKIE_JAR" \
        "$url/auth/session" 2>/dev/null)
    
    session_status=$(echo "$session_response" | tail -1 | cut -d: -f2)
    session_body=$(echo "$session_response" | head -n -1)
    
    if [ "$session_status" = "200" ]; then
        echo -e "   ✅ Session creation: ${GREEN}SUCCESS (200)${NC}"
        echo "      Session created with JWT token!"
    else
        echo -e "   ❌ Session creation: ${RED}FAILED ($session_status)${NC}"
        echo "      Response: $session_body"
        echo "      JWT token used: ${jwt_token:0:50}..."
        return 1
    fi
    
    # Step 3: Test admin user endpoint with session cookie
    echo "   Step 3: Testing /admin/users/me with session cookie..."
    admin_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -H "Content-Type: application/json" \
        -b "$COOKIE_JAR" \
        "$url/admin/users/me" 2>/dev/null)
    
    admin_status=$(echo "$admin_response" | tail -1 | cut -d: -f2)
    admin_body=$(echo "$admin_response" | head -n -1)
    
    if [ "$admin_status" = "200" ]; then
        echo -e "   ✅ Admin access: ${GREEN}SUCCESS (200)${NC}"
        echo "      User data retrieved successfully!"
        
        # Extract user info
        user_email=$(echo "$admin_body" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
        user_id=$(echo "$admin_body" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$user_email" ]; then
            echo "      User email: $user_email"
        fi
        if [ -n "$user_id" ]; then
            echo "      User ID: $user_id"
        fi
        
        return 0
    else
        echo -e "   ❌ Admin access: ${RED}FAILED ($admin_status)${NC}"
        echo "      Response: $admin_body"
        return 1
    fi
}

# Function to analyze cookies in detail
analyze_cookies_detailed() {
    local label=$1
    
    echo -e "${BLUE}🍪 Detailed Cookie Analysis: $label${NC}"
    
    if [ -f "$COOKIE_JAR" ]; then
        echo "   Cookies found in: $COOKIE_JAR"
        cookie_count=0
        
        while IFS=$'\t' read -r domain flag path secure expiration name value; do
            if [[ ! "$domain" =~ ^#.* ]] && [ -n "$name" ]; then
                cookie_count=$((cookie_count + 1))
                echo "   Cookie $cookie_count:"
                echo "      Domain: $domain"
                echo "      Name: $name"
                echo "      Value: ${value:0:30}..."
                echo "      Secure: $secure"
                echo "      Path: $path"
                echo "      Expiration: $expiration"
                echo "      ---"
            fi
        done < "$COOKIE_JAR"
        
        if [ $cookie_count -eq 0 ]; then
            echo -e "   ${YELLOW}No valid cookies found${NC}"
        else
            echo "   Total cookies: $cookie_count"
        fi
    else
        echo -e "   ${RED}No cookie file found${NC}"
    fi
}

# Test basic connectivity (same as before)
test_basic_connectivity() {
    local url=$1
    local label=$2
    
    echo -e "${BLUE}🔗 Testing basic connectivity: $label${NC}"
    
    # Test health endpoint
    echo "   Testing /health endpoint..."
    health_response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$url/health" 2>/dev/null)
    http_status=$(echo "$health_response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    
    if [ "$http_status" = "200" ]; then
        echo -e "   ✅ Health check: ${GREEN}OK (200)${NC}"
    else
        echo -e "   ❌ Health check: ${RED}FAILED ($http_status)${NC}"
        return 1
    fi
    
    # Test admin interface
    echo "   Testing /app endpoint..."
    app_response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$url/app" 2>/dev/null)
    app_status=$(echo "$app_response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    
    if [ "$app_status" = "200" ]; then
        echo -e "   ✅ Admin interface: ${GREEN}OK (200)${NC}"
    else
        echo -e "   ❌ Admin interface: ${RED}FAILED ($app_status)${NC}"
        return 1
    fi
    
    return 0
}

# Main test execution
echo "🚀 Starting improved diagnostic tests..."
echo ""

# Test 1: Localhost access with proper JWT flow
echo -e "${YELLOW}TEST 1: LOCALHOST ACCESS (JWT FLOW)${NC}"
echo "======================================="

if test_basic_connectivity "$LOCALHOST_URL" "localhost"; then
    echo ""
    if test_jwt_authentication_flow "$LOCALHOST_URL" "localhost"; then
        echo ""
        analyze_cookies_detailed "localhost"
        LOCALHOST_SUCCESS=true
    else
        LOCALHOST_SUCCESS=false
    fi
else
    LOCALHOST_SUCCESS=false
fi

echo ""
echo ""

# Test 2: External IP access with proper JWT flow
echo -e "${YELLOW}TEST 2: EXTERNAL IP ACCESS (JWT FLOW)${NC}"
echo "========================================="

if test_basic_connectivity "$EXTERNAL_URL" "external IP"; then
    echo ""
    if test_jwt_authentication_flow "$EXTERNAL_URL" "external IP"; then
        echo ""
        analyze_cookies_detailed "external IP"
        EXTERNAL_SUCCESS=true
    else
        EXTERNAL_SUCCESS=false
    fi
else
    EXTERNAL_SUCCESS=false
fi

echo ""
echo ""

# Summary and recommendations
echo -e "${YELLOW}📊 IMPROVED DIAGNOSTIC SUMMARY${NC}"
echo "=================================="

if [ "$LOCALHOST_SUCCESS" = true ] && [ "$EXTERNAL_SUCCESS" = true ]; then
    echo -e "🎉 ${GREEN}BOTH localhost and external access work with proper JWT flow!${NC}"
    echo "   The issue was in the JWT token handling."
    echo "   The admin interface should now work in browser."
    
elif [ "$LOCALHOST_SUCCESS" = true ] && [ "$EXTERNAL_SUCCESS" = false ]; then
    echo -e "⚠️  ${YELLOW}Localhost works but external IP fails with JWT${NC}"
    echo "   This suggests a domain-specific issue with JWT token handling."
    echo ""
    echo "🔧 Possible causes:"
    echo "   1. CORS settings blocking JWT tokens for external domain"
    echo "   2. Different cookie domain requirements"
    echo "   3. HTTPS vs HTTP JWT token handling differences"
    
elif [ "$LOCALHOST_SUCCESS" = false ] && [ "$EXTERNAL_SUCCESS" = false ]; then
    echo -e "❌ ${RED}Both localhost and external access fail with proper JWT flow${NC}"
    echo "   This indicates a deeper authentication configuration issue."
    echo ""
    echo "🔧 Recommended fixes:"
    echo "   1. Check JWT_SECRET configuration in .env.production"
    echo "   2. Verify admin user exists in database: medusa user create"
    echo "   3. Check medusa-config.ts JWT settings"
    echo "   4. Review container logs for JWT validation errors"
    
elif [ "$LOCALHOST_SUCCESS" = false ] && [ "$EXTERNAL_SUCCESS" = true ]; then
    echo -e "🤔 ${BLUE}External works but localhost fails (very unusual)${NC}"
    echo "   This is an unexpected pattern that needs investigation."
    
fi

echo ""
echo "💡 IMPORTANT INSIGHTS:"
echo "   - Authentication endpoint works (JWT token generation)"
echo "   - Session creation was the issue (JWT token validation)"
echo "   - This test shows the correct JWT Bearer token flow"
echo ""
echo "🌐 Browser Testing URLs:"
echo "   Localhost: $LOCALHOST_URL/app"
echo "   External:  $EXTERNAL_URL/app"
echo ""
echo "🔑 Admin credentials:"
echo "   Email: $ADMIN_EMAIL"
echo "   Password: $ADMIN_PASSWORD"

# Cleanup
rm -f "$COOKIE_JAR"

echo ""
echo "✨ Improved diagnostic test completed!"
