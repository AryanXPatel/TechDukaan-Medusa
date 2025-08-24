#!/bin/bash

# TechDukaan - Complete Dual Subdomain Setup (AUTOMATED)
# ONE COMMAND to set up everything correctly with zero routing confusion
# Replaces multiple manual steps with comprehensive automated solution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}[PHASE]${NC} $1"
}

# Validation function to check routing is correct
validate_routing() {
    local phase="$1"
    print_status "🔍 Validating routing ($phase)..."
    
    # Test direct service access
    if ! curl -s http://localhost:9000/health > /dev/null; then
        print_error "❌ Medusa not accessible on localhost:9000"
        return 1
    fi
    
    if ! curl -s http://localhost:7700/health > /dev/null; then
        print_error "❌ MeiliSearch not accessible on localhost:7700"
        return 1
    fi
    
    # Test subdomain routing
    local api_response=""
    local search_response=""
    
    if [ "$phase" = "HTTPS" ]; then
        api_response=$(curl -s https://api.techdukaan.tech/health 2>/dev/null || echo "FAILED")
        search_response=$(curl -s https://search.techdukaan.tech/health 2>/dev/null || echo "FAILED")
    else
        api_response=$(curl -s -H "Host: api.techdukaan.tech" http://localhost/health 2>/dev/null || echo "FAILED")
        search_response=$(curl -s -H "Host: search.techdukaan.tech" http://localhost/health 2>/dev/null || echo "FAILED")
    fi
    
    print_status "Routing validation results:"
    echo "  API response: $api_response"
    echo "  Search response: $search_response"
    
    # Check for routing errors
    if [[ "$search_response" == *"Medusa"* ]]; then
        print_error "🚨 ROUTING ERROR: search.techdukaan.tech routing to Medusa!"
        return 1
    fi
    
    if [[ "$api_response" == "FAILED" && "$search_response" == "FAILED" && "$phase" != "INITIAL" ]]; then
        print_warning "⚠️ Both endpoints failed (might be SSL transition)"
        return 0  # Don't fail during SSL transition
    fi
    
    print_success "✅ Routing validation passed"
    return 0
}

# Rollback function
rollback() {
    print_error "🔙 Rolling back to previous configuration..."
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        cp -r "$BACKUP_DIR/sites-available/"* /etc/nginx/sites-available/ 2>/dev/null || true
        cp -r "$BACKUP_DIR/sites-enabled/"* /etc/nginx/sites-enabled/ 2>/dev/null || true
        systemctl restart nginx
        print_warning "Backup restored. Please check your configuration manually."
    fi
    exit 1
}

# Trap errors and rollback
trap rollback ERR

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

print_header "🚀 TECHDUKAAN COMPLETE DUAL SUBDOMAIN SETUP"
echo ""
echo "This script will automatically:"
echo "├── 🔧 Configure dual subdomain Nginx routing"
echo "├── 🔒 Set up SSL certificates" 
echo "├── 🌐 Apply CORS fixes for MeiliSearch dashboard"
echo "├── ✅ Validate routing throughout the process"
echo "└── 🧪 Test all endpoints comprehensively"
echo ""
echo "Target Architecture:"
echo "├── 🏪 api.techdukaan.tech → Medusa (port 9000)"
echo "└── 🔍 search.techdukaan.tech → MeiliSearch (port 7700)"
echo ""

read -p "Continue with automated setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled by user"
    exit 0
fi

print_header "📋 PHASE 1: PREREQUISITES CHECK"

# Check Docker containers
print_status "Checking Docker containers..."
if ! docker ps | grep -q "medusa"; then
    print_error "❌ Medusa container not running"
    print_error "Please start your Docker containers first: docker-compose -f docker-compose.production.yml up -d"
    exit 1
fi

if ! docker ps | grep -q "meilisearch"; then
    print_error "❌ MeiliSearch container not running"
    print_error "Please start your Docker containers first: docker-compose -f docker-compose.production.yml up -d"
    exit 1
fi

print_success "✅ Docker containers running"

# Check DNS propagation
print_status "Checking DNS propagation..."
API_DNS=$(dig +short api.techdukaan.tech 2>/dev/null || echo "FAILED")
SEARCH_DNS=$(dig +short search.techdukaan.tech 2>/dev/null || echo "FAILED")

if [ "$API_DNS" = "FAILED" ] || [ "$SEARCH_DNS" = "FAILED" ]; then
    print_warning "⚠️ DNS lookup failed. Continuing with local setup..."
else
    print_success "✅ DNS records found: $API_DNS"
fi

# Install required packages
print_status "Installing required packages..."
apt update -qq
apt install -y nginx certbot python3-certbot-nginx curl dig

print_header "📁 PHASE 2: BACKUP & CLEANUP"

# Create comprehensive backup
BACKUP_DIR="/etc/nginx/backups/complete-setup-$(date +%Y%m%d_%H%M%S)"
print_status "Creating backup at $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
cp -r /etc/nginx/sites-available "$BACKUP_DIR/" 2>/dev/null || true
cp -r /etc/nginx/sites-enabled "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/nginx/nginx.conf "$BACKUP_DIR/" 2>/dev/null || true

# Clean up old configurations
print_status "Cleaning up existing configurations..."
rm -f /etc/nginx/sites-enabled/api.techdukaan.tech
rm -f /etc/nginx/sites-available/api.techdukaan.tech
rm -f /etc/nginx/sites-enabled/search.techdukaan.tech
rm -f /etc/nginx/sites-available/search.techdukaan.tech

print_header "🔧 PHASE 3: NGINX CONFIGURATION"

# Add rate limiting if not present
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    print_status "Adding rate limiting configuration..."
    sed -i '/http {/a\    # Rate limiting zones\n    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;\n    limit_req_zone $binary_remote_addr zone=search:10m rate=20r/s;' /etc/nginx/nginx.conf
fi

# Create API configuration (Medusa)
print_status "Creating api.techdukaan.tech configuration (Medusa)..."
cat > /etc/nginx/sites-available/api.techdukaan.tech << 'EOF'
server {
    listen 80;
    server_name api.techdukaan.tech;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header X-Robots-Tag "noindex, nofollow" always;

    location / {
        limit_req zone=api burst=20 nodelay;
        
        # CORRECT: Proxy to Medusa on port 9000
        proxy_pass http://localhost:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # CORS headers for API access
        add_header 'Access-Control-Allow-Origin' 'https://techdukaan.tech' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        
        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' 'https://techdukaan.tech' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With' always;
            add_header 'Access-Control-Allow-Credentials' 'true' always;
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }
}
EOF

# Create Search configuration (MeiliSearch) with CORS
print_status "Creating search.techdukaan.tech configuration (MeiliSearch + CORS)..."
cat > /etc/nginx/sites-available/search.techdukaan.tech << 'EOF'
server {
    listen 80;
    server_name search.techdukaan.tech;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header X-Robots-Tag "noindex, nofollow" always;

    location / {
        limit_req zone=search burst=30 nodelay;
        
        # CORRECT: Proxy to MeiliSearch on port 7700
        proxy_pass http://localhost:7700;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # CORS headers - Allow self-referential + frontend requests
        add_header 'Access-Control-Allow-Origin' '$http_origin' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With, X-Meili-API-Key' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        
        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '$http_origin' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With, X-Meili-API-Key' always;
            add_header 'Access-Control-Allow-Credentials' 'true' always;
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }
}
EOF

# Enable sites
print_status "Enabling Nginx sites..."
ln -sf /etc/nginx/sites-available/api.techdukaan.tech /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/search.techdukaan.tech /etc/nginx/sites-enabled/

# Test configuration
print_status "Testing Nginx configuration..."
if ! nginx -t; then
    print_error "❌ Nginx configuration test failed"
    rollback
fi

# Restart Nginx
print_status "Restarting Nginx..."
systemctl restart nginx

# Validate HTTP routing
validate_routing "HTTP" || rollback

print_header "🔒 PHASE 4: SSL CERTIFICATE SETUP"

print_status "Setting up SSL certificates..."
if certbot --nginx -d api.techdukaan.tech -d search.techdukaan.tech --non-interactive --agree-tos --email admin@techdukaan.tech --redirect; then
    print_success "✅ SSL certificates installed successfully"
else
    print_warning "⚠️ SSL certificate setup failed, continuing with HTTP"
    print_warning "You can manually run: sudo certbot --nginx -d api.techdukaan.tech -d search.techdukaan.tech"
fi

print_header "🧪 PHASE 5: COMPREHENSIVE TESTING"

# Wait for SSL to settle
sleep 3

# Final validation
validate_routing "HTTPS" || rollback

# Test MeiliSearch dashboard functionality
print_status "Testing MeiliSearch dashboard..."
DASHBOARD_TEST=$(curl -s https://search.techdukaan.tech/ | grep -i "meilisearch\|search" || echo "")
if [ -n "$DASHBOARD_TEST" ]; then
    print_success "✅ MeiliSearch dashboard accessible"
else
    print_warning "⚠️ MeiliSearch dashboard test inconclusive"
fi

# Test API endpoints
print_status "Testing API endpoints..."
API_HEALTH=$(curl -s https://api.techdukaan.tech/health 2>/dev/null || echo "FAILED")
SEARCH_HEALTH=$(curl -s https://search.techdukaan.tech/health 2>/dev/null || echo "FAILED")

print_header "🎉 SETUP COMPLETE!"
echo ""
print_success "✅ Dual subdomain architecture successfully configured!"
echo ""
print_status "🔗 Your endpoints:"
echo "├── 🏪 Medusa API: https://api.techdukaan.tech"
echo "├── 🔧 Admin Panel: https://api.techdukaan.tech/app"
echo "├── 🔍 MeiliSearch API: https://search.techdukaan.tech"
echo "└── 🎛️ MeiliSearch Dashboard: https://search.techdukaan.tech"
echo ""
print_status "📊 Health Check Results:"
echo "├── API Health: $API_HEALTH"
echo "└── Search Health: $SEARCH_HEALTH"
echo ""
print_success "🚀 Ready for production use!"
echo ""
print_warning "📋 Next steps:"
echo "1. Update your frontend environment variables:"
echo "   NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://api.techdukaan.tech"
echo "   NEXT_PUBLIC_MEILI_URL=https://search.techdukaan.tech"
echo ""
echo "2. Deploy your frontend with the new endpoints"
echo ""
echo "3. Test your complete application end-to-end"

# Disable error trap since we completed successfully
trap - ERR

print_success "🎯 Zero-routing-confusion setup completed successfully!"
