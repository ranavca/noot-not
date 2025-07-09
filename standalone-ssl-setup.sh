#!/bin/bash

# Standalone SSL Setup for Noot-Not
# This script sets up SSL certificates without relying on the main application stack

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
DOMAINS=("nootnot.rocks" "www.nootnot.rocks" "api.nootnot.rocks")
EMAIL="admin@nootnot.rocks"
WEBROOT_PATH="./nginx/webroot"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "Don't run as root. Use a regular user with sudo privileges."
    exit 1
fi

# Check Docker access
if ! docker ps &> /dev/null; then
    print_error "Docker access denied. Run: sudo usermod -aG docker \$USER && newgrp docker"
    exit 1
fi

print_status "Starting standalone SSL setup..."

# Create directories
mkdir -p "$WEBROOT_PATH"
mkdir -p "nginx/conf.d"

# Create minimal nginx for ACME challenge
print_status "Creating temporary nginx container for ACME challenge..."

cat > nginx-temp.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name nootnot.rocks www.nootnot.rocks api.nootnot.rocks;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files $uri =404;
        }
        
        location / {
            return 200 'SSL setup in progress...';
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Stop any existing nginx
docker rm -f temp-nginx 2>/dev/null || true

# Start temporary nginx
docker run -d \
    --name temp-nginx \
    -p 80:80 \
    -v "$(pwd)/nginx-temp.conf:/etc/nginx/nginx.conf:ro" \
    -v "$(pwd)/$WEBROOT_PATH:/var/www/certbot" \
    nginx:alpine

print_success "Temporary nginx started"

# Wait for nginx
sleep 5

# Test nginx
if ! curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
    print_error "Nginx is not responding"
    docker logs temp-nginx
    exit 1
fi

print_success "Nginx is responding"

# Generate certificates
print_status "Generating SSL certificates..."

# Create certbot volume
docker volume create certbot-certs 2>/dev/null || true

# Generate certificates for main domain
print_status "Obtaining certificate for nootnot.rocks and www.nootnot.rocks..."
docker run --rm \
    -v certbot-certs:/etc/letsencrypt \
    -v "$(pwd)/$WEBROOT_PATH:/var/www/certbot" \
    certbot/certbot \
    certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --domains nootnot.rocks,www.nootnot.rocks

# Generate certificate for API
print_status "Obtaining certificate for api.nootnot.rocks..."
docker run --rm \
    -v certbot-certs:/etc/letsencrypt \
    -v "$(pwd)/$WEBROOT_PATH:/var/www/certbot" \
    certbot/certbot \
    certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --domains api.nootnot.rocks

print_success "SSL certificates generated successfully!"

# Stop temporary nginx
docker rm -f temp-nginx

# Extract certificates to local directory
print_status "Extracting certificates to nginx/ssl directory..."
mkdir -p nginx/ssl

# Copy certificates from volume
docker run --rm \
    -v certbot-certs:/etc/letsencrypt \
    -v "$(pwd)/nginx/ssl:/ssl" \
    alpine \
    sh -c "
    cp -r /etc/letsencrypt/live/nootnot.rocks/* /ssl/ &&
    cp -r /etc/letsencrypt/live/api.nootnot.rocks/* /ssl/ &&
    chown -R $(id -u):$(id -g) /ssl
    "

print_success "Certificates extracted"

# Update docker-compose.yml to use SSL
print_status "Updating main docker-compose.yml for SSL..."

# Add SSL volume mount to nginx service if not already present
if ! grep -q "certbot-certs:/etc/letsencrypt" docker-compose.yml; then
    # Backup original
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
    
    # Add SSL volume to nginx service
    sed -i '/nginx:/,/networks:/{
        /volumes:/,/networks:/{
            /- \.\/nginx\/ssl:/a\
      - certbot-certs:/etc/letsencrypt:ro
        }
    }' docker-compose.yml
    
    # Add SSL volume definition
    sed -i '/^volumes:/a\
  certbot-certs:\
    external: true' docker-compose.yml
fi

# Create SSL renewal script
print_status "Creating renewal script..."
cat > renew-ssl-standalone.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting SSL renewal..."

# Renew certificates
docker run --rm \
    -v certbot-certs:/etc/letsencrypt \
    -v "$(pwd)/nginx/webroot:/var/www/certbot" \
    certbot/certbot \
    renew --quiet

# Extract renewed certificates
docker run --rm \
    -v certbot-certs:/etc/letsencrypt \
    -v "$(pwd)/nginx/ssl:/ssl" \
    alpine \
    cp -r /etc/letsencrypt/live/. /ssl/

# Reload nginx if running
if docker ps | grep -q noot-not-nginx; then
    docker exec noot-not-nginx nginx -s reload
    echo "Nginx reloaded"
fi

echo "SSL renewal completed"
EOF

chmod +x renew-ssl-standalone.sh

# Clean up
rm -f nginx-temp.conf

print_success "SSL setup completed!"
echo ""
echo "Next steps:"
echo "1. Start your main application: docker-compose up -d"
echo "2. Verify HTTPS access to your domains"
echo "3. Set up automatic renewal: add './renew-ssl-standalone.sh' to crontab"
echo ""
echo "Certificate files are in:"
echo "- Docker volume: certbot-certs"
echo "- Local copy: nginx/ssl/"
echo ""
print_status "SSL setup script completed successfully!"
