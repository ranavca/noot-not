#!/bin/bash

# Deployment script for noot-not main server (API + Frontend)
# This script deploys both the PHP API and React frontend on the same server

set -e

echo "🚀 Starting deployment of noot-not main server..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_ENV=${1:-production}
PROJECT_DIR=$(pwd)

echo -e "${YELLOW}Deployment environment: $DEPLOY_ENV${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

print_status "Docker is available and running"

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

print_status "Docker Compose is available"

# Determine compose command
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p nginx/ssl
mkdir -p noot-not-api/public/images
mkdir -p logs

print_status "Directories created"

# Stop existing containers if running
echo "🛑 Stopping existing containers..."
$COMPOSE_CMD down --remove-orphans || true
print_status "Existing containers stopped"

# Remove old images (optional, uncomment if you want to force rebuild)
# echo "🗑️ Removing old images..."
# docker image prune -f

# Build and start services
echo "🔨 Building and starting services..."
if [ "$DEPLOY_ENV" = "production" ]; then
    $COMPOSE_CMD up -d --build
else
    $COMPOSE_CMD up -d --build
fi

print_status "Services built and started"

# Wait for services to be healthy
echo "🏥 Waiting for services to be healthy..."
sleep 10

# Check health of services
check_service_health() {
    local service_name=$1
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker container inspect "$service_name" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            print_status "$service_name is healthy"
            return 0
        elif docker container inspect "$service_name" --format='{{.State.Status}}' 2>/dev/null | grep -q "running"; then
            echo -n "."
            sleep 2
            ((attempt++))
        else
            print_error "$service_name is not running"
            return 1
        fi
    done
    
    print_warning "$service_name health check timed out"
    return 1
}

# Check individual services
echo "Checking database health..."
check_service_health "noot-not-db"

echo "Checking API health..."
check_service_health "noot-not-api"

echo "Checking frontend health..."
check_service_health "noot-not-frontend"

# Show running containers
echo "📋 Running containers:"
docker ps --filter "name=noot-not" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Show logs for any failed services
echo "📜 Checking for any errors in logs..."
for service in noot-not-db noot-not-api noot-not-frontend; do
    if ! docker container inspect "$service" --format='{{.State.Status}}' 2>/dev/null | grep -q "running"; then
        print_error "Service $service is not running. Logs:"
        docker logs "$service" --tail 20
    fi
done

# Final status
echo ""
echo "🎉 Deployment completed!"
echo ""
echo "Services available at:"
echo "  📱 Frontend: http://localhost:3000"
echo "  🔌 API: http://localhost:8000"
echo "  🗄️ Database: localhost:3306"
echo ""
echo "For production with Nginx reverse proxy:"
echo "  🌐 Frontend: https://nootnot.rocks"
echo "  🔌 API: https://api.nootnot.rocks"
echo ""
echo "To view logs: $COMPOSE_CMD logs -f [service_name]"
echo "To stop services: $COMPOSE_CMD down"
echo "To restart services: $COMPOSE_CMD restart [service_name]"
echo ""

# SSL Certificate reminder
if [ "$DEPLOY_ENV" = "production" ]; then
    echo -e "${YELLOW}📋 Production deployment checklist:${NC}"
    echo "  □ SSL certificates placed in nginx/ssl/ directory"
    echo "  □ Domain DNS pointing to this server"
    echo "  □ Firewall configured (ports 80, 443)"
    echo "  □ Environment variables configured"
    echo "  □ Database migrations applied"
    echo "  □ Image API service deployed on image-api.nootnot.rocks"
fi

print_status "Deployment script completed successfully"
