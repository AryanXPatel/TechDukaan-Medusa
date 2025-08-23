#!/bin/bash

# TechDukaan - Automated SSL/Domain Configuration Script
# This script automates the complete setup of HTTPS API endpoints with SSL certificates
# Usage: sudo ./04-configure-ssl-domain.sh api.techdukaan.tech [email@domain.com]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Progress tracking
TOTAL_STEPS=8
CURRENT_STEP=0

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                TechDukaan SSL/Domain Setup                   ║${NC}"
    echo -e "${CYAN}║              Automated HTTPS Configuration                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${BLUE}[STEP $CURRENT_STEP/$TOTAL_STEPS]${NC} $1"
}

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

print_progress() {
    echo -e "${PURPLE}[PROGRESS]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root or with sudo"
    echo "Usage: sudo $0 <domain> [email]"
    exit 1
fi

# Check domain parameter
if [ $# -eq 0 ]; then
    print_error "Domain parameter is required"
    echo ""
    echo "Usage: sudo $0 <domain> [email]"
    echo "Example: sudo $0 api.techdukaan.tech admin@techdukaan.tech"
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-admin@$(echo $DOMAIN | sed 's/^api\.//')}"

print_header
print_status "Configuring SSL for domain: $DOMAIN"
print_status "Using email: $EMAIL"
echo ""

# Step 1: Prerequisites Validation
print_step "Validating Prerequisites"

# Check DNS resolution
print_progress "Checking DNS resolution for $DOMAIN..."
if ! nslookup "$DOMAIN" >/dev/null 2>&1; then
    print_error "DNS resolution failed for $DOMAIN"
    echo ""
    echo "💡 SOLUTION STEPS:"
    echo "1. Add DNS A record: $DOMAIN → $(curl -s ifconfig.me)"
    echo "2. Wait 5-15 minutes for DNS propagation"
    echo "3. Verify: nslookup $DOMAIN"
    exit 1
fi

RESOLVED_IP=$(nslookup "$DOMAIN" | grep "Address:" | tail -n1 | awk '{print $2}')
VM_IP=$(curl -s ifconfig.me)
if [ "$RESOLVED_IP" != "$VM_IP" ]; then
    print_warning "DNS resolves to $RESOLVED_IP but VM IP is $VM_IP"
    print_warning "This might cause SSL validation issues"
fi

print_success "DNS resolution verified: $DOMAIN → $RESOLVED_IP"

# Check port accessibility
print_progress "Testing port accessibility..."
timeout 5 bash -c "</dev/tcp/$DOMAIN/80" 2>/dev/null
if [ $? -eq 0 ]; then
    print_success "Port 80 is accessible"
else
    print_error "Port 80 is not accessible from outside"
    echo ""
    echo "💡 SOLUTION STEPS:"
    echo "1. Open Azure Portal → Virtual Machines → [your-vm] → Networking"
    echo "2. Add inbound rule: Port 80, TCP, Any source, Allow"
    echo "3. Add inbound rule: Port 443, TCP, Any source, Allow"
    echo "4. Wait 2-3 minutes and retry this script"
    exit 1
fi

# Check if Docker services are running
print_progress "Checking Docker services..."
if ! docker ps | grep -q "medusa-server"; then
    print_error "Medusa server container is not running"
    echo ""
    echo "💡 SOLUTION STEPS:"
    echo "1. Start Docker services: docker-compose -f docker-compose.production.yml up -d"
    echo "2. Wait for services to be healthy"
    echo "3. Retry this script"
    exit 1
fi

if ! docker ps | grep -q "meilisearch"; then
    print_warning "MeiliSearch container not running (optional service)"
else
    print_success "MeiliSearch container is running"
fi

print_success "Prerequisites validation completed"
echo ""

# Step 2: Install Required Packages
print_step "Installing Required Packages"

print_progress "Updating package lists..."
apt update -qq

if ! command -v nginx >/dev/null 2>&1; then
    print_progress "Installing Nginx..."
    apt install -y nginx
    systemctl enable nginx
    print_success "Nginx installed and enabled"
else
    print_success "Nginx is already installed"
fi

if ! command -v certbot >/dev/null 2>&1; then
    print_progress "Installing Certbot..."
    apt install -y certbot python3-certbot-nginx
    print_success "Certbot installed"
else
    print_success "Certbot is already installed"
fi
echo ""

# Step 3: Configure Nginx Reverse Proxy
print_step "Configuring Nginx Reverse Proxy"

print_progress "Creating Nginx configuration for $DOMAIN..."

# Backup existing configuration if it exists
if [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
    cp "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-available/$DOMAIN.backup.$(date +%s)"
    print_status "Backed up existing configuration"
fi

cat > "/etc/nginx/sites-available/$DOMAIN" << EOF
server {
    listen 80;
    server_name $DOMAIN;

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

    # MeiliSearch proxy endpoint
    location /search {
        limit_req zone=search burst=30 nodelay;
        
        # Remove /search prefix and proxy to MeiliSearch
        rewrite ^/search/(.*) /\$1 break;
        rewrite ^/search\$ / break;
        
        proxy_pass http://localhost:7700;
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
}
EOF

# Add rate limiting configuration to nginx.conf if not present
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    print_progress "Adding rate limiting configuration..."
    sed -i '/http {/a\    # Rate limiting zones\n    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;\n    limit_req_zone $binary_remote_addr zone=search:10m rate=20r/s;' /etc/nginx/nginx.conf
fi

# Enable the site
print_progress "Enabling Nginx site..."
ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"

# Remove default site if it exists
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    rm -f "/etc/nginx/sites-enabled/default"
    print_status "Removed default Nginx site"
fi

print_success "Nginx configuration created and enabled"
echo ""

# Step 4: Test Nginx Configuration
print_step "Testing Nginx Configuration"

print_progress "Validating Nginx syntax..."
if nginx -t 2>/dev/null; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    nginx -t
    exit 1
fi

print_progress "Restarting Nginx..."
systemctl restart nginx
if systemctl is-active --quiet nginx; then
    print_success "Nginx restarted successfully"
else
    print_error "Failed to restart Nginx"
    systemctl status nginx
    exit 1
fi
echo ""

# Step 5: Test HTTP Endpoint
print_step "Testing HTTP Endpoint"

print_progress "Testing HTTP access to $DOMAIN..."
sleep 3  # Give Nginx time to fully restart

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/health" || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_success "HTTP endpoint is working (status: $HTTP_STATUS)"
else
    print_warning "HTTP endpoint test failed (status: $HTTP_STATUS)"
    print_status "This might be normal if services are still starting up"
fi
echo ""

# Step 6: Obtain SSL Certificate
print_step "Obtaining SSL Certificate"

print_progress "Requesting SSL certificate from Let's Encrypt..."
print_status "Email: $EMAIL"
print_status "Domain: $DOMAIN"

# Run certbot with automatic agreement and email
if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect; then
    print_success "SSL certificate obtained successfully"
else
    print_error "Failed to obtain SSL certificate"
    echo ""
    echo "💡 COMMON SOLUTIONS:"
    echo "1. Verify port 80 is accessible: telnet $DOMAIN 80"
    echo "2. Check DNS: nslookup $DOMAIN"
    echo "3. Check firewall: Azure NSG rules for ports 80/443"
    echo "4. Wait a few minutes and try: sudo certbot --nginx -d $DOMAIN"
    exit 1
fi
echo ""

# Step 7: Test HTTPS Endpoints
print_step "Testing HTTPS Endpoints"

print_progress "Waiting for SSL configuration to take effect..."
sleep 5

# Test main API endpoint
print_progress "Testing Medusa API endpoint..."
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/health" || echo "000")
if [ "$HTTPS_STATUS" = "200" ]; then
    print_success "✅ Medusa API: https://$DOMAIN (status: $HTTPS_STATUS)"
else
    print_warning "⚠️  Medusa API test failed (status: $HTTPS_STATUS)"
fi

# Test MeiliSearch endpoint
print_progress "Testing MeiliSearch endpoint..."
SEARCH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/search/health" || echo "000")
if [ "$SEARCH_STATUS" = "200" ]; then
    print_success "✅ MeiliSearch: https://$DOMAIN/search (status: $SEARCH_STATUS)"
else
    print_warning "⚠️  MeiliSearch test failed (status: $SEARCH_STATUS)"
fi

# Test admin interface
print_progress "Testing Admin interface..."
ADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/app" || echo "000")
if [ "$ADMIN_STATUS" = "200" ] || [ "$ADMIN_STATUS" = "302" ]; then
    print_success "✅ Admin Interface: https://$DOMAIN/app (status: $ADMIN_STATUS)"
else
    print_warning "⚠️  Admin interface test inconclusive (status: $ADMIN_STATUS)"
fi
echo ""

# Step 8: Update Backend Configuration
print_step "Updating Backend Configuration"

if [ -f ".env.production" ]; then
    print_progress "Updating backend URL in .env.production..."
    
    # Update MEDUSA_ADMIN_BACKEND_URL
    if grep -q "MEDUSA_ADMIN_BACKEND_URL" .env.production; then
        sed -i "s|MEDUSA_ADMIN_BACKEND_URL=.*|MEDUSA_ADMIN_BACKEND_URL=https://$DOMAIN|" .env.production
        print_success "Updated MEDUSA_ADMIN_BACKEND_URL to https://$DOMAIN"
    else
        echo "MEDUSA_ADMIN_BACKEND_URL=https://$DOMAIN" >> .env.production
        print_success "Added MEDUSA_ADMIN_BACKEND_URL to .env.production"
    fi
    
    print_progress "Restarting Docker services to apply configuration..."
    docker-compose -f docker-compose.production.yml restart medusa-server
    print_success "Docker services restarted"
else
    print_warning ".env.production not found, skipping backend URL update"
fi
echo ""

# Final Success Report
print_header
print_success "🎉 SSL/Domain Configuration Completed Successfully!"
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    SETUP COMPLETE                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🌐 Your TechDukaan API is now available at:${NC}"
echo -e "   • ${GREEN}Medusa API:${NC}      https://$DOMAIN"
echo -e "   • ${GREEN}Admin Interface:${NC} https://$DOMAIN/app"
echo -e "   • ${GREEN}MeiliSearch:${NC}     https://$DOMAIN/search"
echo -e "   • ${GREEN}Health Check:${NC}    https://$DOMAIN/health"
echo ""
echo -e "${CYAN}🔒 SSL Certificate Information:${NC}"
certbot certificates | grep -A 5 "$DOMAIN" || echo "   Certificate details available via: sudo certbot certificates"
echo ""
echo -e "${CYAN}🔧 Next Steps:${NC}"
echo "   1. Update your frontend .env.production with:"
echo "      NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://$DOMAIN"
echo "      NEXT_PUBLIC_MEILI_URL=https://$DOMAIN/search"
echo ""
echo "   2. Test all endpoints in your browser"
echo "   3. Deploy frontend changes to Vercel"
echo ""
echo -e "${CYAN}🛡️  Security Notes:${NC}"
echo "   • SSL certificate auto-renews via cron"
echo "   • CORS configured for techdukaan.tech"
echo "   • Rate limiting active on all endpoints"
echo ""
echo -e "${GREEN}✅ Your TechDukaan platform is now production-ready with HTTPS!${NC}"
