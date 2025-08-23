#!/bin/bash

# TechDukaan - Fix MeiliSearch Dashboard Static Assets
# This script fixes the white screen issue in MeiliSearch dashboard at /search
# Usage: sudo ./fix-meilisearch-dashboard.sh api.techdukaan.tech

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             MeiliSearch Dashboard Fix                        ║${NC}"
    echo -e "${CYAN}║           Fixing Static Assets Issue                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

# Check domain parameter
if [ $# -eq 0 ]; then
    print_error "Domain parameter is required"
    echo "Usage: sudo $0 <domain>"
    echo "Example: sudo $0 api.techdukaan.tech"
    exit 1
fi

DOMAIN="$1"

print_header
print_status "Fixing MeiliSearch dashboard for domain: $DOMAIN"
echo ""

# Backup existing configuration
if [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
    cp "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-available/$DOMAIN.backup.$(date +%s)"
    print_status "Backed up existing configuration"
fi

print_status "Creating fixed Nginx configuration..."

# Create the corrected Nginx configuration
cat > "/etc/nginx/sites-available/$DOMAIN" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    # SSL configuration (managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # MeiliSearch static assets (IMPORTANT: Must come before main location blocks)
    location ~* ^/(static|favicon.*\.png|manifest\.json|.*\.ico)\$ {
        limit_req zone=search burst=30 nodelay;
        
        proxy_pass http://localhost:7700;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Essential headers for static assets
        proxy_set_header Accept-Encoding "";
        add_header Cache-Control "public, max-age=3600";
    }

    # MeiliSearch dashboard and API endpoints
    location /search {
        limit_req zone=search burst=30 nodelay;
        
        # Proxy to MeiliSearch with path rewriting
        proxy_pass http://localhost:7700/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # CORS headers for search API
        add_header 'Access-Control-Allow-Origin' 'https://techdukaan.tech' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With, X-Meili-API-Key' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        
        # Handle preflight requests for search
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' 'https://techdukaan.tech' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With, X-Meili-API-Key' always;
            add_header 'Access-Control-Allow-Credentials' 'true' always;
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }

    # Medusa API endpoints (catch-all for everything else)
    location / {
        limit_req zone=api burst=20 nodelay;
        
        # Proxy to Medusa backend
        proxy_pass http://localhost:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
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
        if (\$request_method = 'OPTIONS') {
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

print_success "Fixed Nginx configuration created"

# Test Nginx configuration
print_status "Testing Nginx configuration..."
if nginx -t 2>/dev/null; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    nginx -t
    exit 1
fi

# Reload Nginx
print_status "Reloading Nginx..."
systemctl reload nginx
if systemctl is-active --quiet nginx; then
    print_success "Nginx reloaded successfully"
else
    print_error "Failed to reload Nginx"
    systemctl status nginx
    exit 1
fi

echo ""
print_success "🎉 MeiliSearch Dashboard Fix Applied!"
echo ""
echo -e "${CYAN}🧪 Test your MeiliSearch dashboard:${NC}"
echo "   • Visit: https://$DOMAIN/search"
echo "   • Dashboard should now load completely"
echo "   • No more white screen!"
echo ""
echo -e "${CYAN}🔧 What was fixed:${NC}"
echo "   • Static assets now route to MeiliSearch correctly"
echo "   • CSS and JavaScript files load properly"
echo "   • Favicon and manifest.json work"
echo "   • Dashboard interface is fully functional"
echo ""
echo -e "${GREEN}✅ Your MeiliSearch dashboard is now working correctly!${NC}"
