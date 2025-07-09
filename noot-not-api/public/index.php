<?php

require_once __DIR__ . '/../vendor/autoload.php';

use Slim\Factory\AppFactory;
use Dotenv\Dotenv;
use App\Middleware\CorsMiddleware;
use App\Middleware\JsonBodyParserMiddleware;
use App\Middleware\JwtAuthMiddleware;
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

// Handle preflight OPTIONS requests first
$app->options('/{routes:.+}', function ($request, $response) {
    return $response;
});

// Routes
$app->group('/api', function ($group) {
    $group->post('/confessions', '\App\Controllers\ConfessionController:create');
    $group->get('/confessions', '\App\Controllers\ConfessionController:list');
    $group->post('/confessions/{id}/vote', '\App\Controllers\ConfessionController:vote');
    $group->post('/confessions/{id}/report', '\App\Controllers\ConfessionController:report');
    $group->post('/confessions/{id}/update-images', '\App\Controllers\ConfessionController:updateImages');
});

// Admin routes (protected by JWT)
$app->group('/api/admin', function ($group) {
    // Authentication
    $group->post('/login', '\App\Controllers\AdminController:login');
    
    // Dashboard and stats (protected routes)
    $group->group('', function ($subGroup) {
        $subGroup->get('/stats', '\App\Controllers\AdminController:getStats');
        
        // Confession management
        $subGroup->get('/confessions', '\App\Controllers\AdminController:getAllConfessions');
        $subGroup->post('/confessions', '\App\Controllers\AdminController:createConfession');
        $subGroup->put('/confessions/{id}/status', '\App\Controllers\AdminController:updateConfessionStatus');
        $subGroup->delete('/confessions/{id}', '\App\Controllers\AdminController:deleteConfession');
        $subGroup->post('/confessions/{id}/regenerate-images', '\App\Controllers\AdminController:regenerateImages');
        
        // Report management
        $subGroup->get('/reports', '\App\Controllers\AdminController:getReports');
        $subGroup->put('/reports/{id}/resolve', '\App\Controllers\AdminController:resolveReport');
        
        // User management
        $subGroup->get('/users', '\App\Controllers\AdminController:getAdminUsers');
        $subGroup->post('/users', '\App\Controllers\AdminController:createAdminUser');
        
    })->add(new JwtAuthMiddleware());
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
