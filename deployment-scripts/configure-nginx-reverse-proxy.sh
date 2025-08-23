#!/bin/bash

# TechDukaan - Nginx Reverse Proxy Configuration for api.techdukaan.tech
# This script sets up Nginx to proxy requests to Medusa backend and MeiliSearch

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

print_status "Setting up Nginx reverse proxy for api.techdukaan.tech..."

# Install Nginx if not installed
if ! command -v nginx &> /dev/null; then
    print_status "Installing Nginx..."
    apt update
    apt install -y nginx
    systemctl enable nginx
fi

# Install Certbot for SSL if not installed
if ! command -v certbot &> /dev/null; then
    print_status "Installing Certbot for SSL certificates..."
    apt install -y certbot python3-certbot-nginx
fi

# Create Nginx configuration for api.techdukaan.tech
print_status "Creating Nginx configuration..."

cat > /etc/nginx/sites-available/api.techdukaan.tech << 'EOF'
server {
    listen 80;
    server_name api.techdukaan.tech;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Rate limiting
    location / {
        limit_req zone=api burst=20 nodelay;
        
        # Proxy to Medusa backend
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

    # MeiliSearch proxy endpoint
    location /search {
        limit_req zone=search burst=30 nodelay;
        
        # Remove /search prefix and proxy to MeiliSearch
        rewrite ^/search/(.*) /$1 break;
        rewrite ^/search$ / break;
        
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
        
        # CORS headers for search API
        add_header 'Access-Control-Allow-Origin' 'https://techdukaan.tech' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With, X-Meili-API-Key' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        
        # Handle preflight requests for search
        if ($request_method = 'OPTIONS') {
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
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Add rate limiting configuration to nginx.conf if not present
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    print_status "Adding rate limiting configuration..."
    sed -i '/http {/a\    # Rate limiting zones\n    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;\n    limit_req_zone $binary_remote_addr zone=search:10m rate=20r/s;' /etc/nginx/nginx.conf
fi

# Enable the site
print_status "Enabling Nginx site..."
ln -sf /etc/nginx/sites-available/api.techdukaan.tech /etc/nginx/sites-enabled/

# Test Nginx configuration
print_status "Testing Nginx configuration..."
if nginx -t; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

# Restart Nginx
print_status "Restarting Nginx..."
systemctl restart nginx

print_success "Nginx reverse proxy configured successfully!"
print_warning "Next steps:"
echo "1. Point your DNS A record for api.techdukaan.tech to this server's IP address"
echo "2. Run: sudo certbot --nginx -d api.techdukaan.tech"
echo "3. Ensure Docker containers (medusa-server, meilisearch) are running on ports 9000 and 7700"
echo ""
print_status "Testing endpoints will be available at:"
echo "- Medusa API: https://api.techdukaan.tech"
echo "- MeiliSearch: https://api.techdukaan.tech/search"
echo "- Health check: https://api.techdukaan.tech/health"
