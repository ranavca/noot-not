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
    
    # Deploy in order
    deploy_main
    echo ""
    sleep 5
    
    deploy_image_api
    echo ""
    sleep 5
    
    deploy_monitoring
    
    print_status "Complete stack deployment finished"
    echo ""
    echo "🎉 Full noot-not application stack is now deployed!"
    echo ""
    echo "📋 Post-deployment checklist:"
    echo "  □ Verify SSL certificates are properly configured"
    echo "  □ Test all endpoints and functionality"
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
    
    # Test endpoints if possible
    print_info "Testing endpoints..."
    
    # Test main API
    if curl -f -s http://localhost:8000/api/health &>/dev/null; then
        print_status "Main API is responding"
    else
        print_warning "Main API is not responding on localhost:8000"
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
