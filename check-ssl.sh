#!/bin/bash

# SSL Certificate Status Checker
# This script checks the status and expiry of SSL certificates

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

check_certificate_expiry() {
    local domain=$1
    print_status "Checking certificate for $domain..."
    
    # Check if domain is accessible
    if timeout 10 curl -s -I "https://$domain" > /dev/null 2>&1; then
        # Get certificate expiry date
        local expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
                           openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
        
        if [[ -n "$expiry_date" ]]; then
            local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
            local current_epoch=$(date +%s)
            local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
            
            if [[ $days_until_expiry -gt 30 ]]; then
                print_success "✓ $domain expires in $days_until_expiry days ($expiry_date)"
            elif [[ $days_until_expiry -gt 7 ]]; then
                print_warning "⚠ $domain expires in $days_until_expiry days ($expiry_date)"
            else
                print_error "⚠ $domain expires in $days_until_expiry days ($expiry_date) - RENEWAL NEEDED!"
            fi
        else
            print_error "✗ Could not get certificate expiry for $domain"
        fi
    else
        print_error "✗ $domain is not accessible via HTTPS"
    fi
}

check_docker_certificates() {
    print_status "Checking certificates in Docker volume..."
    
    if docker-compose -f docker-compose.yml -f docker-compose.ssl.yml run --rm certbot certbot certificates 2>/dev/null; then
        return 0
    else
        print_warning "Could not check certificates via Docker. Make sure the SSL setup is complete."
        return 1
    fi
}

main() {
    echo "=================================================="
    echo "     SSL Certificate Status Checker"
    echo "=================================================="
    echo ""
    
    local domains=("nootnot.rocks" "www.nootnot.rocks" "api.nootnot.rocks")
    
    # Check each domain's certificate
    for domain in "${domains[@]}"; do
        check_certificate_expiry "$domain"
    done
    
    echo ""
    echo "=================================================="
    echo "     Docker Certificate Details"
    echo "=================================================="
    echo ""
    
    # Check certificates in Docker volume
    check_docker_certificates
    
    echo ""
    print_status "To renew certificates manually, run: ./renew-ssl.sh"
}

main "$@"
