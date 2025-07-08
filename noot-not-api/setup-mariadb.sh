#!/bin/bash

# Noot Not - MariaDB Setup Script
# This script helps set up MariaDB for the Noot Not application

echo "🗄️  Setting up MariaDB for Noot Not..."

# Check if MariaDB is installed
if ! command -v mysql &> /dev/null && ! command -v mariadb &> /dev/null; then
    echo "❌ MariaDB/MySQL is not installed."
    echo "Please install MariaDB first:"
    echo ""
    echo "On macOS (with Homebrew):"
    echo "  brew install mariadb"
    echo "  brew services start mariadb"
    echo ""
    echo "On Ubuntu/Debian:"
    echo "  sudo apt update"
    echo "  sudo apt install mariadb-server"
    echo "  sudo systemctl start mariadb"
    echo ""
    echo "On CentOS/RHEL:"
    echo "  sudo yum install mariadb-server"
    echo "  sudo systemctl start mariadb"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "composer.json" ]; then
    echo "❌ Please run this script from the noot-not-api directory"
    exit 1
fi

echo "📋 Setting up database..."

# Database configuration
DB_NAME="noot_not"
DB_USER="noot_user"
DB_PASSWORD="noot_password"

# Create database and user
echo "Creating database and user..."
mysql -u root -p <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo "✅ Database and user created successfully!"
    
    # Create .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        echo "📝 Creating .env file..."
        cat > .env <<EOF
# Database Configuration (MariaDB/MySQL)
DB_HOST=localhost
DB_PORT=3306
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# OpenAI API Key (optional for content moderation)
OPENAI_API_KEY=
EOF
        echo "✅ Created .env file with database configuration"
    else
        echo "ℹ️  .env file already exists, please update it manually if needed"
    fi
    
    # Run migrations
    echo "🚀 Running database migrations..."
    php migrations/run.php
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "🎉 MariaDB setup completed successfully!"
        echo ""
        echo "📋 Database Details:"
        echo "  Database: ${DB_NAME}"
        echo "  User: ${DB_USER}"
        echo "  Password: ${DB_PASSWORD}"
        echo ""
        echo "🚀 You can now start the application with:"
        echo "  cd .. && ./start-dev.sh"
    else
        echo "❌ Migration failed. Please check the error messages above."
        exit 1
    fi
else
    echo "❌ Failed to create database. Please check your MariaDB installation and try again."
    exit 1
fi
