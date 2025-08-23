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
    print_error ".env.production file not found"
    echo ""
    print_info "🚀 Quick Setup Guide:"
    print_info "  1. Copy template: cp .env.production.template .env.production"
    print_info "  2. Edit configuration: nano .env.production"
    print_info "  3. Replace ALL placeholder values with your actual configuration"
    echo ""
    print_info "� Find your VM IP address:"
    print_info "  curl ifconfig.me    # External IP for MEDUSA_ADMIN_BACKEND_URL"
    echo ""
    print_info "🔐 Generate secrets:"
    print_info "  openssl rand -base64 32    # For JWT_SECRET"
    print_info "  openssl rand -base64 16    # For SESSION_SECRET and COOKIE_SECRET (use SAME value!)"
    print_info "  openssl rand -hex 16       # For MEILI_MASTER_KEY"
    echo ""
    print_info "🗄️ Azure Storage Key (find in Azure Portal):"
    print_info "  Portal > Storage Accounts > sttechdukaanprod > Access keys > Copy key1"
    echo ""
    print_warning "⚠️  CRITICAL: SESSION_SECRET and COOKIE_SECRET must have identical values!"
    echo ""
    print_info "After editing, run the deployment script again."
    exit 1
fi

print_success ".env.production file found"

# Load template values for comparison
print_info "Loading template for comparison..."
set -a
source .env.production.template 2>/dev/null || true
# Store template values
TEMPLATE_DATABASE_URL="$DATABASE_URL"
TEMPLATE_MEDUSA_ADMIN_BACKEND_URL="$MEDUSA_ADMIN_BACKEND_URL"
TEMPLATE_JWT_SECRET="$JWT_SECRET"
TEMPLATE_COOKIE_SECRET="$COOKIE_SECRET"
TEMPLATE_SESSION_SECRET="$SESSION_SECRET"
TEMPLATE_MEILI_MASTER_KEY="$MEILI_MASTER_KEY"
TEMPLATE_AZURE_STORAGE_ACCOUNT_KEY="$AZURE_STORAGE_ACCOUNT_KEY"
set +a

# Load actual production environment variables for validation
print_info "Loading production configuration..."
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

# Validate required variables are set and different from template
VALIDATION_FAILED=false
echo ""
print_info "🔍 Validating configuration values..."

for var in "${REQUIRED_VARS[@]}"; do
    current_value="${!var}"
    template_var="TEMPLATE_$var"
    template_value="${!template_var}"
    
    if [ -z "$current_value" ]; then
        print_error "❌ $var is not set"
        VALIDATION_FAILED=true
    elif [[ "$current_value" == *"CHANGE_ME"* ]] || [[ "$current_value" == *"YOUR_"* ]] || [[ "$current_value" == *"GENERATE_"* ]] || [[ "$current_value" == *"USERNAME"* ]] || [[ "$current_value" == *"PASSWORD"* ]] || [[ "$current_value" == *"PLACEHOLDER"* ]] || [[ "$current_value" == *"TEMPLATE"* ]]; then
        print_error "❌ $var still contains placeholder: ${current_value}"
        case "$var" in
            "DATABASE_URL")
                print_info "   💡 Format: postgres://username:password@server.postgres.database.azure.com:5432/database?ssl=true"
                ;;
            "MEDUSA_ADMIN_BACKEND_URL")
                print_info "   💡 Get your IP: curl ifconfig.me"
                print_info "   💡 Format: http://YOUR_EXTERNAL_IP:9000"
                ;;
            "JWT_SECRET")
                print_info "   💡 Generate: openssl rand -base64 32"
                ;;
            "SESSION_SECRET"|"COOKIE_SECRET")
                print_info "   💡 Generate: openssl rand -base64 16 (use SAME value for both)"
                ;;
            "MEILI_MASTER_KEY")
                print_info "   💡 Generate: openssl rand -hex 16"
                ;;
            "AZURE_STORAGE_ACCOUNT_KEY")
                print_info "   💡 Azure Portal > Storage Accounts > sttechdukaanprod > Access keys"
                ;;
        esac
        VALIDATION_FAILED=true
    elif [ -n "$template_value" ] && [ "$current_value" = "$template_value" ]; then
        print_error "❌ $var has the same value as template (not customized)"
        VALIDATION_FAILED=true
    else
        print_success "✅ $var is configured"
    fi
done

# Additional specific validations
echo ""
print_info "🔍 Performing additional configuration checks..."

if [[ "$DATABASE_URL" == *"USERNAME:PASSWORD"* ]]; then
    print_error "❌ DATABASE_URL still contains USERNAME:PASSWORD placeholder"
    print_info "   💡 Replace with your actual Azure PostgreSQL credentials"
    VALIDATION_FAILED=true
fi

if [[ "$MEDUSA_ADMIN_BACKEND_URL" == *"YOUR_VM_IP"* ]]; then
    print_error "❌ MEDUSA_ADMIN_BACKEND_URL still contains YOUR_VM_IP placeholder"
    print_info "   💡 Run: curl ifconfig.me to get your external IP"
    print_info "   💡 Then replace YOUR_VM_IP with the actual IP address"
    VALIDATION_FAILED=true
fi

if [[ "$AZURE_STORAGE_ACCOUNT_KEY" == *"YOUR_AZURE_STORAGE_KEY"* ]]; then
    print_error "❌ AZURE_STORAGE_ACCOUNT_KEY still contains placeholder"
    print_info "   💡 Get key from: Azure Portal > Storage Accounts > sttechdukaanprod > Access keys"
    VALIDATION_FAILED=true
fi

# Critical validation: SESSION_SECRET must match COOKIE_SECRET
echo ""
if [ "$SESSION_SECRET" != "$COOKIE_SECRET" ]; then
    print_error "❌ SESSION_SECRET must match COOKIE_SECRET for admin interface to work"
    print_info "   💡 Generate one value and use it for both: openssl rand -base64 16"
    print_info "   💡 Set both SESSION_SECRET and COOKIE_SECRET to the same value"
    VALIDATION_FAILED=true
else
    print_success "✅ SESSION_SECRET correctly matches COOKIE_SECRET"
fi

# Validate secret lengths
if [ ${#JWT_SECRET} -lt 32 ]; then
    print_warning "⚠️ JWT_SECRET is shorter than recommended 32 characters"
fi

if [ ${#COOKIE_SECRET} -lt 16 ]; then
    print_warning "⚠️ COOKIE_SECRET is shorter than recommended 16 characters"
fi

# Validate external URL format
if [[ ! "$MEDUSA_ADMIN_BACKEND_URL" =~ ^https?://[^/]+:[0-9]+$ ]]; then
    print_warning "⚠️ MEDUSA_ADMIN_BACKEND_URL format may be incorrect: $MEDUSA_ADMIN_BACKEND_URL"
    print_info "   💡 Expected format: http://YOUR_EXTERNAL_IP:9000"
    print_info "   💡 Get IP: curl ifconfig.me"
fi

# Check database URL format
if [[ ! "$DATABASE_URL" =~ ^postgres://.*@.*:.*/.* ]]; then
    print_error "❌ DATABASE_URL format appears incorrect"
    print_info "   💡 Expected format: postgres://username:password@server:5432/database?ssl=true"
    VALIDATION_FAILED=true
fi

if [ "$VALIDATION_FAILED" = true ]; then
    echo ""
    print_error "❌ Configuration validation failed - placeholder values detected"
    echo ""
    print_info "🛠️ Quick Fix Guide:"
    print_info "  1. Edit configuration: nano .env.production"
    print_info "  2. Get your VM IP: curl ifconfig.me"
    print_info "  3. Generate secrets:"
    print_info "     openssl rand -base64 32    # JWT_SECRET"
    print_info "     openssl rand -base64 16    # SESSION_SECRET & COOKIE_SECRET (same value)"
    print_info "     openssl rand -hex 16       # MEILI_MASTER_KEY"
    print_info "  4. Get Azure Storage Key:"
    print_info "     Portal > Storage Accounts > sttechdukaanprod > Access keys > Copy key"
    print_info "  5. Update Database URL with your actual username/password"
    echo ""
    print_warning "⚠️ Remember: SESSION_SECRET and COOKIE_SECRET must be identical!"
    echo ""
    print_info "After fixing, run the deployment script again."
    echo ""
    print_info "📝 To fix this:"
    print_info "  1. Edit the file: nano .env.production"
    print_info "  2. Replace all GENERATE_*, YOUR_*, USERNAME, PASSWORD placeholders"
    print_info "  3. Generate secrets with:"
    print_info "     openssl rand -base64 32    # For JWT_SECRET"
    print_info "     openssl rand -base64 16    # For SESSION_SECRET and COOKIE_SECRET"
    print_info "     openssl rand -hex 16       # For MEILI_MASTER_KEY"
    print_info "  4. Run deployment script again"
    echo ""
    print_warning "⚠️  Remember: SESSION_SECRET and COOKIE_SECRET must have the same value!"
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
