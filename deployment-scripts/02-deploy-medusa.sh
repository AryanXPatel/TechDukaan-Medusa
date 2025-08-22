#!/bin/bash

# Medusa Production Deployment
# Deploys Medusa v2.8.x with admin interface session persistence fix

set -euo pipefail

# Simple logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "\033[0;34m[INFO]\033[0m $message" | tee -a ~/deployment.log
            ;;
        "SUCCESS")
            echo -e "\033[0;32m[SUCCESS]\033[0m $message" | tee -a ~/deployment.log
            ;;
        "WARN"|"WARNING")
            echo -e "\033[1;33m[WARN]\033[0m $message" | tee -a ~/deployment.log
            ;;
        "ERROR")
            echo -e "\033[0;31m[ERROR]\033[0m $message" | tee -a ~/deployment.log
            ;;
        *)
            echo "[$timestamp] $level $message" | tee -a ~/deployment.log
            ;;
    esac
}

# Get external IP
get_external_ip() {
    curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "localhost"
}

# Source utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/utils/deployment-utils.sh" ]]; then
    source "$SCRIPT_DIR/utils/deployment-utils.sh"
fi

# Configuration
readonly COMPOSE_FILE="docker-compose.production.yml"
readonly ENV_FILE=".env.production"

# Validate environment before deployment
validate_environment() {
    log "INFO" "Validating environment configuration..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log "ERROR" "Environment file not found: $ENV_FILE"
        log "ERROR" "You must create and configure $ENV_FILE before deployment"
        exit 1
    fi
    
    # Check for required variables
    local required_vars=(
        "DATABASE_URL"
        "JWT_SECRET"
        "COOKIE_SECRET"
        "SESSION_SECRET"
        "MEDUSA_ADMIN_BACKEND_URL"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$ENV_FILE" || grep -q "^${var}=CHANGE_ME" "$ENV_FILE"; then
            log "ERROR" "Required environment variable not configured: $var"
            log "ERROR" "Please update $ENV_FILE with your production values"
            exit 1
        fi
    done
    
    # Validate critical admin fix configuration
    local session_secret cookie_secret
    session_secret=$(grep "^SESSION_SECRET=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    cookie_secret=$(grep "^COOKIE_SECRET=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    
    if [[ "$session_secret" != "$cookie_secret" ]]; then
        log "ERROR" "Admin interface fix requires SESSION_SECRET to match COOKIE_SECRET exactly"
        log "ERROR" "Please update $ENV_FILE to make these values identical"
        exit 1
    fi
    
    log "INFO" "Environment validation completed successfully"
}

# Install production dependencies
install_dependencies() {
    log "INFO" "Installing production dependencies..."
    
    if [[ ! -f "package.json" ]]; then
        log "ERROR" "package.json not found. Ensure you're in the medusa-backend directory"
        exit 1
    fi
    
    npm ci --only=production
    log "INFO" "Dependencies installed"
}

# Build admin interface with proper configuration
build_admin_interface() {
    log "INFO" "Building admin interface with production configuration..."
    
    # Load environment variables for build
    set -a
    source "$ENV_FILE"
    set +a
    
    # Build admin interface
    if ! npm run build:admin; then
        log "ERROR" "Admin interface build failed"
        log "ERROR" "Check that MEDUSA_ADMIN_BACKEND_URL is correctly configured"
        exit 1
    fi
    
    log "INFO" "Admin interface built successfully"
}

# Deploy services using Docker Compose
deploy_services() {
    log "INFO" "Deploying Medusa services..."
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log "ERROR" "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    # Stop existing services
    if docker-compose -f "$COMPOSE_FILE" ps -q > /dev/null 2>&1; then
        log "INFO" "Stopping existing services..."
        docker-compose -f "$COMPOSE_FILE" down
    fi
    
    # Build and start services
    log "INFO" "Building and starting services..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    docker-compose -f "$COMPOSE_FILE" up -d
    
    log "INFO" "Services deployed"
}

# Wait for services to be ready
wait_for_services() {
    log "INFO" "Waiting for services to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log "INFO" "Health check attempt $attempt/$max_attempts..."
        
        if curl -sf http://localhost:9000/health > /dev/null 2>&1; then
            log "INFO" "Medusa API is ready"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log "ERROR" "Services failed to start within expected time"
            log "ERROR" "Check service logs: docker-compose -f $COMPOSE_FILE logs"
            exit 1
        fi
        
        sleep 10
        ((attempt++))
    done
}

# Run database migrations
run_migrations() {
    log "INFO" "Running database migrations..."
    
    if ! docker-compose -f "$COMPOSE_FILE" exec -T medusa-server npm run migration:run; then
        log "ERROR" "Database migrations failed"
        log "ERROR" "Check database connectivity and credentials"
        exit 1
    fi
    
    log "INFO" "Database migrations completed"
}

# Create admin user if configured
create_admin_user() {
    log "INFO" "Creating admin user..."
    
    # Load environment variables
    set -a
    source "$ENV_FILE"
    set +a
    
    # Check if admin credentials are configured
    if [[ -z "${ADMIN_EMAIL:-}" ]] || [[ -z "${ADMIN_PASSWORD:-}" ]]; then
        log "WARN" "Admin user credentials not configured in environment"
        log "WARN" "You can create an admin user manually after deployment"
        return 0
    fi
    
    # Create admin user
    if ! docker-compose -f "$COMPOSE_FILE" exec -T medusa-server npx medusa user -e "$ADMIN_EMAIL" -p "$ADMIN_PASSWORD"; then
        log "WARN" "Admin user creation failed (user may already exist)"
        log "INFO" "You can create an admin user manually if needed"
    else
        log "INFO" "Admin user created successfully"
    fi
}

# Show deployment status
show_deployment_status() {
    log "INFO" "Deployment status:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    log "INFO" "Service health checks:"
    if curl -sf http://localhost:9000/health > /dev/null 2>&1; then
        log "INFO" "  - API: Healthy"
    else
        log "WARN" "  - API: Not responding"
    fi
    
    if docker-compose -f "$COMPOSE_FILE" ps redis | grep -q "Up"; then
        log "INFO" "  - Redis: Running"
    else
        log "WARN" "  - Redis: Not running"
    fi
    
    if docker-compose -f "$COMPOSE_FILE" ps meilisearch | grep -q "Up"; then
        log "INFO" "  - MeiliSearch: Running"
    else
        log "WARN" "  - MeiliSearch: Not running"
    fi
}

# Main deployment process
main() {
    log "INFO" "=== Medusa Production Deployment ==="
    
    validate_environment
    install_dependencies
    build_admin_interface
    deploy_services
    wait_for_services
    run_migrations
    create_admin_user
    show_deployment_status
    
    log "INFO" "Medusa deployment completed successfully"
    
    # Show access information
    local external_ip
    external_ip=$(get_external_ip) || external_ip="localhost"
    
    log "INFO" "Access URLs:"
    log "INFO" "  - API: http://$external_ip:9000"
    log "INFO" "  - Admin: http://$external_ip:9000/app"
    log "INFO" "  - Health: http://$external_ip:9000/health"
    
    log "INFO" "Next steps:"
    log "INFO" "  1. Test admin interface access"
    log "INFO" "  2. Configure firewall to allow port 9000"
    log "INFO" "  3. Run verification script: ./03-verify-deployment.sh"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
