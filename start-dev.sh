#!/bin/bash

# Noot Not - Development Startup Script
# This script starts both the API and frontend development servers

set -e

echo "🚀 Starting Noot Not Development Environment..."

# Check if we're in the right directory
if [ ! -d "noot-not-api" ] || [ ! -d "noot-not-front" ] || [ ! -d "noot-not-image-api" ]; then
    echo "❌ Error: Please run this script from the root directory containing noot-not-api, noot-not-front, and noot-not-image-api folders"
    exit 1
fi

# Check if PHP is installed
if ! command -v php &> /dev/null; then
    echo "❌ Error: PHP is not installed. Please install PHP to run the API."
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed. Please install Node.js to run the frontend."
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed. Please install Python 3 to run the image API."
    exit 1
fi

# Check if Composer is installed
if ! command -v composer &> /dev/null; then
    echo "❌ Error: Composer is not installed. Please install Composer to manage PHP dependencies."
    exit 1
fi

echo "📦 Installing dependencies..."

# Install API dependencies
echo "Installing API dependencies..."
cd noot-not-api
if [ ! -d "vendor" ]; then
    composer install
fi
cd ..

# Install Frontend dependencies
echo "Installing Frontend dependencies..."
cd noot-not-front
if [ ! -d "node_modules" ]; then
    npm install
fi
cd ..

# Install Image API dependencies
echo "Installing Image API dependencies..."
cd noot-not-image-api
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt
deactivate
cd ..

echo "🔧 Setting up environment..."

# Copy environment files if they don't exist
if [ ! -f "noot-not-api/.env" ]; then
    if [ -f "noot-not-api/.env.example" ]; then
        cp noot-not-api/.env.example noot-not-api/.env
        echo "📝 Created API .env file from example"
    fi
fi

if [ ! -f "noot-not-front/.env" ]; then
    echo "VITE_API_BASE_URL=http://localhost:8000/api" > noot-not-front/.env
    echo "📝 Created Frontend .env file"
fi

if [ ! -f "noot-not-image-api/.env" ]; then
    cat > noot-not-image-api/.env << EOF
# Image API Configuration
PORT=8001
HOST=0.0.0.0
DEBUG=True

# PHP API Configuration  
PHP_API_BASE_URL=http://localhost:8000

# Image Configuration
IMAGE_WIDTH=1920
IMAGE_HEIGHT=1920
FONT_SIZE=84
LINE_HEIGHT=110
MAX_LINES_PER_IMAGE=15
TEXT_MARGIN=100

# Paths
FONTS_DIR=./assets/fonts
IMAGES_DIR=./assets/images
BACKGROUND_DIR=./assets/backgrounds
EOF
    echo "📝 Created Image API .env file"
fi

echo "🚀 Starting servers..."

# Function to cleanup background processes on script exit
cleanup() {
    echo "🛑 Stopping servers..."
    kill $API_PID $FRONTEND_PID $IMAGE_API_PID 2>/dev/null || true
    exit 0
}

# Trap the cleanup function on script exit
trap cleanup EXIT INT TERM

# Start API server in background
echo "Starting API server on http://0.0.0.0:8000..."
cd noot-not-api
php -S 0.0.0.0:8000 -t public &
API_PID=$!
cd ..

# Start Image API server in background
echo "Starting Image API server on http://0.0.0.0:8001..."
cd noot-not-image-api
source venv/bin/activate
python app.py &
IMAGE_API_PID=$!
deactivate
cd ..

# Wait a bit for APIs to start
sleep 3

# Start Frontend server in background
echo "Starting Frontend server on http://localhost:5173..."
cd noot-not-front
npm run dev --host &
FRONTEND_PID=$!
cd ..

echo ""
echo "✅ All servers are starting up!"
echo ""
echo "🌐 Frontend: http://localhost:5173"
echo "🔧 API: http://localhost:8000 (accessible on network via your IP)"
echo "🖼️  Image API: http://localhost:8001"
echo ""
echo "📋 Logs will appear below. Press Ctrl+C to stop all servers."
echo "─────────────────────────────────────────────────────"

# Wait for all processes to finish
wait $API_PID $FRONTEND_PID $IMAGE_API_PID
