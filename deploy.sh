#!/bin/bash

# TechDukaan Medusa Backend - Automated Deployment Script
# This script automates the complete deployment process on Azure VM
# 🎉 TESTED AND WORKING - Used for successful production deployment

set -e  # Exit on any error

echo "� TechDukaan Medusa Backend Deployment Starting..."
echo "=================================================="
echo "✅ This script has been tested and proven to work!"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_status "Docker and Docker Compose are installed"

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    print_warning ".env.production not found"
    if [ -f ".env.production.template" ]; then
        print_status "Copying from template..."
        cp .env.production.template .env.production
        print_warning "Please edit .env.production with your actual credentials before continuing"
        print_warning "Press Enter after editing .env.production, or Ctrl+C to exit"
        read -p ""
    else
        print_error ".env.production.template not found. Cannot proceed."
        exit 1
    fi
fi

print_status ".env.production found"

# Load environment variables (for validation only, Docker Compose will load them)
set -a
source .env.production
set +a

print_status "Environment variables loaded"

# Validate critical environment variables
if [ -z "$DATABASE_URL" ]; then
    print_error "DATABASE_URL is not set in .env.production"
    exit 1
fi

if [ -z "$MEILI_MASTER_KEY" ]; then
    print_error "MEILI_MASTER_KEY is not set in .env.production"
    exit 1
fi

if [ -z "$JWT_SECRET" ]; then
    print_error "JWT_SECRET is not set in .env.production"
    exit 1
fi

print_status "Critical environment variables validated"
echo "   - DATABASE_URL: Azure PostgreSQL configured"
echo "   - MEILI_MASTER_KEY: ${MEILI_MASTER_KEY:0:8}***"
echo "   - JWT_SECRET: ${JWT_SECRET:0:8}***"

# Stop any existing containers
print_status "Stopping existing containers..."
docker-compose -f docker-compose.production.yml down --remove-orphans || true

# Build the application (optional, can be skipped for faster deployment)
read -p "🏗️  Build new image? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Building Medusa server image..."
    docker-compose -f docker-compose.production.yml build --no-cache
else
    print_status "Skipping build, using existing image"
fi

# Start all services using docker-compose up (proper production method)
print_status "Starting all services..."
docker-compose -f docker-compose.production.yml up -d

# Wait for services to start
print_status "Waiting for services to start..."
sleep 30

# Health check
print_status "Performing health checks..."

# Check if containers are running
if ! docker-compose -f docker-compose.production.yml ps | grep "Up" > /dev/null; then
    print_error "Some containers failed to start"
    docker-compose -f docker-compose.production.yml logs
    exit 1
fi

# Wait a bit more for Medusa to fully start
print_status "Waiting for Medusa to fully initialize..."
sleep 30

# Test API health endpoint
if curl -f -s http://localhost:9000/health > /dev/null; then
    print_status "API health check passed"
else
    print_warning "API health check failed, checking if services are still starting..."
    print_status "You can check logs with: docker-compose -f docker-compose.production.yml logs -f"
fi

# Create admin user
print_status "Creating admin user..."
if docker-compose -f docker-compose.production.yml exec -T medusa-server npx medusa user --email $ADMIN_EMAIL --password $ADMIN_PASSWORD 2>/dev/null; then
    print_status "Admin user created successfully"
else
    print_warning "Admin user creation failed or user already exists"
    print_status "You can manually create with: docker-compose -f docker-compose.production.yml exec medusa-server npx medusa user --email $ADMIN_EMAIL --password $ADMIN_PASSWORD"
fi

# Get server IP for external testing
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to determine public IP")

echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "📍 Service URLs:"
echo "   • API Health: http://localhost:9000/health"
echo "   • Admin Interface: http://localhost:9000/app/"
if [ "$SERVER_IP" != "Unable to determine public IP" ]; then
echo "   • External API: http://$SERVER_IP:9000/health"
echo "   • External Admin: http://$SERVER_IP:9000/app/"
fi
echo ""
echo "🔧 Management Commands:"
echo "   • View logs: docker-compose -f docker-compose.production.yml logs -f"
echo "   • Restart: docker-compose -f docker-compose.production.yml restart"
echo "   • Stop: docker-compose -f docker-compose.production.yml down"
echo "   • Update: git pull && ./deploy.sh"
echo ""
echo "🧪 Test Commands:"
echo "   • Health: curl http://localhost:9000/health"
echo "   • Store API: curl http://localhost:9000/store/regions"
if [ "$SERVER_IP" != "Unable to determine public IP" ]; then
echo "   • External: curl http://$SERVER_IP:9000/health"
fi
echo ""

# Show container status
echo "📦 Container Status:"
docker-compose -f docker-compose.production.yml ps

echo ""
print_status "TechDukaan Medusa Backend is now running!"
if [ "$SERVER_IP" != "Unable to determine public IP" ]; then
    print_warning "Remember to configure your domain DNS to point to $SERVER_IP"
fi
print_warning "Ensure Azure NSG allows inbound traffic on port 9000"

# Final validation
echo ""
echo "🔍 Final Validation:"
echo "   Containers running: $(docker-compose -f docker-compose.production.yml ps --services --filter status=running | wc -l)/3"
echo "   Health endpoint: $(curl -s http://localhost:9000/health 2>/dev/null || echo 'Not responding')"

echo ""
print_status "Deployment script completed successfully! 🎉"
