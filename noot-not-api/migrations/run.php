<?php

require_once __DIR__ . '/../vendor/autoload.php';

use Dotenv\Dotenv;

// Load environment variables
$dotenv = Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

try {
    $host = $_ENV['DB_HOST'] ?? 'localhost';
    $port = $_ENV['DB_PORT'] ?? '3306';
    $dbname = $_ENV['DB_NAME'] ?? 'noot_not';
    $username = $_ENV['DB_USER'] ?? 'noot_user';
    $password = $_ENV['DB_PASSWORD'] ?? 'noot_password';

    echo "Connecting to database: {$host}:{$port}/{$dbname} as {$username}\n";

    $dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset=utf8mb4";
    
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
    ]);

    echo "Running migrations...\n";

    // Create confessions table
    $sql = "
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
    ";

    $pdo->exec($sql);
    echo "✓ Created confessions table\n";

    // Create indexes for better performance
    $indexes = [
        "CREATE INDEX IF NOT EXISTS idx_confessions_moderation_status ON confessions(moderation_status);",
        "CREATE INDEX IF NOT EXISTS idx_confessions_created_at ON confessions(created_at);",
        "CREATE INDEX IF NOT EXISTS idx_confessions_upvotes ON confessions(upvotes);",
        "CREATE INDEX IF NOT EXISTS idx_confessions_reports ON confessions(reports);",
    ];

    foreach ($indexes as $index) {
        $pdo->exec($index);
    }
    echo "✓ Created indexes\n";

    // Run admin dashboard migration
    $adminMigrationPath = __DIR__ . '/002_admin_dashboard.sql';
    if (file_exists($adminMigrationPath)) {
        $adminSql = file_get_contents($adminMigrationPath);
        
        // Split by semicolon and execute each statement
        $statements = array_filter(array_map('trim', explode(';', $adminSql)));
        
        foreach ($statements as $statement) {
            if (!empty($statement)) {
                try {
                    $pdo->exec($statement);
                } catch (PDOException $e) {
                    // Ignore errors for statements that might already exist
                    if (strpos($e->getMessage(), 'already exists') === false && 
                        strpos($e->getMessage(), 'Duplicate') === false) {
                        echo "Warning: " . $e->getMessage() . "\n";
                    }
                }
            }
        }
        echo "✓ Admin dashboard migration completed\n";
    }

    echo "All migrations completed successfully!\n";

} catch (PDOException $e) {
    echo "Migration failed: " . $e->getMessage() . "\n";
    exit(1);
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
