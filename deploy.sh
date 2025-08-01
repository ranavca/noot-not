#!/bin/bash

# Master deployment script for noot-not application
# This script can deploy to either the main server or image API server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ENV=${2:-production}

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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <deployment-target> [environment]"
    echo ""
    echo "Deployment targets:"
    echo "  main        Deploy main server (API + Frontend + Database)"
    echo "  image-api   Deploy image API server"
    echo "  ssl         Setup Let's Encrypt SSL certificates"
    echo "  monitoring  Deploy monitoring stack (optional)"
    echo "  all         Deploy everything (requires specific setup)"
    echo ""
    echo "Environment options:"
    echo "  production  Production deployment (default)"
    echo "  development Development deployment"
    echo ""
    echo "Examples:"
    echo "  $0 main production"
    echo "  $0 image-api"
    echo "  $0 ssl"
    echo "  $0 monitoring"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "Run: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
        exit 1
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi

    print_status "Prerequisites check passed"
}

# Function to deploy main server
deploy_main() {
    print_info "Deploying main server (API + Frontend + Database)..."
    
    # Check if deployment script exists
    if [ ! -f "$SCRIPT_DIR/deploy-main.sh" ]; then
        print_error "Main deployment script not found at $SCRIPT_DIR/deploy-main.sh"
        exit 1
    fi

    # Run main deployment script
    bash "$SCRIPT_DIR/deploy-main.sh" "$DEPLOY_ENV"
    
    if [ $? -eq 0 ]; then
        print_status "Main server deployment completed successfully"
        echo ""
        echo "🌐 Services available at:"
        echo "  Frontend: https://nootnot.rocks (or http://localhost:3000)"
        echo "  API: https://api.nootnot.rocks (or http://localhost:8000)"
        echo "  Database: localhost:3306"
    else
        print_error "Main server deployment failed"
        exit 1
    fi
}

# Function to deploy image API
deploy_image_api() {
    print_info "Deploying image API server..."
    
    # Check if deployment script exists
    if [ ! -f "$SCRIPT_DIR/deploy-image-api.sh" ]; then
        print_error "Image API deployment script not found at $SCRIPT_DIR/deploy-image-api.sh"
        exit 1
    fi

    # Run image API deployment script
    bash "$SCRIPT_DIR/deploy-image-api.sh" "$DEPLOY_ENV"
    
    if [ $? -eq 0 ]; then
        print_status "Image API deployment completed successfully"
        echo ""
        echo "🖼️ Image API available at:"
        echo "  Service: https://image-api.nootnot.rocks (or http://localhost:8001)"
        echo "  Health: https://image-api.nootnot.rocks/health"
    else
        print_error "Image API deployment failed"
        exit 1
    fi
}

# Function to setup SSL certificates
deploy_ssl() {
    print_info "Setting up Let's Encrypt SSL certificates..."
    
    # SSL Configuration
    DOMAINS=("nootnot.rocks" "www.nootnot.rocks" "api.nootnot.rocks" "image-api.nootnot.rocks")
    EMAIL="admin@nootnot.rocks"
    WEBROOT_PATH="./nginx/webroot"
    
    # Check if SSL setup script exists
    if [ -f "$SCRIPT_DIR/setup-ssl.sh" ]; then
        print_info "Using existing SSL setup script..."
        bash "$SCRIPT_DIR/setup-ssl.sh"
        return $?
    fi
    
    # Inline SSL setup if script doesn't exist
    print_info "Running inline SSL setup..."
    
    # Check Docker access
    if ! docker ps &> /dev/null; then
        print_error "Docker access denied. Please ensure Docker is running and user has permissions."
        echo "Run: sudo usermod -aG docker \$USER && newgrp docker"
        exit 1
    fi
    
    # Create directories
    mkdir -p "$WEBROOT_PATH"
    mkdir -p "nginx/conf.d"
    mkdir -p "nginx/ssl"
    
    # Create temporary nginx for ACME challenge
    print_info "Creating temporary nginx container for ACME challenge..."
    
    cat > nginx-temp.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name nootnot.rocks www.nootnot.rocks api.nootnot.rocks image-api.nootnot.rocks;
        
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
NGINX_EOF
    
    # Stop any existing temporary containers
    docker rm -f temp-nginx 2>/dev/null || true
    docker rm -f certbot-temp 2>/dev/null || true
    
    # Start temporary nginx
    docker run -d \
        --name temp-nginx \
        -p 80:80 \
        -v "$(pwd)/nginx-temp.conf:/etc/nginx/nginx.conf:ro" \
        -v "$(pwd)/$WEBROOT_PATH:/var/www/certbot" \
        nginx:alpine
    
    print_status "Temporary nginx started, waiting for it to be ready..."
    sleep 5
    
    # Test if nginx is responding
    if ! curl -f -s http://localhost/.well-known/acme-challenge/test &>/dev/null; then
        print_warning "ACME challenge endpoint might not be ready, continuing anyway..."
    fi
    
    # Obtain certificates for all domains
    print_info "Obtaining SSL certificates from Let's Encrypt..."
    
    # Create domain string for certbot
    DOMAIN_STRING=""
    for domain in "${DOMAINS[@]}"; do
        DOMAIN_STRING="$DOMAIN_STRING -d $domain"
    done
    
    # Run certbot
    docker run --rm \
        -v "$(pwd)/nginx/ssl:/etc/letsencrypt" \
        -v "$(pwd)/$WEBROOT_PATH:/var/www/certbot" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        $DOMAIN_STRING
    
    if [ $? -eq 0 ]; then
        print_status "SSL certificates obtained successfully"
        
        # Create SSL nginx configuration
        print_info "Creating SSL nginx configuration..."
        
        cat > nginx/conf.d/ssl.conf << 'SSL_CONF_EOF'
# SSL Configuration for noot-not
server {
    listen 80;
    server_name nootnot.rocks www.nootnot.rocks api.nootnot.rocks image-api.nootnot.rocks;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Main site HTTPS
server {
    listen 443 ssl http2;
    server_name nootnot.rocks www.nootnot.rocks;
    
    ssl_certificate /etc/letsencrypt/live/nootnot.rocks/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nootnot.rocks/privkey.pem;
    
    # SSL Security Headers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    location / {
        proxy_pass http://noot-not-front:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# API HTTPS
server {
    listen 443 ssl http2;
    server_name api.nootnot.rocks;
    
    ssl_certificate /etc/letsencrypt/live/nootnot.rocks/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nootnot.rocks/privkey.pem;
    
    # SSL Security Headers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    location / {
        proxy_pass http://noot-not-api:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Image API HTTPS
server {
    listen 443 ssl http2;
    server_name image-api.nootnot.rocks;
    
    ssl_certificate /etc/letsencrypt/live/nootnot.rocks/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nootnot.rocks/privkey.pem;
    
    # SSL Security Headers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    location / {
        proxy_pass http://host.docker.internal:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
SSL_CONF_EOF
        
        print_status "SSL configuration created"
        
        # Stop temporary nginx
        docker rm -f temp-nginx 2>/dev/null || true
        
        # Clean up temp files
        rm -f nginx-temp.conf
        
        print_status "SSL setup completed successfully"
        echo ""
        echo "🔒 SSL certificates installed for:"
        for domain in "${DOMAINS[@]}"; do
            echo "  ✓ $domain"
        done
        echo ""
        echo "📋 Next steps:"
        echo "  1. Deploy your main application with SSL support"
        echo "  2. Update docker-compose.yml to use SSL configuration"
        echo "  3. Set up certificate renewal (certbot renew)"
        echo ""
        
        # Check SSL certificate validity
        print_info "Checking certificate validity..."
        if [ -f "nginx/ssl/live/nootnot.rocks/fullchain.pem" ]; then
            CERT_EXPIRY=$(openssl x509 -enddate -noout -in nginx/ssl/live/nootnot.rocks/fullchain.pem | cut -d= -f2)
            print_status "Certificate expires: $CERT_EXPIRY"
        fi
        
    else
        print_error "SSL certificate generation failed"
        docker rm -f temp-nginx 2>/dev/null || true
        rm -f nginx-temp.conf
        exit 1
    fi
}

# Function to deploy monitoring
deploy_monitoring() {
    print_info "Deploying monitoring stack..."
    
    # Check if monitoring compose file exists
    if [ ! -f "$SCRIPT_DIR/docker-compose.monitoring.yml" ]; then
        print_error "Monitoring compose file not found at $SCRIPT_DIR/docker-compose.monitoring.yml"
        exit 1
    fi

    # Create monitoring configuration directory
    mkdir -p "$SCRIPT_DIR/monitoring"
    
    # Create basic Prometheus config if it doesn't exist
    if [ ! -f "$SCRIPT_DIR/monitoring/prometheus.yml" ]; then
        cat > "$SCRIPT_DIR/monitoring/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'noot-not-api'
    static_configs:
      - targets: ['host.docker.internal:8000']
    metrics_path: '/metrics'

  - job_name: 'noot-not-image-api'
    static_configs:
      - targets: ['host.docker.internal:8001']
    metrics_path: '/metrics'
EOF
    fi

    # Create basic Alertmanager config if it doesn't exist
    if [ ! -f "$SCRIPT_DIR/monitoring/alertmanager.yml" ]; then
        cat > "$SCRIPT_DIR/monitoring/alertmanager.yml" << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@nootnot.rocks'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'admin@nootnot.rocks'
    subject: 'noot-not Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF
    fi

    # Deploy monitoring stack
    docker-compose -f "$SCRIPT_DIR/docker-compose.monitoring.yml" up -d --build
    
    if [ $? -eq 0 ]; then
        print_status "Monitoring stack deployment completed successfully"
        echo ""
        echo "📊 Monitoring services available at:"
        echo "  Grafana: http://localhost:3001 (admin/admin123)"
        echo "  Prometheus: http://localhost:9090"
        echo "  AlertManager: http://localhost:9093"
        echo "  Node Exporter: http://localhost:9100"
        echo "  cAdvisor: http://localhost:8080"
    else
        print_error "Monitoring deployment failed"
        exit 1
    fi
}

# Function to deploy everything
deploy_all() {
    print_info "Deploying complete noot-not stack..."
    print_warning "This requires careful coordination between servers!"
    
    echo ""
    read -p "Are you sure you want to deploy the complete stack? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    # Ask about SSL setup
    echo ""
    read -p "Do you want to set up SSL certificates? (y/N): " -n 1 -r
    echo
    SETUP_SSL=$REPLY
    
    # Deploy in order
    deploy_main
    echo ""
    sleep 5
    
    deploy_image_api
    echo ""
    sleep 5
    
    # Setup SSL if requested
    if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
        deploy_ssl
        echo ""
        sleep 5
    fi
    
    deploy_monitoring
    
    print_status "Complete stack deployment finished"
    echo ""
    echo "🎉 Full noot-not application stack is now deployed!"
    echo ""
    if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
        echo "🔒 SSL certificates have been configured"
        echo ""
    fi
    echo "📋 Post-deployment checklist:"
    if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
        echo "  ✓ SSL certificates are configured"
        echo "  □ Set up SSL certificate auto-renewal"
    else
        echo "  □ Set up SSL certificates (run: $0 ssl)"
    fi
    echo "  □ Verify all endpoints and functionality"
    echo "  □ Configure monitoring alerts"
    echo "  □ Set up backup procedures"
    echo "  □ Configure firewall rules"
    echo "  □ Update DNS records if needed"
}

# Function to show status
show_status() {
    print_info "Checking deployment status..."
    echo ""
    
    # Check main server containers
    echo "Main server containers:"
    docker ps --filter "name=noot-not" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No main server containers found"
    echo ""
    
    # Check image API containers
    echo "Image API containers:"
    docker ps --filter "name=noot-not-image-api" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No image API containers found"
    echo ""
    
    # Check monitoring containers
    echo "Monitoring containers:"
    docker ps --filter "name=noot-not-prometheus" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No monitoring containers found"
    echo ""
    
    # Check SSL certificates
    print_info "Checking SSL certificates..."
    if [ -f "nginx/ssl/live/nootnot.rocks/fullchain.pem" ]; then
        CERT_EXPIRY=$(openssl x509 -enddate -noout -in nginx/ssl/live/nootnot.rocks/fullchain.pem 2>/dev/null | cut -d= -f2 || echo "Unable to read certificate")
        print_status "SSL certificate found - expires: $CERT_EXPIRY"
        
        # Check certificate validity (days remaining)
        if command -v openssl &> /dev/null; then
            DAYS_REMAINING=$(openssl x509 -checkend 86400 -noout -in nginx/ssl/live/nootnot.rocks/fullchain.pem 2>/dev/null && echo "Valid for more than 1 day" || echo "Expires within 24 hours!")
            echo "  Certificate status: $DAYS_REMAINING"
        fi
    else
        print_warning "SSL certificates not found. Run: $0 ssl"
    fi
    echo ""
    
    # Test endpoints if possible
    print_info "Testing endpoints..."
    
    # Test main API
    if curl -f -s http://localhost:8000/api/health &>/dev/null; then
        print_status "Main API is responding (HTTP)"
    else
        print_warning "Main API is not responding on localhost:8000"
    fi
    
    # Test HTTPS if SSL is configured
    if [ -f "nginx/ssl/live/nootnot.rocks/fullchain.pem" ]; then
        if curl -f -s -k https://localhost/api/health &>/dev/null; then
            print_status "Main API is responding (HTTPS)"
        else
            print_warning "Main API HTTPS is not responding"
        fi
    fi
    
    # Test frontend
    if curl -f -s http://localhost:3000 &>/dev/null; then
        print_status "Frontend is responding"
    else
        print_warning "Frontend is not responding on localhost:3000"
    fi
    
    # Test image API
    if curl -f -s http://localhost:8001/health &>/dev/null; then
        print_status "Image API is responding"
    else
        print_warning "Image API is not responding on localhost:8001"
    fi
}

# Main script logic
main() {
    echo "🚀 noot-not Deployment Manager"
    echo "=============================="
    
    case "$1" in
        "main")
            check_prerequisites
            deploy_main
            ;;
        "image-api")
            check_prerequisites
            deploy_image_api
            ;;
        "ssl")
            check_prerequisites
            deploy_ssl
            ;;
        "monitoring")
            check_prerequisites
            deploy_monitoring
            ;;
        "all")
            check_prerequisites
            deploy_all
            ;;
        "status")
            show_status
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
