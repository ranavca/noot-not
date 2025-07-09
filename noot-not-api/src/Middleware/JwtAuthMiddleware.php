<?php

namespace App\Middleware;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface as RequestHandler;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;
use Firebase\JWT\SignatureInvalidException;

class JwtAuthMiddleware implements MiddlewareInterface
{
    private string $secretKey;

    public function __construct()
    {
        $this->secretKey = $_ENV['JWT_SECRET'] ?? 'your-secret-key-change-in-production';
    }

    public function process(Request $request, RequestHandler $handler): Response
    {
        $authHeader = $request->getHeaderLine('Authorization');
        
        if (empty($authHeader)) {
            return $this->unauthorizedResponse('Token de autorización requerido');
        }

        if (!preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $this->unauthorizedResponse('Formato de token inválido');
        }

        $token = $matches[1];

        try {
            $decoded = JWT::decode($token, new Key($this->secretKey, 'HS256'));
            
            // Add user info to request attributes
            $request = $request->withAttribute('admin_user', $decoded);
            
            return $handler->handle($request);
            
        } catch (ExpiredException $e) {
            return $this->unauthorizedResponse('Token expirado');
        } catch (SignatureInvalidException $e) {
            return $this->unauthorizedResponse('Token inválido');
        } catch (\Exception $e) {
            return $this->unauthorizedResponse('Token inválido');
        }
    }

    private function unauthorizedResponse(string $message): Response
    {
        $response = new \Slim\Psr7\Response();
        $response->getBody()->write(json_encode(['error' => $message]));
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus(401);
    }
}
