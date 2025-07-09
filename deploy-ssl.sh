#!/bin/bash

# Remote SSL Setup Deployment Script
# This script helps deploy and run SSL setup on a remote Linux server

set -e

# Configuration - UPDATE THESE VALUES
SERVER_USER="your-username"
SERVER_IP="your-server-ip"
SERVER_PATH="/home/your-username/noot-not"
LOCAL_PROJECT_PATH="/Users/raymond/Desktop/noot-not"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Function to check if server details are configured
check_config() {
    if [[ "$SERVER_USER" == "your-username" ]] || [[ "$SERVER_IP" == "your-server-ip" ]]; then
        print_error "Please configure SERVER_USER and SERVER_IP in this script before running."
        echo ""
        echo "Edit this script and update:"
        echo "  SERVER_USER=\"your-actual-username\""
        echo "  SERVER_IP=\"your-actual-server-ip\""
        echo "  SERVER_PATH=\"/path/to/deployment/directory\""
        exit 1
    fi
}

# Function to test SSH connection
test_ssh_connection() {
    print_status "Testing SSH connection to $SERVER_USER@$SERVER_IP..."
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_IP" exit 2>/dev/null; then
        print_success "SSH connection successful"
    else
        print_error "SSH connection failed. Please check:"
        echo "  - Server IP address: $SERVER_IP"
        echo "  - Username: $SERVER_USER"
        echo "  - SSH key authentication or password"
        echo "  - Server accessibility"
        exit 1
    fi
}

# Function to sync files to server
sync_files() {
    print_status "Syncing project files to server..."
    
    # Create directory on server if it doesn't exist
    ssh "$SERVER_USER@$SERVER_IP" "mkdir -p $SERVER_PATH"
    
    # Sync files (excluding development files)
    rsync -avz --progress \
        --exclude='node_modules/' \
        --exclude='.git/' \
        --exclude='*.log' \
        --exclude='noot-not-front/dist/' \
        --exclude='noot-not-front/node_modules/' \
        --exclude='noot-not-api/vendor/' \
        "$LOCAL_PROJECT_PATH/" \
        "$SERVER_USER@$SERVER_IP:$SERVER_PATH/"
    
    print_success "Files synced successfully"
}

# Function to run SSL setup remotely
run_ssl_setup() {
    print_status "Running SSL setup on remote server..."
    
    ssh -t "$SERVER_USER@$SERVER_IP" << EOF
        cd $SERVER_PATH
        
        echo "Current directory: \$(pwd)"
        echo "Checking Docker status..."
        
        # Check if Docker is running
        if ! docker info > /dev/null 2>&1; then
            echo "Docker is not running. Attempting to start..."
            sudo systemctl start docker || {
                echo "Failed to start Docker. Please start Docker manually and try again."
                exit 1
            }
        fi
        
        echo "Making SSL setup script executable..."
        chmod +x setup-ssl.sh
        
        echo "Starting SSL setup..."
        ./setup-ssl.sh
EOF
    
    if [[ $? -eq 0 ]]; then
        print_success "SSL setup completed successfully on remote server!"
    else
        print_error "SSL setup failed. Check the output above for details."
        exit 1
    fi
}

# Function to verify SSL setup
verify_ssl() {
    print_status "Verifying SSL setup..."
    
    ssh "$SERVER_USER@$SERVER_IP" << EOF
        cd $SERVER_PATH
        chmod +x check-ssl.sh
        ./check-ssl.sh
EOF
}

# Main function
main() {
    echo "=============================================="
    echo "   Remote SSL Setup Deployment Script"
    echo "=============================================="
    echo ""
    
    # Check configuration
    check_config
    
    # Confirm with user
    echo "This script will:"
    echo "  1. Test SSH connection to $SERVER_USER@$SERVER_IP"
    echo "  2. Sync project files to $SERVER_PATH"
    echo "  3. Run SSL setup on the remote server"
    echo "  4. Verify SSL configuration"
    echo ""
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
        print_status "Deployment cancelled."
        exit 0
    fi
    
    # Run deployment steps
    test_ssh_connection
    sync_files
    run_ssl_setup
    verify_ssl
    
    echo ""
    print_success "SSL deployment completed!"
    echo ""
    print_status "Next steps:"
    echo "  1. Test your domains: https://nootnot.rocks"
    echo "  2. Verify API access: https://api.nootnot.rocks"
    echo "  3. Check certificate expiration dates"
    echo "  4. Monitor the application logs"
}

# Show usage if no arguments
if [[ $# -eq 0 ]]; then
    main
else
    case "\$1" in
        "sync")
            check_config
            test_ssh_connection
            sync_files
            ;;
        "ssl")
            check_config
            test_ssh_connection
            run_ssl_setup
            ;;
        "verify")
            check_config
            test_ssh_connection
            verify_ssl
            ;;
        *)
            echo "Usage: \$0 [sync|ssl|verify]"
            echo ""
            echo "Commands:"
            echo "  sync    - Only sync files to server"
            echo "  ssl     - Only run SSL setup"
            echo "  verify  - Only verify SSL configuration"
            echo ""
            echo "Run without arguments for full deployment"
            ;;
    esac
fi
