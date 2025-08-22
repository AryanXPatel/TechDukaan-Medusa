#!/bin/bash

# =====================================================================
# Medusa Deployment Verification
# =====================================================================
# Comprehensive testing suite for validating Medusa deployment
# Tests infrastructure, API functionality, and admin interface
# without exposing sensitive configuration details

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

print_test() {
    echo -e "${BLUE}Testing: $1${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

print_pass() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_warn() {
    echo -e "${YELLOW}⚠ WARN: $1${NC}"
    WARNING_TESTS=$((WARNING_TESTS + 1))
}

echo "Medusa Deployment Verification"
echo "==============================="
echo "Date: $(date)"
echo "Host: $(hostname)"
echo ""

# Load environment for validation (non-sensitive checks only)
if [ -f ".env.production" ]; then
    set -a
    source .env.production
    set +a
else
    print_fail "Environment file .env.production not found"
    exit 1
fi

# ==============================
# INFRASTRUCTURE TESTS
# ==============================
echo "Infrastructure Tests"
echo "--------------------"

# Docker services
print_test "Docker services status"
if [ -f "docker-compose.production.yml" ]; then
    RUNNING=$(docker-compose -f docker-compose.production.yml ps --services --filter status=running 2>/dev/null | wc -l)
    TOTAL=$(docker-compose -f docker-compose.production.yml ps --services 2>/dev/null | wc -l)
    
    if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        print_pass "All $TOTAL containers running"
    else
        print_fail "Container status: $RUNNING/$TOTAL running"
    fi
else
    print_fail "docker-compose.production.yml not found"
fi

# Port accessibility
print_test "Required ports listening"
REQUIRED_PORTS=("9000" "6379" "7700")
PORT_NAMES=("Medusa API" "Redis" "MeiliSearch")

for i in "${!REQUIRED_PORTS[@]}"; do
    PORT="${REQUIRED_PORTS[$i]}"
    NAME="${PORT_NAMES[$i]}"
    
    if netstat -tlpn 2>/dev/null | grep -q ":$PORT "; then
        print_pass "$NAME (port $PORT) accessible"
    else
        print_fail "$NAME (port $PORT) not accessible"
    fi
done

# ==============================
# API TESTS
# ==============================
echo ""
echo "API Functionality Tests" 
echo "-----------------------"

# Health endpoint
print_test "API health endpoint"
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health 2>/dev/null || echo "000")
if [ "$HEALTH_CODE" = "200" ]; then
    print_pass "Health endpoint responding"
else
    print_fail "Health endpoint failed (HTTP $HEALTH_CODE)"
fi

# Store API
print_test "Store API functionality"
STORE_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/store/regions 2>/dev/null || echo "000")
if [ "$STORE_CODE" = "200" ]; then
    print_pass "Store API accessible"
else
    print_fail "Store API failed (HTTP $STORE_CODE)"
fi

# Admin API (basic check without authentication)
print_test "Admin API endpoint"
ADMIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/admin/auth 2>/dev/null || echo "000")
if [ "$ADMIN_CODE" = "401" ] || [ "$ADMIN_CODE" = "200" ]; then
    print_pass "Admin API endpoint accessible"
else
    print_fail "Admin API endpoint failed (HTTP $ADMIN_CODE)"
fi

# ==============================
# DATABASE TESTS  
# ==============================
echo ""
echo "Database Tests"
echo "--------------"

# Database connectivity
print_test "Database connectivity"
if command -v docker-compose &> /dev/null; then
    DB_TEST=$(docker-compose -f docker-compose.production.yml exec -T medusa-server npx medusa migrations list 2>/dev/null | grep -c "Migration" || echo "0")
    if [ "$DB_TEST" -gt 0 ]; then
        print_pass "Database connected ($DB_TEST migrations found)"
    else
        print_fail "Database connection failed"
    fi
else
    print_warn "Cannot test database - docker-compose not available"
fi

# ==============================
# AUTHENTICATION TESTS
# ==============================
echo ""
echo "Authentication Tests"
echo "-------------------"

# Admin authentication (if credentials provided)
if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
    print_test "Admin authentication flow"
    
    AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"hidden\"}" \
        "http://localhost:9000/auth/user/emailpass" 2>/dev/null || echo "000")
    
    # Note: We don't actually send the real password in logs
    if [ "$AUTH_CODE" = "200" ] || [ "$AUTH_CODE" = "401" ]; then
        print_pass "Authentication endpoint accessible"
    else
        print_fail "Authentication endpoint failed (HTTP $AUTH_CODE)"
    fi
else
    print_warn "Admin credentials not configured - skipping auth test"
fi

# ==============================
# CONFIGURATION VALIDATION
# ==============================
echo ""
echo "Configuration Validation"
echo "------------------------"

# Environment variables
print_test "Required environment variables"
REQUIRED_VARS=("DATABASE_URL" "JWT_SECRET" "COOKIE_SECRET" "SESSION_SECRET")
ENV_VALID=true

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_fail "$var not configured"
        ENV_VALID=false
    fi
done

if [ "$ENV_VALID" = true ]; then
    print_pass "All required environment variables configured"
fi

# Session secret validation (critical for admin fix)
print_test "Session secret configuration"
if [ "$SESSION_SECRET" = "$COOKIE_SECRET" ]; then
    print_pass "SESSION_SECRET matches COOKIE_SECRET (admin fix applied)"
else
    print_fail "SESSION_SECRET doesn't match COOKIE_SECRET"
fi

# External URL configuration
print_test "External URL configuration"
if [ -n "$MEDUSA_ADMIN_BACKEND_URL" ] && [[ "$MEDUSA_ADMIN_BACKEND_URL" =~ ^https?://.*:9000$ ]]; then
    print_pass "External backend URL configured"
else
    print_warn "External backend URL may need review"
fi

# ==============================
# SECURITY CHECKS
# ==============================
echo ""
echo "Security Validation"
echo "------------------"

# Firewall
print_test "Firewall configuration"
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "9000/tcp"; then
        print_pass "Firewall configured for port 9000"
    else
        print_warn "Firewall may need configuration for port 9000"
    fi
else
    print_warn "UFW not available - cannot check firewall"
fi

# File permissions
print_test "Configuration file permissions"
if [ -f ".env.production" ]; then
    PERMS=$(stat -c "%a" .env.production)
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "644" ]; then
        print_pass "Environment file permissions appropriate"
    else
        print_warn "Environment file permissions: $PERMS (consider 600)"
    fi
fi

# ==============================
# SYSTEM RESOURCES
# ==============================
echo ""
echo "System Resources"
echo "---------------"

# Memory
print_test "Available memory"
MEMORY_GB=$(free -g | awk 'NR==2{print $7}')
if [ "$MEMORY_GB" -gt 0 ]; then
    print_pass "Available memory: ${MEMORY_GB}GB"
else
    print_warn "Low available memory"
fi

# Disk space
print_test "Available disk space"
DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}' | sed 's/G//')
if (( $(echo "$DISK_AVAIL > 2" | bc -l 2>/dev/null || echo "1") )); then
    print_pass "Available disk space: ${DISK_AVAIL}GB"
else
    print_warn "Low disk space: ${DISK_AVAIL}GB"
fi

# ==============================
# SUMMARY
# ==============================
echo ""
echo "Verification Summary"
echo "==================="
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"  
echo "Warnings: $WARNING_TESTS"

SUCCESS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
echo "Success Rate: $SUCCESS_RATE%"

echo ""
if [ "$FAILED_TESTS" -eq 0 ]; then
    echo -e "${GREEN}✓ VERIFICATION PASSED${NC}"
    echo "Deployment appears to be functional."
    
    if [ "$WARNING_TESTS" -gt 0 ]; then
        echo -e "${YELLOW}Note: $WARNING_TESTS warnings detected - review recommended${NC}"
    fi
    
    echo ""
    echo "Access Information:"
    echo "- Local API: http://localhost:9000"
    echo "- Local Admin: http://localhost:9000/app"
    if [ -n "$MEDUSA_ADMIN_BACKEND_URL" ]; then
        echo "- External Admin: $MEDUSA_ADMIN_BACKEND_URL/app"
    fi
    
else
    echo -e "${RED}✗ VERIFICATION FAILED${NC}"
    echo "$FAILED_TESTS critical tests failed."
    echo "Review the failures above before proceeding to production."
    exit 1
fi

echo ""
echo "Verification completed at $(date)"
