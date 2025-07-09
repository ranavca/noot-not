<?php

require_once __DIR__ . '/../vendor/autoload.php';

use Slim\Factory\AppFactory;
use Dotenv\Dotenv;
use App\Middleware\CorsMiddleware;
use App\Middleware\JsonBodyParserMiddleware;
use App\Database\Connection;

// Load environment variables
try {
    $dotenv = Dotenv::createImmutable(__DIR__ . '/..');
    $dotenv->load();
} catch (Exception $e) {
    // In production, environment variables should be set by Docker
    // This fallback allows the app to work without a .env file
}

// Create Slim app
$app = AppFactory::create();

// Add error middleware
$app->addErrorMiddleware(true, true, true);

// Add CORS middleware
$app->add(new CorsMiddleware());

// Add JSON body parser middleware
$app->add(new JsonBodyParserMiddleware());

// Routes
$app->group('/api', function ($group) {
    $group->post('/confessions', '\App\Controllers\ConfessionController:create');
    $group->get('/confessions', '\App\Controllers\ConfessionController:list');
    $group->post('/confessions/{id}/vote', '\App\Controllers\ConfessionController:vote');
    $group->post('/confessions/{id}/report', '\App\Controllers\ConfessionController:report');
    $group->post('/confessions/{id}/update-images', '\App\Controllers\ConfessionController:updateImages');
});

// Handle preflight OPTIONS requests
$app->options('/{routes:.+}', function ($request, $response) {
    return $response;
});

// Health check
$app->get('/health', function ($request, $response) {
    $health = ['status' => 'ok', 'timestamp' => date('c')];
    
    try {
        // Check database connection
        $db = \App\Database\Connection::getInstance();
        $stmt = $db->query('SELECT 1');
        if ($stmt) {
            $health['database'] = 'connected';
        } else {
            $health['database'] = 'error';
            $health['status'] = 'degraded';
        }
    } catch (Exception $e) {
        $health['database'] = 'error';
        $health['database_error'] = $e->getMessage();
        $health['status'] = 'degraded';
    }
    
    $statusCode = ($health['status'] === 'ok') ? 200 : 503;
    $response->getBody()->write(json_encode($health));
    return $response->withHeader('Content-Type', 'application/json')->withStatus($statusCode);
});

$app->run();
