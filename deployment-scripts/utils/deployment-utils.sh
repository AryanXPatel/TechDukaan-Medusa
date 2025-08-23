#!/bin/bash

# =====================================================================
# 🔧 Deployment Utilities and Helper Functions
# =====================================================================
# Common functions used across deployment scripts
# Source this file in other scripts: source utils/deployment-utils.sh

# Colors and formatting
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m'
export BOLD='\033[1m'

# Logging functions
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a ~/deployment.log
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a ~/deployment.log
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a ~/deployment.log
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a ~/deployment.log
}

# Network utilities
detect_external_ip() {
    local ip=""
    
    # Try multiple IP detection services
    for service in "ifconfig.me" "icanhazip.com" "ipecho.net/plain" "checkip.amazonaws.com"; do
        ip=$(curl -s --connect-timeout 5 "$service" 2>/dev/null | tr -d '[:space:]')
        
        # Validate IP format
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    echo "DETECTION_FAILED"
    return 1
}

# Environment validation
validate_environment() {
    local env_file="$1"
    local required_vars=("$@")
    shift # Remove first argument (env_file)
    
    if [ ! -f "$env_file" ]; then
        log_error "Environment file $env_file not found"
        return 1
    fi
    
    source "$env_file"
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Docker utilities
wait_for_containers() {
    local compose_file="$1"
    local max_wait="${2:-60}"
    local wait_time=0
    
    log_info "Waiting for containers to start (max ${max_wait}s)..."
    
    while [ $wait_time -lt $max_wait ]; do
        local running=$(docker compose -f "$compose_file" ps --services --filter status=running | wc -l)
        local total=$(docker compose -f "$compose_file" ps --services | wc -l)
        
        if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
            log_success "All $total containers are running"
            return 0
        fi
        
        sleep 5
        wait_time=$((wait_time + 5))
    done
    
    log_error "Containers failed to start within ${max_wait}s"
    return 1
}

# Health check utilities
check_endpoint() {
    local url="$1"
    local expected_code="${2:-200}"
    local max_retries="${3:-5}"
    local retry_delay="${4:-5}"
    
    for ((i=1; i<=max_retries; i++)); do
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        
        if [ "$response_code" = "$expected_code" ]; then
            return 0
        fi
        
        if [ $i -lt $max_retries ]; then
            log_info "Health check attempt $i/$max_retries failed (HTTP $response_code), retrying in ${retry_delay}s..."
            sleep "$retry_delay"
        fi
    done
    
    log_error "Health check failed after $max_retries attempts (HTTP $response_code)"
    return 1
}

# Security utilities
generate_secret() {
    local length="${1:-16}"
    openssl rand -hex "$length"
}

generate_password() {
    local length="${1:-12}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# File utilities
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
        echo "$backup"
    fi
}

# System utilities
check_system_requirements() {
    local errors=()
    
    # Check memory
    local memory_gb=$(free -g | awk 'NR==2{print $2}')
    if [ "$memory_gb" -lt 1 ]; then
        errors+=("Insufficient memory: ${memory_gb}GB (minimum 1GB required)")
    fi
    
    # Check disk space
    local disk_gb=$(df -BG / | awk 'NR==2{gsub("G","",$4); print $4}')
    if [ "$disk_gb" -lt 10 ]; then
        errors+=("Insufficient disk space: ${disk_gb}GB (minimum 10GB required)")
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        errors+=("Docker not installed")
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        errors+=("Docker Compose not installed")
    fi
    
    if [ ${#errors[@]} -gt 0 ]; then
        log_error "System requirements check failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
    
    log_success "System requirements check passed"
    return 0
}

# Database utilities
test_database_connection() {
    local compose_file="$1"
    local max_retries="${2:-5}"
    
    for ((i=1; i<=max_retries; i++)); do
        if docker compose -f "$compose_file" exec -T medusa-server npx medusa migrations list &>/dev/null; then
            log_success "Database connection successful"
            return 0
        fi
        
        if [ $i -lt $max_retries ]; then
            log_info "Database connection attempt $i/$max_retries failed, retrying..."
            sleep 10
        fi
    done
    
    log_error "Database connection failed after $max_retries attempts"
    return 1
}

# Admin user utilities
test_admin_authentication() {
    local email="$1"
    local password="$2"
    local base_url="${3:-http://localhost:9000}"
    
    local auth_response=$(curl -s \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
        "$base_url/auth/user/emailpass" 2>/dev/null || echo "")
    
    if echo "$auth_response" | grep -q "token"; then
        log_success "Admin authentication successful"
        return 0
    else
        log_error "Admin authentication failed"
        return 1
    fi
}

# Comprehensive deployment status
get_deployment_status() {
    local compose_file="$1"
    
    echo "=== Deployment Status ==="
    echo "Date: $(date)"
    echo "User: $(whoami)"
    echo "Directory: $(pwd)"
    echo ""
    
    echo "=== System Resources ==="
    echo "Memory: $(free -h | awk 'NR==2{printf "Used: %s/%s", $3,$2}')"
    echo "Disk: $(df -h / | awk 'NR==2{printf "Used: %s/%s", $3,$2}')"
    echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    
    echo "=== Docker Containers ==="
    if [ -f "$compose_file" ]; then
        docker compose -f "$compose_file" ps
    else
        echo "Docker Compose file not found"
    fi
    echo ""
    
    echo "=== Network Ports ==="
    netstat -tlpn 2>/dev/null | grep -E ":(9000|6379|7700)" || echo "No services detected on standard ports"
    echo ""
}

# Cleanup utilities
cleanup_deployment() {
    log_info "Cleaning up temporary files..."
    rm -f /tmp/deploy_*.txt
    rm -f /tmp/verify_*.txt
    rm -f /tmp/auth_*.txt
    docker system prune -f &>/dev/null || true
    log_success "Cleanup completed"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f detect_external_ip validate_environment
export -f wait_for_containers check_endpoint
export -f generate_secret generate_password backup_file
export -f check_system_requirements test_database_connection
export -f test_admin_authentication get_deployment_status cleanup_deployment
