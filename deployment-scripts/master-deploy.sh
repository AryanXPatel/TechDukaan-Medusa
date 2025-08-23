#!/bin/bash

# Medusa Production Deployment Orchestrator
# Production-grade deployment automation with user-controlled configuration

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="$HOME/deployment.log"
readonly LOCKFILE="/tmp/medusa-deploy.lock"

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

# Source utilities if available (with fallback)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/utils/deployment-utils.sh" ]]; then
    source "$SCRIPT_DIR/utils/deployment-utils.sh"
fi

# Script metadata
readonly SCRIPT_VERSION="2.0.0"
readonly DEPLOYMENT_DATE="$(date '+%Y-%m-%d %H:%M:%S')"

# Deployment phases
readonly PHASES=(
    "system:System Dependencies Setup"
    "config:Environment Configuration"
    "deploy:Application Deployment"
    "verify:Deployment Verification"
)

# Initialize deployment
init_deployment() {
    # Check for existing deployment
    if [[ -f "$LOCKFILE" ]]; then
        log "ERROR" "Another deployment is already in progress"
        exit 1
    fi
    
    # Create lockfile
    echo "$$" > "$LOCKFILE"
    trap cleanup_deployment EXIT
    
    # Initialize logging
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
    
    log "INFO" "Starting Medusa Production Deployment v$SCRIPT_VERSION"
    log "INFO" "Deployment initiated at: $DEPLOYMENT_DATE"
    log "INFO" "Working directory: $PROJECT_ROOT"
    log "INFO" "Log file: $LOG_FILE"
}

# Cleanup on exit
cleanup_deployment() {
    rm -f "$LOCKFILE"
    log "INFO" "Deployment orchestrator finished"
}

# Validate prerequisites
validate_prerequisites() {
    log "INFO" "Validating deployment prerequisites..."
    
    # Check operating system
    if ! grep -q "Ubuntu" /etc/os-release; then
        log "ERROR" "This deployment requires Ubuntu Linux"
        exit 1
    fi
    
    # Check user permissions
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "Running as root is not recommended for production"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Check available disk space (minimum 10GB)
    local available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 10485760 ]]; then
        log "ERROR" "Insufficient disk space. At least 10GB required"
        exit 1
    fi
    
    # Check internet connectivity
    if ! curl -s --max-time 10 https://github.com > /dev/null; then
        log "ERROR" "No internet connectivity detected"
        exit 1
    fi
    
    log "INFO" "Prerequisites validation completed"
}

# Display deployment information
show_deployment_info() {
    log "INFO" "=== Medusa Production Deployment ==="
    log "INFO" "Version: $SCRIPT_VERSION"
    log "INFO" "Date: $DEPLOYMENT_DATE"
    log "INFO" "Target: Medusa v2.8.x E-commerce Platform"
    log "INFO" "Features: Admin Interface Session Fix, Production Configuration"
    log "INFO" "Security: User-controlled secrets and configuration"
    echo
    
    log "INFO" "Deployment Phases:"
    for phase in "${PHASES[@]}"; do
        local phase_name="${phase#*:}"
        log "INFO" "  - $phase_name"
    done
    echo
    
    log "WARN" "SECURITY NOTICE:"
    log "WARN" "- You must manually configure .env.production before deployment"
    log "WARN" "- This script does NOT auto-generate or populate secrets"
    log "WARN" "- All configuration values must be provided by you"
    echo
    
    read -p "Proceed with production deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Deployment cancelled by user"
        exit 0
    fi
}

# Execute deployment phase
execute_phase() {
    local phase_id="$1"
    local phase_name="$2"
    local script_name
    
    case "$phase_id" in
        "system")
            script_name="00-fresh-vm-setup.sh"
            ;;
        "config")
            script_name="01-clone-and-configure.sh"
            ;;
        "deploy")
            script_name="02-deploy-medusa.sh"
            ;;
        "verify")
            script_name="03-verify-deployment.sh"
            ;;
        *)
            log "ERROR" "Unknown deployment phase: $phase_id"
            exit 1
            ;;
    esac
    
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [[ ! -f "$script_path" ]]; then
        log "ERROR" "Phase script not found: $script_path"
        exit 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log "WARN" "Making script executable: $script_name"
        chmod +x "$script_path"
    fi
    
    log "INFO" "=== Phase: $phase_name ==="
    
    local start_time=$(date +%s)
    
    if "$script_path"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log "INFO" "Phase '$phase_name' completed successfully in ${duration}s"
    else
        local exit_code=$?
        log "ERROR" "Phase '$phase_name' failed with exit code $exit_code"
        
        # Provide troubleshooting guidance
        case "$phase_id" in
            "system")
                log "INFO" "System setup failed. Check package installation errors above."
                ;;
            "config")
                log "INFO" "Configuration validation failed. Ensure .env.production is properly configured."
                ;;
            "deploy")
                log "INFO" "Deployment failed. Check Docker logs: docker-compose logs"
                ;;
            "verify")
                log "INFO" "Verification failed. Some services may not be working correctly."
                ;;
        esac
        
        exit $exit_code
    fi
}

# Execute all deployment phases
run_deployment() {
    local total_start_time=$(date +%s)
    
    for phase in "${PHASES[@]}"; do
        local phase_id="${phase%%:*}"
        local phase_name="${phase#*:}"
        
        execute_phase "$phase_id" "$phase_name"
        
        # Brief pause between phases
        sleep 2
    done
    
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    
    log "INFO" "=== Deployment Summary ==="
    log "INFO" "All phases completed successfully"
    log "INFO" "Total deployment time: ${total_duration}s"
    log "INFO" "Deployment log: $LOG_FILE"
}

# Show post-deployment information
show_completion_info() {
    log "INFO" "=== Deployment Completed Successfully ==="
    echo
    
    # Get external IP for access information
    local external_ip
    external_ip=$(get_external_ip) || external_ip="YOUR_SERVER_IP"
    
    log "INFO" "Access Information:"
    log "INFO" "  API Health Check: http://$external_ip:9000/health"
    log "INFO" "  Admin Interface: http://$external_ip:9000/app"
    log "INFO" "  Store API: http://$external_ip:9000/store"
    echo
    
    log "INFO" "Next Steps:"
    log "INFO" "  1. Test admin interface login with your configured credentials"
    log "INFO" "  2. Configure firewall/security groups to allow port 9000"
    log "INFO" "  3. Set up SSL/TLS certificate for HTTPS (recommended)"
    log "INFO" "  4. Configure domain DNS if using custom domain"
    log "INFO" "  5. Set up automated backups for database"
    echo
    
    log "INFO" "Service Management:"
    log "INFO" "  View logs: docker-compose -f docker-compose.production.yml logs -f"
    log "INFO" "  Check status: docker-compose -f docker-compose.production.yml ps"
    log "INFO" "  Restart: docker-compose -f docker-compose.production.yml restart"
    echo
    
    log "INFO" "Documentation:"
    log "INFO" "  - README.md: Complete deployment guide"
    log "INFO" "  - Deployment log: $LOG_FILE"
    log "INFO" "  - Medusa docs: https://docs.medusajs.com"
    echo
    
    log "INFO" "Support:"
    log "INFO" "  If you encounter issues, check the troubleshooting section in README.md"
    log "INFO" "  For admin interface problems, ensure SESSION_SECRET matches COOKIE_SECRET"
}

# Main execution
main() {
    init_deployment
    validate_prerequisites
    show_deployment_info
    run_deployment
    show_completion_info
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
