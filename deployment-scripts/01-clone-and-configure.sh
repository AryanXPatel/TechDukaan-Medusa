#!/bin/bash

# =====================================================================
# Environment Configuration Validation
# =====================================================================
# This script validates that the user has properly configured their
# environment file with all required values for production deployment
#
# SECURITY: This script does NOT generate or auto-populate secrets
# User must provide all configuration values manually

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

echo "Environment Configuration Validation"
echo "===================================="
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -f ".env.production.template" ]; then
    print_error "Not in Medusa project directory or missing required files"
    exit 1
fi

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    print_warning ".env.production file not found"
    print_info "Creating .env.production from template..."
    
    if [ ! -f ".env.production.template" ]; then
        print_error ".env.production.template not found"
        exit 1
    fi
    
    cp .env.production.template .env.production
    print_success ".env.production created from template"
    
    echo ""
    print_warning "IMPORTANT: You must configure .env.production with your actual values"
    print_info "The file contains placeholder values that need to be replaced:"
    print_info "- Database credentials (USERNAME:PASSWORD)"
    print_info "- Security secrets (generate with openssl rand commands)"
    print_info "- Azure storage keys"
    print_info "- Your VM IP address"
    echo ""
    
    read -p "Would you like to edit .env.production in nano now? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_info "Opening .env.production in nano..."
        nano .env.production
        print_success "Environment file editing completed"
    else
        print_warning "You chose to skip editing. Please configure .env.production manually before continuing"
        print_info "You can edit it later with: nano .env.production"
    fi
    echo ""
fi

print_success ".env.production file found"

# Load environment variables for validation
set -a
source .env.production
set +a

print_info "Validating environment configuration..."

# Define required variables
REQUIRED_VARS=(
    "NODE_ENV"
    "DATABASE_URL"
    "JWT_SECRET"
    "COOKIE_SECRET"
    "SESSION_SECRET"
    "ADMIN_EMAIL"
    "ADMIN_PASSWORD"
    "MEDUSA_ADMIN_BACKEND_URL"
    "WORKER_MODE"
    "MEILI_MASTER_KEY"
)

# Validate required variables are set
VALIDATION_FAILED=false
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required variable $var is not set"
        VALIDATION_FAILED=true
    elif [[ "${!var}" == *"CHANGE_ME"* ]] || [[ "${!var}" == *"YOUR_"* ]] || [[ "${!var}" == *"GENERATE_"* ]] || [[ "${!var}" == *"USERNAME"* ]] || [[ "${!var}" == *"PASSWORD"* ]]; then
        print_error "Variable $var still contains placeholder value: ${!var}"
        VALIDATION_FAILED=true
    fi
done

# Critical validation: SESSION_SECRET must match COOKIE_SECRET
if [ "$SESSION_SECRET" != "$COOKIE_SECRET" ]; then
    print_error "SESSION_SECRET must match COOKIE_SECRET for admin interface fix"
    print_info "Set SESSION_SECRET=$COOKIE_SECRET in .env.production"
    VALIDATION_FAILED=true
else
    print_success "SESSION_SECRET correctly matches COOKIE_SECRET"
fi

# Validate secret lengths
if [ ${#JWT_SECRET} -lt 32 ]; then
    print_warning "JWT_SECRET is shorter than recommended 32 characters"
fi

if [ ${#COOKIE_SECRET} -lt 16 ]; then
    print_warning "COOKIE_SECRET is shorter than recommended 16 characters"
fi

# Validate external URL format
if [[ ! "$MEDUSA_ADMIN_BACKEND_URL" =~ ^https?://[^/]+:[0-9]+$ ]]; then
    print_warning "MEDUSA_ADMIN_BACKEND_URL format may be incorrect: $MEDUSA_ADMIN_BACKEND_URL"
    print_info "Expected format: http://YOUR_VM_IP:9000"
fi

# Check database URL format
if [[ ! "$DATABASE_URL" =~ ^postgres://.*@.*:.*/.* ]]; then
    print_error "DATABASE_URL format appears incorrect"
    print_info "Expected format: postgres://username:password@server:5432/database?ssl=true"
    VALIDATION_FAILED=true
fi

if [ "$VALIDATION_FAILED" = true ]; then
    echo ""
    print_error "Configuration validation failed"
    print_info "Please fix the issues above in .env.production before continuing"
    print_info ""
    print_info "Quick fix commands:"
    print_info "  Edit file: nano .env.production"
    print_info "  Generate JWT secret: openssl rand -base64 32"
    print_info "  Generate session/cookie secret: openssl rand -base64 16"
    print_info "  Generate MeiliSearch key: openssl rand -hex 16"
    print_info ""
    print_info "Make sure SESSION_SECRET and COOKIE_SECRET have the same value!"
    exit 1
fi

print_success "Environment configuration validation passed"
print_info "Configuration is ready for deployment"
echo ""

# Display non-sensitive configuration summary
echo "Configuration Summary:"
echo "====================="
echo "Node Environment: $NODE_ENV"
echo "Worker Mode: $WORKER_MODE"
echo "Admin Email: $ADMIN_EMAIL"
echo "External Backend URL: $MEDUSA_ADMIN_BACKEND_URL"
echo "Database Host: $(echo "$DATABASE_URL" | sed 's|.*@||' | sed 's|:.*||')"
echo "Session/Cookie Secrets: $([ "$SESSION_SECRET" = "$COOKIE_SECRET" ] && echo "✓ Matching" || echo "✗ Not matching")"
echo ""
echo "Ready for deployment."
