#!/bin/bash
# Secure deployment script for Azure VM

set -e  # Exit on any error

echo "🔒 TechDukaan Secure Deployment Script"
echo "====================================="

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo "❌ Error: .env.production file not found!"
    echo "📋 Please create it from the template:"
    echo "   cp .env.production.template .env.production"
    echo "   nano .env.production  # Fill in your actual values"
    exit 1
fi

# Load and export environment variables for Docker Compose
echo "🔍 Loading environment variables..."
set -a  # automatically export all variables
source .env.production
set +a  # turn off automatic export

# Validate critical environment variables
if [ -z "$DATABASE_URL" ] || [[ "$DATABASE_URL" == *"USERNAME"* ]]; then
    echo "❌ DATABASE_URL not properly configured"
    exit 1
fi

if [ -z "$AZURE_STORAGE_ACCOUNT_KEY" ] || [[ "$AZURE_STORAGE_ACCOUNT_KEY" == *"YOUR_AZURE"* ]]; then
    echo "❌ AZURE_STORAGE_ACCOUNT_KEY not properly configured"
    exit 1
fi

if [ -z "$JWT_SECRET" ] || [[ "$JWT_SECRET" == *"GENERATE"* ]]; then
    echo "❌ JWT_SECRET not properly configured"
    exit 1
fi

if [ -z "$MEILI_MASTER_KEY" ] || [[ "$MEILI_MASTER_KEY" == *"GENERATE"* ]]; then
    echo "❌ MEILI_MASTER_KEY not properly configured"
    exit 1
fi

echo "✅ Environment variables validated"
echo "   - DATABASE_URL: Connected to Azure PostgreSQL"
echo "   - MEILI_MASTER_KEY: ${MEILI_MASTER_KEY:0:8}***"
echo "   - JWT_SECRET: ${JWT_SECRET:0:8}***"

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Build and start production stack
echo "🚀 Starting production deployment..."
docker-compose -f docker-compose.production.yml up -d --build

# Wait for containers to start
echo "⏳ Waiting for containers to start..."
sleep 30

# Check container health
echo "🔍 Checking container status..."
docker ps

echo ""
echo "✅ Deployment complete!"
echo "📊 Check logs with: docker-compose -f docker-compose.production.yml logs"
echo "🌐 Your backend should be available at: http://localhost:9000"
echo "🔍 MeiliSearch should be available at: http://localhost:7700"
