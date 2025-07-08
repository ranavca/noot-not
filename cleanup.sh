#!/bin/bash

# Cleanup script for noot-not project
# This script removes temporary files, generated content, and other trash

set -e

echo "🧹 Cleaning up noot-not project..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "Working in: $PROJECT_DIR"

# Clean generated images
echo "🖼️ Cleaning generated images..."
if [ -d "noot-not-image-api/assets/images" ]; then
    # Keep the directory structure but remove generated files
    find noot-not-image-api/assets/images -name "*.png" -type f -delete 2>/dev/null || true
    find noot-not-image-api/assets/images -name "*.jpg" -type f -delete 2>/dev/null || true
    find noot-not-image-api/assets/images -name "*.jpeg" -type f -delete 2>/dev/null || true
    find noot-not-image-api/assets/images -name "*.gif" -type f -delete 2>/dev/null || true
    find noot-not-image-api/assets/images -name "*.webp" -type f -delete 2>/dev/null || true
    print_status "Generated images cleaned"
else
    print_warning "Image directory not found"
fi

# Clean log files
echo "📜 Cleaning log files..."
find . -name "*.log" -type f -delete 2>/dev/null || true
find . -name "npm-debug.log*" -type f -delete 2>/dev/null || true
find . -name "yarn-debug.log*" -type f -delete 2>/dev/null || true
find . -name "yarn-error.log*" -type f -delete 2>/dev/null || true
print_status "Log files cleaned"

# Clean temporary files
echo "🗑️ Cleaning temporary files..."
find . -name "*.tmp" -type f -delete 2>/dev/null || true
find . -name "*.temp" -type f -delete 2>/dev/null || true
find . -name "*~" -type f -delete 2>/dev/null || true
find . -name "*.bak" -type f -delete 2>/dev/null || true
find . -name "*.backup" -type f -delete 2>/dev/null || true
print_status "Temporary files cleaned"

# Clean OS files
echo "💻 Cleaning OS files..."
find . -name ".DS_Store" -type f -delete 2>/dev/null || true
find . -name "Thumbs.db" -type f -delete 2>/dev/null || true
find . -name "desktop.ini" -type f -delete 2>/dev/null || true
find . -name "._*" -type f -delete 2>/dev/null || true
print_status "OS files cleaned"

# Clean Python cache
echo "🐍 Cleaning Python cache..."
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -type f -delete 2>/dev/null || true
find . -name "*.pyo" -type f -delete 2>/dev/null || true
find . -name "*.pyd" -type f -delete 2>/dev/null || true
find . -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null || true
print_status "Python cache cleaned"

# Clean Node.js cache and temporary files
echo "📦 Cleaning Node.js files..."
find . -name ".npm" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".cache" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".parcel-cache" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".eslintcache" -type f -delete 2>/dev/null || true
print_status "Node.js cache cleaned"

# Clean Docker build cache (optional)
echo "🐳 Cleaning Docker build cache..."
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        docker builder prune -f 2>/dev/null || true
        print_status "Docker build cache cleaned"
    else
        print_warning "Docker not running, skipping Docker cleanup"
    fi
else
    print_warning "Docker not installed, skipping Docker cleanup"
fi

# Clean IDE files
echo "💼 Cleaning IDE files..."
find . -name "*.swp" -type f -delete 2>/dev/null || true
find . -name "*.swo" -type f -delete 2>/dev/null || true
find . -name "*~" -type f -delete 2>/dev/null || true
print_status "IDE files cleaned"

# Clean empty directories
echo "📁 Cleaning empty directories..."
find . -type d -empty -delete 2>/dev/null || true
print_status "Empty directories cleaned"

# Create .gitkeep files for important empty directories
echo "📝 Creating .gitkeep files..."
mkdir -p noot-not-image-api/assets/images/generated
touch noot-not-image-api/assets/images/generated/.gitkeep

mkdir -p noot-not-api/public/images
touch noot-not-api/public/images/.gitkeep

mkdir -p logs
touch logs/.gitkeep

print_status ".gitkeep files created"

echo ""
echo "🎉 Cleanup completed successfully!"
echo ""
echo "Cleaned items:"
echo "  ✓ Generated images"
echo "  ✓ Log files"
echo "  ✓ Temporary files" 
echo "  ✓ OS files (.DS_Store, Thumbs.db, etc.)"
echo "  ✓ Python cache (__pycache__, *.pyc)"
echo "  ✓ Node.js cache (.npm, .cache, .eslintcache)"
echo "  ✓ Docker build cache"
echo "  ✓ IDE files (*.swp, *.swo)"
echo "  ✓ Empty directories"
echo ""
echo "📋 Next steps:"
echo "  1. Review .gitignore files"
echo "  2. Copy .env.example files to .env and configure"
echo "  3. Run 'git status' to verify clean state"
echo ""
