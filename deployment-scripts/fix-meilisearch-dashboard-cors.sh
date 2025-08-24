#!/bin/bash

# TechDukaan - Fix MeiliSearch Dashboard CORS Issue
# Fixes "It seems like Meilisearch isn't running" error
# Root cause: CORS configuration blocking self-referential requests

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

print_status "🔍 Diagnosing MeiliSearch Dashboard CORS Issue..."
echo ""

# Test direct MeiliSearch access
print_status "Testing direct MeiliSearch access (localhost:7700)..."
if curl -s http://localhost:7700/health > /dev/null; then
    print_success "✅ MeiliSearch is accessible on localhost:7700"
else
    print_error "❌ MeiliSearch is not accessible on localhost:7700"
    print_error "Please check if MeiliSearch container is running: docker ps | grep meilisearch"
    exit 1
fi

# Test proxied MeiliSearch access
print_status "Testing proxied MeiliSearch access (search.techdukaan.tech)..."
if curl -s https://search.techdukaan.tech/health > /dev/null; then
    print_success "✅ MeiliSearch is accessible through proxy"
else
    print_warning "⚠️ MeiliSearch proxy might have issues"
fi

# Get MeiliSearch API key from environment
MEILI_KEY=""
if [ -f ".env.production" ]; then
    MEILI_KEY=$(grep "MEILI_MASTER_KEY" .env.production | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi

if [ -n "$MEILI_KEY" ]; then
    print_status "Found MeiliSearch API key: ${MEILI_KEY:0:8}..."
else
    print_warning "No MeiliSearch API key found in .env.production"
fi

# Backup current Nginx configuration
BACKUP_DIR="/etc/nginx/backups/$(date +%Y%m%d_%H%M%S)"
print_status "Creating backup of current Nginx configuration..."
mkdir -p "$BACKUP_DIR"
cp /etc/nginx/sites-available/search.techdukaan.tech "$BACKUP_DIR/" 2>/dev/null || true

# Create updated Nginx configuration for search.techdukaan.tech with proper CORS
print_status "Creating updated Nginx configuration with proper CORS headers..."

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
        
        # Proxy to MeiliSearch
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
        
        # CORS headers - FIXED to allow self-referential requests
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

    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://localhost:7700/health;
        add_header Content-Type application/json;
        
        # CORS for health checks
        add_header 'Access-Control-Allow-Origin' '$http_origin' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
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
    exit 1
fi

# Restart Nginx
print_status "Restarting Nginx to apply changes..."
systemctl restart nginx

# Test the fix
print_status "Testing MeiliSearch dashboard connectivity..."
sleep 2

# Test API endpoint
if curl -s https://search.techdukaan.tech/health > /dev/null; then
    print_success "✅ MeiliSearch API is accessible through proxy"
else
    print_warning "⚠️ MeiliSearch API test failed"
fi

# Test with API key if available
if [ -n "$MEILI_KEY" ]; then
    print_status "Testing API with key..."
    if curl -s -H "X-Meili-API-Key: $MEILI_KEY" https://search.techdukaan.tech/stats > /dev/null; then
        print_success "✅ MeiliSearch API with key is working"
    else
        print_warning "⚠️ MeiliSearch API with key test failed"
    fi
fi

print_success "🎉 MeiliSearch Dashboard CORS fix completed!"
echo ""
print_status "🔗 Test your endpoints:"
echo "├── 🎛️ MeiliSearch Dashboard: https://search.techdukaan.tech"
echo "├── ❤️ MeiliSearch API Health: https://search.techdukaan.tech/health"
echo "└── 📊 MeiliSearch Stats: https://search.techdukaan.tech/stats"
echo ""
print_warning "📋 What was fixed:"
echo "1. ✅ CORS headers now allow self-referential requests"
echo "2. ✅ Added \$http_origin variable for dynamic CORS"
echo "3. ✅ Added X-Meili-API-Key to allowed headers"
echo "4. ✅ Proper preflight request handling"
echo ""
print_success "🚀 Your MeiliSearch dashboard should now work perfectly!"
