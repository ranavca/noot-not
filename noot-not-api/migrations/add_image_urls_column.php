<?php

// Migration: Add image_urls column to confessions table
// Run this file once to update the database schema

require_once __DIR__ . '/../vendor/autoload.php';

// Load environment variables
if (file_exists(__DIR__ . '/../.env')) {
    $dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
    $dotenv->load();
}

use App\Database\Connection;

try {
    $db = Connection::getInstance();
    
    // Check if column already exists (MySQL/MariaDB syntax)
    $stmt = $db->prepare("SHOW COLUMNS FROM confessions LIKE 'image_urls'");
    $stmt->execute();
    
    if ($stmt->rowCount() == 0) {
        // Add image_urls column
        $sql = "ALTER TABLE confessions ADD COLUMN image_urls JSON DEFAULT NULL";
        $db->exec($sql);
        echo "✅ Added image_urls column to confessions table\n";
    } else {
        echo "ℹ️  image_urls column already exists\n";
    }
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
