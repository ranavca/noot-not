<?php

require_once __DIR__ . '/../vendor/autoload.php';

use Slim\Factory\AppFactory;
use Dotenv\Dotenv;
use App\Middleware\CorsMiddleware;
use App\Middleware\JsonBodyParserMiddleware;
use App\Database\Connection;

// Load environment variables
$dotenv = Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

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

// Health check
$app->get('/health', function ($request, $response) {
    $response->getBody()->write(json_encode(['status' => 'ok']));
    return $response->withHeader('Content-Type', 'application/json');
});

$app->run();
