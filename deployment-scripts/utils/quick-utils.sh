#!/bin/bash

# =====================================================================
# 🔧 Quick Deployment Utilities
# =====================================================================
# Standalone utility scripts for common deployment tasks

# Update GitHub repository URL in master-deploy.sh
update_github_repo() {
    local repo_url="$1"
    if [ -z "$repo_url" ]; then
        echo "Usage: update_github_repo <repository_url>"
        echo "Example: update_github_repo https://github.com/username/TechDukaan.git"
        return 1
    fi
    
    sed -i "s|GITHUB_REPO=.*|GITHUB_REPO=\"$repo_url\"|" deployment-scripts/master-deploy.sh
    echo "✅ Updated GitHub repository URL to: $repo_url"
}

# Quick health check
quick_health_check() {
    echo "🔍 Quick Health Check"
    echo "===================="
    
    # Docker containers
    echo "📦 Containers:"
    if command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.production.yml ps 2>/dev/null || echo "   Docker Compose not running"
    else
        echo "   Docker Compose not available"
    fi
    
    # API health
    echo "🌐 API Health:"
    local health=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health 2>/dev/null || echo "000")
    if [ "$health" = "200" ]; then
        echo "   ✅ API responding (HTTP 200)"
    else
        echo "   ❌ API not responding (HTTP $health)"
    fi
    
    # Admin test
    echo "👤 Admin Interface:"
    local admin=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/app 2>/dev/null || echo "000")
    if [ "$admin" = "200" ]; then
        echo "   ✅ Admin interface accessible"
    else
        echo "   ❌ Admin interface not accessible (HTTP $admin)"
    fi
}

# Show deployment status
show_status() {
    echo "📊 TechDukaan Medusa Deployment Status"
    echo "======================================="
    echo "Date: $(date)"
    echo "User: $(whoami)"
    echo "Directory: $(pwd)"
    echo ""
    
    # System info
    echo "🖥️  System:"
    echo "   Memory: $(free -h | awk 'NR==2{printf "Used: %s/%s", $3,$2}')"
    echo "   Disk: $(df -h / | awk 'NR==2{printf "Used: %s/%s", $3,$2}')"
    echo "   Load: $(uptime | awk -F'load average:' '{print $2}' | xargs)"
    echo ""
    
    # External IP
    echo "🌐 Network:"
    local external_ip=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to detect")
    echo "   External IP: $external_ip"
    echo "   Admin URL: http://$external_ip:9000/app"
    echo ""
    
    quick_health_check
}

# Show admin credentials
show_credentials() {
    if [ -f ".env.production" ]; then
        source .env.production
        echo "🔑 Admin Credentials"
        echo "==================="
        echo "Email: $ADMIN_EMAIL"
        echo "Password: $ADMIN_PASSWORD"
        echo "URL: $MEDUSA_ADMIN_BACKEND_URL/app"
    else
        echo "❌ .env.production not found"
    fi
}

# Test admin authentication
test_admin() {
    if [ -f ".env.production" ]; then
        source .env.production
        echo "🔐 Testing Admin Authentication..."
        
        local auth_response=$(curl -s \
            -H "Content-Type: application/json" \
            -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" \
            "http://localhost:9000/auth/user/emailpass" 2>/dev/null || echo "")
        
        if echo "$auth_response" | grep -q "token"; then
            echo "✅ Admin authentication successful"
        else
            echo "❌ Admin authentication failed"
            echo "Response: $auth_response"
        fi
    else
        echo "❌ .env.production not found"
    fi
}

# Restart services
restart_services() {
    echo "🔄 Restarting Medusa services..."
    if [ -f "docker-compose.production.yml" ]; then
        docker-compose -f docker-compose.production.yml restart
        echo "✅ Services restarted"
        sleep 5
        quick_health_check
    else
        echo "❌ docker-compose.production.yml not found"
    fi
}

# Show logs
show_logs() {
    local service="${1:-medusa-server}"
    echo "📋 Showing logs for: $service"
    if [ -f "docker-compose.production.yml" ]; then
        docker-compose -f docker-compose.production.yml logs -f "$service"
    else
        echo "❌ docker-compose.production.yml not found"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "🚀 TechDukaan Medusa Deployment Utilities"
    echo "=========================================="
    echo "1. Show deployment status"
    echo "2. Quick health check"
    echo "3. Show admin credentials"
    echo "4. Test admin authentication"
    echo "5. Restart services"
    echo "6. Show logs (medusa-server)"
    echo "7. Show all logs"
    echo "8. Update GitHub repository URL"
    echo "9. Run full verification"
    echo "0. Exit"
    echo ""
}

# Interactive mode
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    while true; do
        show_menu
        read -p "Select option (0-9): " choice
        
        case $choice in
            1) show_status ;;
            2) quick_health_check ;;
            3) show_credentials ;;
            4) test_admin ;;
            5) restart_services ;;
            6) show_logs medusa-server ;;
            7) show_logs ;;
            8) 
                read -p "Enter GitHub repository URL: " repo_url
                update_github_repo "$repo_url"
                ;;
            9) 
                if [ -f "deployment-scripts/03-verify-deployment.sh" ]; then
                    ./deployment-scripts/03-verify-deployment.sh
                else
                    echo "❌ Verification script not found"
                fi
                ;;
            0) echo "👋 Goodbye!"; break ;;
            *) echo "❌ Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
fi
