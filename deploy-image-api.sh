#!/bin/bash

# Deployment script for noot-not-image-api
# This script deploys the Python image generation service on image-api.nootnot.rocks

set -e

echo "🖼️ Starting deployment of noot-not-image-api..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_ENV=${1:-production}
PROJECT_DIR=$(pwd)/noot-not-image-api

echo -e "${YELLOW}Deployment environment: $DEPLOY_ENV${NC}"
echo -e "${YELLOW}Project directory: $PROJECT_DIR${NC}"

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

# Change to image API directory
cd "$PROJECT_DIR"

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

# Check required files
echo "📋 Checking required files..."
required_files=(
    "Dockerfile"
    "docker-compose.yml"
    "requirements.txt"
    "app.py"
    "image_generator.py"
    ".env"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file $file is missing"
        exit 1
    fi
done

print_status "All required files are present"

# Check font files
echo "🔤 Checking font files..."
if [ ! -f "assets/fonts/NotoSans-Regular.ttf" ]; then
    print_warning "NotoSans-Regular.ttf not found in assets/fonts/"
fi

if [ ! -f "assets/fonts/noto-emoji-bw.ttf" ]; then
    print_warning "noto-emoji-bw.ttf not found in assets/fonts/"
fi

if [ ! -f "assets/fonts/NotoColorEmoji.ttf" ]; then
    print_warning "NotoColorEmoji.ttf not found in assets/fonts/"
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p assets/images/generated
mkdir -p assets/backgrounds
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
echo "🔨 Building and starting image API service..."
if [ "$DEPLOY_ENV" = "production" ]; then
    # Production settings
    export DEBUG=False
    export HOST=0.0.0.0
    export PORT=8001
    export PHP_API_BASE_URL=https://api.nootnot.rocks
    $COMPOSE_CMD up -d --build
else
    # Development settings
    export DEBUG=True
    export HOST=0.0.0.0
    export PORT=8001
    export PHP_API_BASE_URL=http://localhost:8000
    $COMPOSE_CMD up -d --build
fi

print_status "Image API service built and started"

# Wait for service to be ready
echo "⏳ Waiting for service to be ready..."
sleep 5

# Check if container is running
if docker ps --filter "name=noot-not-image-api" --format "{{.Names}}" | grep -q "noot-not-image-api"; then
    print_status "Container is running"
else
    print_error "Container failed to start"
    echo "Container logs:"
    docker logs noot-not-image-api --tail 20
    exit 1
fi

# Health check
echo "🏥 Performing health check..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost:8001/health &>/dev/null; then
        print_status "Health check passed"
        break
    else
        echo -n "."
        sleep 2
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    print_warning "Health check timed out"
    echo "Service logs:"
    docker logs noot-not-image-api --tail 20
fi

# Test image generation endpoint
echo "🖼️ Testing image generation..."
if curl -f -X POST http://localhost:8001/generate-images \
    -H "Content-Type: application/json" \
    -d '{"text": "Test message", "confession_id": "test-123"}' &>/dev/null; then
    print_status "Image generation endpoint is working"
else
    print_warning "Image generation endpoint test failed"
fi

# Show running containers
echo "📋 Running containers:"
docker ps --filter "name=noot-not-image-api" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Show logs
echo "📜 Recent logs:"
docker logs noot-not-image-api --tail 10

# Final status
echo ""
echo "🎉 Image API deployment completed!"
echo ""
echo "Service available at:"
echo "  🖼️ Image API: http://localhost:8001"
echo "  🏥 Health check: http://localhost:8001/health"
echo "  📊 Generate images: POST http://localhost:8001/generate-images"
echo ""

if [ "$DEPLOY_ENV" = "production" ]; then
    echo "Production URLs:"
    echo "  🖼️ Image API: https://image-api.nootnot.rocks"
    echo "  🏥 Health check: https://image-api.nootnot.rocks/health"
    echo ""
    echo -e "${YELLOW}📋 Production deployment checklist:${NC}"
    echo "  □ SSL certificate configured for image-api.nootnot.rocks"
    echo "  □ Domain DNS pointing to this server"
    echo "  □ Firewall configured (port 8001 or 443)"
    echo "  □ Environment variables configured"
    echo "  □ Font files uploaded to assets/fonts/"
    echo "  □ Background images uploaded to assets/backgrounds/"
    echo "  □ Main API service deployed and configured"
fi

echo ""
echo "Useful commands:"
echo "  📜 View logs: $COMPOSE_CMD logs -f"
echo "  🔄 Restart: $COMPOSE_CMD restart"
echo "  🛑 Stop: $COMPOSE_CMD down"
echo "  🖼️ Test generation: curl -X POST http://localhost:8001/generate-images -H 'Content-Type: application/json' -d '{\"text\":\"Hello World\",\"confession_id\":\"test\"}'"
echo ""

print_status "Image API deployment script completed successfully"
