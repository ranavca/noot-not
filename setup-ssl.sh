#!/bin/bash

# SSL Setup Script for Noot-Not using Let's Encrypt
# This script configures SSL certificates using certbot and updates nginx configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAINS=("nootnot.rocks" "www.nootnot.rocks" "api.nootnot.rocks")
EMAIL="admin@nootnot.rocks"  # Change this to your email
NGINX_CONF_DIR="./nginx/conf.d"
SSL_DIR="./nginx/ssl"
WEBROOT_PATH="./nginx/webroot"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if script is run as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for security reasons."
        print_status "Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Function to check if required commands exist
check_dependencies() {
    print_status "Checking dependencies..."
    
    local deps=("docker" "docker-compose")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            print_error "$dep is required but not installed."
            exit 1
        fi
    done
    
    # Check Docker permissions
    if ! docker ps &> /dev/null; then
        print_warning "Docker permission issue detected. You may need to:"
        print_status "1. Add user to docker group: sudo usermod -aG docker \$USER"
        print_status "2. Logout and login again"
        print_status "3. Or run with sudo (not recommended for security)"
        
        # Try with sudo as fallback
        if sudo docker ps &> /dev/null; then
            print_warning "Will use sudo for Docker commands"
            export USE_SUDO="sudo"
        else
            print_error "Docker is not accessible even with sudo"
            exit 1
        fi
    fi
    
    print_success "All dependencies are available."
}

# Function to create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p "$SSL_DIR"
    mkdir -p "$WEBROOT_PATH"
    
    print_success "Directories created."
}

# Function to ensure Docker network exists
ensure_docker_network() {
    print_status "Ensuring Docker network exists..."
    
    # Determine docker command with sudo if needed
    local docker_cmd="docker"
    if [[ -n "${USE_SUDO:-}" ]]; then
        docker_cmd="sudo docker"
    fi
    
    # Check if network exists, create if not
    if ! $docker_cmd network ls | grep -q "noot-not-network"; then
        print_status "Creating Docker network: noot-not-network"
        $docker_cmd network create noot-not-network
        print_success "Docker network created."
    else
        print_success "Docker network already exists."
    fi
}

# Function to create temporary nginx configuration for ACME challenge
create_temp_nginx_config() {
    print_status "Creating temporary nginx configuration for ACME challenge..."
    
    cat > "$NGINX_CONF_DIR/temp-ssl.conf" << 'EOF'
# Temporary configuration for SSL certificate generation
server {
    listen 80;
    server_name nootnot.rocks www.nootnot.rocks api.nootnot.rocks;
    
    # ACME challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }
    
    # Redirect all other requests to HTTPS (will be enabled after SSL setup)
    location / {
        return 301 https://$server_name$request_uri;
    }
}
EOF
    
    print_success "Temporary nginx configuration created."
}

# Function to backup existing nginx configuration
backup_nginx_config() {
    print_status "Backing up existing nginx configuration..."
    
    if [[ -f "$NGINX_CONF_DIR/default.conf" ]]; then
        cp "$NGINX_CONF_DIR/default.conf" "$NGINX_CONF_DIR/default.conf.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Nginx configuration backed up."
    fi
}

# Function to create SSL-enabled nginx configuration
create_ssl_nginx_config() {
    print_status "Creating SSL-enabled nginx configuration..."
    
    cat > "$NGINX_CONF_DIR/default.conf" << 'EOF'
# Main frontend server
server {
    listen 80;
    server_name nootnot.rocks www.nootnot.rocks;
    
    # ACME challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }
    
    # Redirect HTTP to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name nootnot.rocks www.nootnot.rocks;

    # SSL configuration with Let's Encrypt certificates
    ssl_certificate /etc/letsencrypt/live/nootnot.rocks/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nootnot.rocks/privkey.pem;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # SSL session configuration
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozTLS:10m;
    ssl_session_tickets off;
    
    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/nootnot.rocks/chain.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Rate limiting
    limit_req zone=general burst=50 nodelay;

    # Frontend (React app)
    location / {
        proxy_pass http://frontend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # Handle client-side routing
        try_files $uri $uri/ @fallback;
    }

    location @fallback {
        proxy_pass http://frontend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
    }
}

# API server
server {
    listen 80;
    server_name api.nootnot.rocks;
    
    # ACME challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }
    
    # Redirect HTTP to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name api.nootnot.rocks;

    # SSL configuration with Let's Encrypt certificates
    ssl_certificate /etc/letsencrypt/live/api.nootnot.rocks/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.nootnot.rocks/privkey.pem;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # SSL session configuration
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozTLS:10m;
    ssl_session_tickets off;
    
    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/api.nootnot.rocks/chain.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Rate limiting for API
    limit_req zone=api burst=20 nodelay;

    # API routes
    location / {
        proxy_pass http://api:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
    }

    # Static images served by API
    location /public/images/ {
        proxy_pass http://api:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # Cache static images
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    print_success "SSL-enabled nginx configuration created."
}

# Function to create docker-compose override for certbot
create_certbot_compose() {
    print_status "Creating docker-compose override for certbot..."
    
    cat > "docker-compose.ssl.yml" << 'EOF'
services:
  nginx:
    volumes:
      - ./nginx/webroot:/var/www/certbot:ro
      - certbot-certs:/etc/letsencrypt:ro

  certbot:
    image: certbot/certbot:latest
    container_name: certbot
    volumes:
      - certbot-certs:/etc/letsencrypt
      - ./nginx/webroot:/var/www/certbot
    command: ["--version"]
    networks:
      - noot-not-network

volumes:
  certbot-certs:

networks:
  noot-not-network:
    driver: bridge
EOF
    
    print_success "Certbot docker-compose configuration created."
}

# Function to obtain SSL certificates
obtain_certificates() {
    print_status "Starting certificate generation process..."
    
    # Determine docker compose command
    local compose_cmd="docker-compose"
    if command -v "docker" &> /dev/null && docker compose version &> /dev/null 2>&1; then
        compose_cmd="docker compose"
    fi
    
    # Add sudo prefix if needed
    if [[ -n "${USE_SUDO:-}" ]]; then
        compose_cmd="sudo $compose_cmd"
    fi
    
    # Start nginx with temporary configuration
    print_status "Starting nginx for ACME challenge..."
    create_temp_nginx_config
    
    # Stop any existing containers first
    $compose_cmd -f docker-compose.yml -f docker-compose.ssl.yml down || true
    
    # Start nginx service
    $compose_cmd -f docker-compose.yml -f docker-compose.ssl.yml up -d nginx
    
    # Wait for nginx to be ready
    sleep 15
    
    # Obtain certificate for main domain (with www subdomain)
    print_status "Obtaining certificate for nootnot.rocks and www.nootnot.rocks..."
    $compose_cmd -f docker-compose.yml -f docker-compose.ssl.yml run --rm certbot \
        certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d nootnot.rocks \
        -d www.nootnot.rocks
    
    # Obtain certificate for API subdomain
    print_status "Obtaining certificate for api.nootnot.rocks..."
    $compose_cmd -f docker-compose.yml -f docker-compose.ssl.yml run --rm certbot \
        certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d api.nootnot.rocks
    
    print_success "SSL certificates obtained successfully!"
}

# Function to test nginx configuration
test_nginx_config() {
    print_status "Testing nginx configuration..."
    
    if docker-compose -f docker-compose.yml -f docker-compose.ssl.yml exec nginx nginx -t; then
        print_success "Nginx configuration is valid."
        return 0
    else
        print_error "Nginx configuration test failed."
        return 1
    fi
}

# Function to reload nginx
reload_nginx() {
    print_status "Reloading nginx..."
    
    if docker-compose -f docker-compose.yml -f docker-compose.ssl.yml exec nginx nginx -s reload; then
        print_success "Nginx reloaded successfully."
    else
        print_error "Failed to reload nginx."
        return 1
    fi
}

# Function to create certificate renewal script
create_renewal_script() {
    print_status "Creating certificate renewal script..."
    
    cat > "renew-ssl.sh" << 'EOF'
#!/bin/bash

# SSL Certificate Renewal Script
# Run this script periodically (e.g., via cron) to renew certificates

set -e

echo "Starting SSL certificate renewal..."

# Renew certificates
docker-compose -f docker-compose.yml -f docker-compose.ssl.yml run --rm certbot \
    certbot renew --quiet

# Reload nginx if certificates were renewed
if [ $? -eq 0 ]; then
    echo "Certificates renewed successfully. Reloading nginx..."
    docker-compose -f docker-compose.yml -f docker-compose.ssl.yml exec nginx nginx -s reload
    echo "Nginx reloaded."
else
    echo "Certificate renewal failed."
    exit 1
fi

echo "SSL certificate renewal completed."
EOF
    
    chmod +x "renew-ssl.sh"
    print_success "Certificate renewal script created: renew-ssl.sh"
}

# Function to create cron job for automatic renewal
setup_auto_renewal() {
    print_status "Setting up automatic certificate renewal..."
    
    local cron_job="0 3 * * * cd $(pwd) && ./renew-ssl.sh >> /var/log/letsencrypt-renewal.log 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "renew-ssl.sh"; then
        print_warning "Cron job for SSL renewal already exists."
    else
        # Add cron job
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        print_success "Automatic renewal cron job added (runs daily at 3 AM)."
    fi
}

# Function to verify SSL setup
verify_ssl_setup() {
    print_status "Verifying SSL setup..."
    
    local domains=("nootnot.rocks" "www.nootnot.rocks" "api.nootnot.rocks")
    
    for domain in "${domains[@]}"; do
        print_status "Checking SSL certificate for $domain..."
        
        # Wait a moment for the domain to be accessible
        sleep 5
        
        if curl -s -I "https://$domain" | grep -q "HTTP/[12]"; then
            print_success "✓ $domain is accessible via HTTPS"
        else
            print_warning "⚠ $domain may not be accessible via HTTPS yet"
            print_status "  This might be normal if DNS is still propagating"
        fi
    done
}

# Function to show SSL status
show_ssl_status() {
    print_status "SSL Certificate Status:"
    echo ""
    
    docker-compose -f docker-compose.yml -f docker-compose.ssl.yml run --rm certbot \
        certbot certificates
}

# Main function
main() {
    echo "=================================================="
    echo "  SSL Setup Script for Noot-Not using Let's Encrypt"
    echo "=================================================="
    echo ""
    
    # Validate email
    read -p "Enter your email address for Let's Encrypt notifications [$EMAIL]: " input_email
    if [[ -n "$input_email" ]]; then
        EMAIL="$input_email"
    fi
    
    # Confirm domains
    echo ""
    print_status "The following domains will be configured:"
    for domain in "${DOMAINS[@]}"; do
        echo "  - $domain"
    done
    echo ""
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "SSL setup cancelled."
        exit 0
    fi
    
    # Run setup steps
    check_root
    check_dependencies
    create_directories
    ensure_docker_network
    backup_nginx_config
    create_certbot_compose
    obtain_certificates
    create_ssl_nginx_config
    
    # Test and reload nginx
    if test_nginx_config; then
        reload_nginx
    else
        print_error "Nginx configuration test failed. Please check the configuration."
        exit 1
    fi
    
    # Create renewal script and setup auto-renewal
    create_renewal_script
    setup_auto_renewal
    
    # Verify setup
    verify_ssl_setup
    
    echo ""
    print_success "SSL setup completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Verify that your domains are accessible via HTTPS"
    echo "2. Check certificate status with: docker-compose -f docker-compose.yml -f docker-compose.ssl.yml run --rm certbot certbot certificates"
    echo "3. Test automatic renewal with: ./renew-ssl.sh"
    echo ""
    print_status "Automatic renewal is set up to run daily at 3 AM."
    print_status "You can also manually renew certificates by running: ./renew-ssl.sh"
    
    # Show current certificate status
    echo ""
    show_ssl_status
}

# Run main function
main "$@"
