#!/bin/bash

# Medusa v2.x Admin Access Diagnostic Script
# Tests localhost vs external IP access to identify session/cookie issues

echo "🔍 Medusa v2.x Admin Access Diagnostic Test"
echo "=========================================="
echo "Testing both localhost and external IP access patterns"
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

# Function to test basic connectivity
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

# Function to test authentication flow
test_authentication_flow() {
    local url=$1
    local label=$2
    
    echo -e "${BLUE}🔐 Testing authentication flow: $label${NC}"
    
    # Clear any existing cookies
    rm -f "$COOKIE_JAR"
    
    # Step 1: Test authentication endpoint
    echo "   Step 1: Testing /auth/user/emailpass..."
    auth_response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" \
        -c "$COOKIE_JAR" \
        "$url/auth/user/emailpass" 2>/dev/null)
    
    auth_status=$(echo "$auth_response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    auth_body=$(echo "$auth_response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$auth_status" = "200" ]; then
        echo -e "   ✅ Authentication: ${GREEN}SUCCESS (200)${NC}"
        echo "      Response contains: $(echo "$auth_body" | grep -o '"token"' | wc -l) token(s)"
    else
        echo -e "   ❌ Authentication: ${RED}FAILED ($auth_status)${NC}"
        echo "      Response: $auth_body"
        return 1
    fi
    
    # Step 2: Test session creation
    echo "   Step 2: Testing /auth/session..."
    session_response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -b "$COOKIE_JAR" \
        -c "$COOKIE_JAR" \
        "$url/auth/session" 2>/dev/null)
    
    session_status=$(echo "$session_response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    session_body=$(echo "$session_response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$session_status" = "200" ]; then
        echo -e "   ✅ Session creation: ${GREEN}SUCCESS (200)${NC}"
        echo "      Session data: $(echo "$session_body" | wc -c) characters"
    else
        echo -e "   ❌ Session creation: ${RED}FAILED ($session_status)${NC}"
        echo "      Response: $session_body"
        return 1
    fi
    
    # Step 3: Test admin user endpoint (the critical test)
    echo "   Step 3: Testing /admin/users/me..."
    admin_response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "Content-Type: application/json" \
        -b "$COOKIE_JAR" \
        "$url/admin/users/me" 2>/dev/null)
    
    admin_status=$(echo "$admin_response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    admin_body=$(echo "$admin_response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$admin_status" = "200" ]; then
        echo -e "   ✅ Admin access: ${GREEN}SUCCESS (200)${NC}"
        echo "      User data retrieved successfully!"
        return 0
    else
        echo -e "   ❌ Admin access: ${RED}FAILED ($admin_status)${NC}"
        echo "      Response: $admin_body"
        return 1
    fi
}

# Function to analyze cookies
analyze_cookies() {
    local label=$1
    
    echo -e "${BLUE}🍪 Cookie Analysis: $label${NC}"
    
    if [ -f "$COOKIE_JAR" ]; then
        echo "   Cookies saved to: $COOKIE_JAR"
        echo "   Cookie contents:"
        while IFS=$'\t' read -r domain flag path secure expiration name value; do
            if [[ ! "$domain" =~ ^#.* ]]; then
                echo "      Domain: $domain"
                echo "      Name: $name"
                echo "      Value: ${value:0:20}..."
                echo "      Secure: $secure"
                echo "      Path: $path"
                echo "      ---"
            fi
        done < "$COOKIE_JAR"
    else
        echo -e "   ${RED}No cookies found${NC}"
    fi
}

# Main test execution
echo "🚀 Starting diagnostic tests..."
echo ""

# Test 1: Localhost access
echo -e "${YELLOW}TEST 1: LOCALHOST ACCESS${NC}"
echo "==============================="

if test_basic_connectivity "$LOCALHOST_URL" "localhost"; then
    echo ""
    if test_authentication_flow "$LOCALHOST_URL" "localhost"; then
        echo ""
        analyze_cookies "localhost"
        LOCALHOST_SUCCESS=true
    else
        LOCALHOST_SUCCESS=false
    fi
else
    LOCALHOST_SUCCESS=false
fi

echo ""
echo ""

# Test 2: External IP access
echo -e "${YELLOW}TEST 2: EXTERNAL IP ACCESS${NC}"
echo "==============================="

if test_basic_connectivity "$EXTERNAL_URL" "external IP"; then
    echo ""
    if test_authentication_flow "$EXTERNAL_URL" "external IP"; then
        echo ""
        analyze_cookies "external IP"
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
echo -e "${YELLOW}📊 DIAGNOSTIC SUMMARY${NC}"
echo "======================"

if [ "$LOCALHOST_SUCCESS" = true ] && [ "$EXTERNAL_SUCCESS" = true ]; then
    echo -e "✅ ${GREEN}Both localhost and external access work perfectly!${NC}"
    echo "   The admin login should work in browser at both URLs."
    
elif [ "$LOCALHOST_SUCCESS" = true ] && [ "$EXTERNAL_SUCCESS" = false ]; then
    echo -e "⚠️  ${YELLOW}Localhost works but external IP fails${NC}"
    echo "   This confirms a domain/cookie configuration issue for external access."
    echo ""
    echo "🔧 Recommended fixes:"
    echo "   1. Check medusa-config.ts cookieOptions configuration"
    echo "   2. Verify CORS settings for external domain"
    echo "   3. Consider adding domain-specific cookie settings"
    echo "   4. Check if HTTPS is required for external access"
    
elif [ "$LOCALHOST_SUCCESS" = false ] && [ "$EXTERNAL_SUCCESS" = false ]; then
    echo -e "❌ ${RED}Both localhost and external access fail${NC}"
    echo "   This indicates a fundamental configuration issue."
    echo ""
    echo "🔧 Recommended fixes:"
    echo "   1. Check medusa-config.ts configuration"
    echo "   2. Verify database connection and admin user exists"
    echo "   3. Check container logs for errors"
    echo "   4. Verify JWT_SECRET and COOKIE_SECRET are set correctly"
    
elif [ "$LOCALHOST_SUCCESS" = false ] && [ "$EXTERNAL_SUCCESS" = true ]; then
    echo -e "🤔 ${BLUE}External works but localhost fails (unusual)${NC}"
    echo "   This is an unusual pattern that needs investigation."
    
fi

echo ""
echo "🔗 Test URLs for browser verification:"
echo "   Localhost: $LOCALHOST_URL/app"
echo "   External:  $EXTERNAL_URL/app"
echo ""
echo "📋 Admin credentials:"
echo "   Email: $ADMIN_EMAIL"
echo "   Password: $ADMIN_PASSWORD"

# Cleanup
rm -f "$COOKIE_JAR"

echo ""
echo "✨ Diagnostic test completed!"
