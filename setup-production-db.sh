#!/bin/bash

# Production Database Setup Script
# This script creates the missing confessions table in production

echo "🗄️  Setting up confessions table in production..."

# Check if we're running in Docker
if [ -f /.dockerenv ]; then
    echo "Running inside Docker container..."
    # Use localhost since we're inside the container
    DB_HOST="localhost"
else
    echo "Running outside Docker container..."
    # Use the database container name
    DB_HOST="noot-not-db"
fi

# Database connection details (these should match your production environment)
DB_NAME="noot_not"
DB_USER="noot_user"
DB_PASSWORD="noot_password"

echo "Connecting to database $DB_NAME on $DB_HOST..."

# Create the confessions table
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << 'EOF'
-- Create confessions table
CREATE TABLE IF NOT EXISTS confessions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    content TEXT NOT NULL,
    moderation_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    upvotes INT NOT NULL DEFAULT 0,
    downvotes INT NOT NULL DEFAULT 0,
    reports INT NOT NULL DEFAULT 0,
    image_urls JSON DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_confessions_moderation_status ON confessions(moderation_status);
CREATE INDEX IF NOT EXISTS idx_confessions_created_at ON confessions(created_at);
CREATE INDEX IF NOT EXISTS idx_confessions_upvotes ON confessions(upvotes);
CREATE INDEX IF NOT EXISTS idx_confessions_reports ON confessions(reports);
EOF

if [ $? -eq 0 ]; then
    echo "✅ Successfully created confessions table and indexes!"
else
    echo "❌ Failed to create confessions table. Please check your database connection and credentials."
    exit 1
fi

# Verify the table was created
echo "Verifying table creation..."
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "DESCRIBE confessions;"

if [ $? -eq 0 ]; then
    echo "✅ Table verification successful!"
else
    echo "❌ Table verification failed."
    exit 1
fi

echo "🎉 Database setup completed successfully!"
