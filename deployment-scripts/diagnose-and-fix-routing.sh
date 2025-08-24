#!/bin/bash

# TechDukaan - Diagnose and Fix Subdomain Routing Issue
# CRITICAL: search.techdukaan.tech routing to Medusa instead of MeiliSearch
# This script will diagnose and fix the routing configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

print_status "🔍 DIAGNOSING SUBDOMAIN ROUTING ISSUE..."
echo ""

# Check current Nginx configurations
print_status "Checking current Nginx configurations..."

# Check api.techdukaan.tech config
if [ -f "/etc/nginx/sites-available/api.techdukaan.tech" ]; then
    print_status "Found api.techdukaan.tech configuration"
    API_PROXY=$(grep -o "proxy_pass http://localhost:[0-9]*" /etc/nginx/sites-available/api.techdukaan.tech | head -1)
    echo "  API proxy_pass: $API_PROXY"
else
    print_error "❌ api.techdukaan.tech configuration not found!"
fi

# Check search.techdukaan.tech config
if [ -f "/etc/nginx/sites-available/search.techdukaan.tech" ]; then
    print_status "Found search.techdukaan.tech configuration"
    SEARCH_PROXY=$(grep -o "proxy_pass http://localhost:[0-9]*" /etc/nginx/sites-available/search.techdukaan.tech | head -1)
    echo "  Search proxy_pass: $SEARCH_PROXY"
else
    print_error "❌ search.techdukaan.tech configuration not found!"
fi

echo ""

# Test direct service access
print_status "Testing direct service access..."

# Test Medusa (should be on port 9000)
if curl -s http://localhost:9000/health > /dev/null; then
    print_success "✅ Medusa accessible on localhost:9000"
else
    print_warning "⚠️ Medusa not accessible on localhost:9000"
fi

# Test MeiliSearch (should be on port 7700)
if curl -s http://localhost:7700/health > /dev/null; then
    print_success "✅ MeiliSearch accessible on localhost:7700"
else
    print_warning "⚠️ MeiliSearch not accessible on localhost:7700"
fi

echo ""

# Test current subdomain routing
print_status "Testing current subdomain routing..."

API_HEALTH=$(curl -s https://api.techdukaan.tech/health 2>/dev/null || echo "FAILED")
SEARCH_HEALTH=$(curl -s https://search.techdukaan.tech/health 2>/dev/null || echo "FAILED")

echo "  api.techdukaan.tech/health: $API_HEALTH"
echo "  search.techdukaan.tech/health: $SEARCH_HEALTH"

# Identify the problem
if [[ "$SEARCH_HEALTH" == *"Medusa"* ]]; then
    print_error "🚨 PROBLEM IDENTIFIED: search.techdukaan.tech is routing to Medusa!"
    print_error "    Expected: MeiliSearch response"
    print_error "    Actual: Medusa response"
    NEEDS_FIX=true
else
    print_success "✅ Routing appears correct"
    NEEDS_FIX=false
fi

if [ "$NEEDS_FIX" = true ]; then
    echo ""
    print_status "🔧 FIXING SUBDOMAIN ROUTING..."
    
    # Backup current configuration
    BACKUP_DIR="/etc/nginx/backups/routing-fix-$(date +%Y%m%d_%H%M%S)"
    print_status "Creating backup of current configuration..."
    mkdir -p "$BACKUP_DIR"
    cp /etc/nginx/sites-available/search.techdukaan.tech "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/nginx/sites-available/api.techdukaan.tech "$BACKUP_DIR/" 2>/dev/null || true
    
    # Recreate search.techdukaan.tech configuration with correct routing
    print_status "Recreating search.techdukaan.tech configuration..."
    
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

    # Rate limiting for search
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
        
        # CORS headers - Allow self-referential requests
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

    # Recreate api.techdukaan.tech configuration to ensure correct routing  
    print_status "Recreating api.techdukaan.tech configuration..."
    
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

    # Rate limiting for API
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

    # Test Nginx configuration
    print_status "Testing updated Nginx configuration..."
    if nginx -t; then
        print_success "✅ Nginx configuration is valid"
    else
        print_error "❌ Nginx configuration test failed"
        print_error "Restoring backup..."
        cp "$BACKUP_DIR/search.techdukaan.tech" /etc/nginx/sites-available/ 2>/dev/null || true
        cp "$BACKUP_DIR/api.techdukaan.tech" /etc/nginx/sites-available/ 2>/dev/null || true
        exit 1
    fi
    
    # Restart Nginx
    print_status "Restarting Nginx to apply fixes..."
    systemctl restart nginx
    
    # Wait a moment for restart
    sleep 3
    
    # Test the fix
    print_status "Testing fixed routing..."
    
    API_HEALTH_NEW=$(curl -s https://api.techdukaan.tech/health 2>/dev/null || echo "FAILED")
    SEARCH_HEALTH_NEW=$(curl -s https://search.techdukaan.tech/health 2>/dev/null || echo "FAILED")
    
    echo ""
    print_status "🔗 New routing test results:"
    echo "  api.techdukaan.tech/health: $API_HEALTH_NEW"
    echo "  search.techdukaan.tech/health: $SEARCH_HEALTH_NEW"
    
    # Verify the fix
    if [[ "$SEARCH_HEALTH_NEW" == *"Medusa"* ]]; then
        print_error "❌ STILL BROKEN: search.techdukaan.tech still routing to Medusa"
        print_error "Manual intervention required - check SSL configuration"
    else
        print_success "✅ FIXED: search.techdukaan.tech now routing correctly to MeiliSearch"
    fi
    
    echo ""
    print_success "🎉 Subdomain routing fix completed!"
    echo ""
    print_status "🔗 Test your endpoints:"
    echo "├── 🏪 Medusa API: https://api.techdukaan.tech"
    echo "├── 🔧 Admin Panel: https://api.techdukaan.tech/app"
    echo "├── 🔍 MeiliSearch API: https://search.techdukaan.tech"
    echo "└── 🎛️ MeiliSearch Dashboard: https://search.techdukaan.tech"
    echo ""
    print_warning "Note: SSL certificates may need to be reapplied:"
    echo "sudo certbot --nginx -d api.techdukaan.tech -d search.techdukaan.tech"
fi
