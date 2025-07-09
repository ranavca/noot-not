<?php

namespace App\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Models\Admin;
use App\Models\Confession;
use App\Services\ModerationService;
use App\Services\ImageGeneratorService;
use Firebase\JWT\JWT;

class AdminController
{
    private Admin $adminModel;
    private Confession $confessionModel;
    private ModerationService $moderationService;
    private ImageGeneratorService $imageGenerator;
    private string $jwtSecret;

    public function __construct()
    {
        $this->adminModel = new Admin();
        $this->confessionModel = new Confession();
        $this->moderationService = new ModerationService();
        $this->imageGenerator = new ImageGeneratorService();
        $this->jwtSecret = $_ENV['JWT_SECRET'] ?? 'your-secret-key-change-in-production';
    }

    // Authentication
    public function login(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            
            if (!isset($data['username']) || !isset($data['password'])) {
                return $this->jsonResponse($response, [
                    'error' => 'Usuario y contraseña requeridos'
                ], 400);
            }

            $admin = $this->adminModel->authenticate($data['username'], $data['password']);
            
            if (!$admin) {
                return $this->jsonResponse($response, [
                    'error' => 'Credenciales inválidas'
                ], 401);
            }

            // Update last login
            $this->adminModel->updateLastLogin($admin['id']);

            // Generate JWT token
            $payload = [
                'iss' => 'noot-not-admin',
                'iat' => time(),
                'exp' => time() + (24 * 60 * 60), // 24 hours
                'user_id' => $admin['id'],
                'username' => $admin['username'],
                'role' => $admin['role']
            ];

            $token = JWT::encode($payload, $this->jwtSecret, 'HS256');

            return $this->jsonResponse($response, [
                'token' => $token,
                'user' => $admin,
                'expires_in' => 24 * 60 * 60
            ]);

        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error interno del servidor'
            ], 500);
        }
    }

    // Dashboard stats
    public function getStats(Request $request, Response $response): Response
    {
        try {
            $stats = $this->confessionModel->getAdminStats();
            return $this->jsonResponse($response, $stats);
        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al obtener estadísticas'
            ], 500);
        }
    }

    // Confession management
    public function getAllConfessions(Request $request, Response $response): Response
    {
        try {
            $params = $request->getQueryParams();
            $status = $params['status'] ?? 'all';
            $page = (int)($params['page'] ?? 1);
            $limit = (int)($params['limit'] ?? 20);
            $offset = ($page - 1) * $limit;

            $confessions = $this->confessionModel->getAdminConfessions($status, $limit, $offset);
            $total = $this->confessionModel->getAdminConfessionsCount($status);

            return $this->jsonResponse($response, [
                'confessions' => $confessions,
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'total_pages' => ceil($total / $limit)
            ]);
        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al obtener confesiones'
            ], 500);
        }
    }

    public function createConfession(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            $adminUser = $request->getAttribute('admin_user');
            
            if (!isset($data['content']) || empty(trim($data['content']))) {
                return $this->jsonResponse($response, [
                    'error' => 'El contenido es requerido'
                ], 400);
            }

            $content = trim($data['content']);
            $status = $data['status'] ?? 'approved';

            $confessionId = $this->confessionModel->createAdminConfession(
                $content,
                $status,
                $adminUser->user_id
            );

            if ($confessionId && $status === 'approved') {
                // Generate images if approved
                $this->generateConfessionImages($confessionId, $content);
            }

            return $this->jsonResponse($response, [
                'message' => 'Confesión creada exitosamente',
                'confession_id' => $confessionId
            ], 201);

        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al crear confesión'
            ], 500);
        }
    }

    public function updateConfessionStatus(Request $request, Response $response, array $args): Response
    {
        try {
            $confessionId = (int)$args['id'];
            $data = $request->getParsedBody();
            $adminUser = $request->getAttribute('admin_user');
            
            if (!isset($data['status'])) {
                return $this->jsonResponse($response, [
                    'error' => 'Estado requerido'
                ], 400);
            }

            $status = $data['status'];
            $reason = $data['reason'] ?? null;

            $success = $this->confessionModel->updateStatus($confessionId, $status, $adminUser->user_id, $reason);

            if (!$success) {
                return $this->jsonResponse($response, [
                    'error' => 'Confesión no encontrada'
                ], 404);
            }

            // Generate images if approved
            if ($status === 'approved') {
                $confession = $this->confessionModel->getById($confessionId);
                if ($confession) {
                    $this->generateConfessionImages($confessionId, $confession['content']);
                }
            }

            return $this->jsonResponse($response, [
                'message' => 'Estado actualizado exitosamente'
            ]);

        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al actualizar estado'
            ], 500);
        }
    }

    public function deleteConfession(Request $request, Response $response, array $args): Response
    {
        try {
            $confessionId = (int)$args['id'];
            $adminUser = $request->getAttribute('admin_user');

            $success = $this->confessionModel->deleteById($confessionId, $adminUser->user_id);

            if (!$success) {
                return $this->jsonResponse($response, [
                    'error' => 'Confesión no encontrada'
                ], 404);
            }

            return $this->jsonResponse($response, [
                'message' => 'Confesión eliminada exitosamente'
            ]);

        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al eliminar confesión'
            ], 500);
        }
    }

    // Report management
    public function getReports(Request $request, Response $response): Response
    {
        try {
            $params = $request->getQueryParams();
            $status = $params['status'] ?? 'pending';
            $page = (int)($params['page'] ?? 1);
            $limit = (int)($params['limit'] ?? 20);
            $offset = ($page - 1) * $limit;

            $reports = $this->confessionModel->getReports($status, $limit, $offset);
            $total = $this->confessionModel->getReportsCount($status);

            return $this->jsonResponse($response, [
                'reports' => $reports,
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'total_pages' => ceil($total / $limit)
            ]);
        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al obtener reportes'
            ], 500);
        }
    }

    public function resolveReport(Request $request, Response $response, array $args): Response
    {
        try {
            $reportId = (int)$args['id'];
            $data = $request->getParsedBody();
            $adminUser = $request->getAttribute('admin_user');
            
            $action = $data['action'] ?? 'dismiss'; // 'dismiss', 'remove_confession'
            $notes = $data['notes'] ?? null;

            $success = $this->confessionModel->resolveReport($reportId, $action, $adminUser->user_id, $notes);

            if (!$success) {
                return $this->jsonResponse($response, [
                    'error' => 'Reporte no encontrado'
                ], 404);
            }

            return $this->jsonResponse($response, [
                'message' => 'Reporte resuelto exitosamente'
            ]);

        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al resolver reporte'
            ], 500);
        }
    }

    // Image management
    public function regenerateImages(Request $request, Response $response, array $args): Response
    {
        try {
            $confessionId = (int)$args['id'];
            
            $confession = $this->confessionModel->getById($confessionId);
            if (!$confession) {
                return $this->jsonResponse($response, [
                    'error' => 'Confesión no encontrada'
                ], 404);
            }

            $success = $this->generateConfessionImages($confessionId, $confession['content']);

            if ($success) {
                return $this->jsonResponse($response, [
                    'message' => 'Imágenes regeneradas exitosamente'
                ]);
            } else {
                return $this->jsonResponse($response, [
                    'error' => 'Error al regenerar imágenes'
                ], 500);
            }

        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al regenerar imágenes'
            ], 500);
        }
    }

    // User management
    public function getAdminUsers(Request $request, Response $response): Response
    {
        try {
            $users = $this->adminModel->getAllUsers();
            return $this->jsonResponse($response, ['users' => $users]);
        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al obtener usuarios'
            ], 500);
        }
    }

    public function createAdminUser(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            
            if (!isset($data['username']) || !isset($data['password'])) {
                return $this->jsonResponse($response, [
                    'error' => 'Usuario y contraseña requeridos'
                ], 400);
            }

            $role = $data['role'] ?? 'admin';
            
            $success = $this->adminModel->createUser($data['username'], $data['password'], $role);

            if ($success) {
                return $this->jsonResponse($response, [
                    'message' => 'Usuario creado exitosamente'
                ], 201);
            } else {
                return $this->jsonResponse($response, [
                    'error' => 'Error al crear usuario (posiblemente ya existe)'
                ], 400);
            }

        } catch (\Exception $e) {
            return $this->jsonResponse($response, [
                'error' => 'Error al crear usuario'
            ], 500);
        }
    }

    // Private helper methods
    private function generateConfessionImages(int $confessionId, string $content): bool
    {
        try {
            $imageUrls = $this->imageGenerator->generateImages($content);
            if (!empty($imageUrls)) {
                $this->confessionModel->updateImageUrls($confessionId, $imageUrls);
                return true;
            }
            return false;
        } catch (\Exception $e) {
            error_log("Error generating images for confession $confessionId: " . $e->getMessage());
            return false;
        }
    }

    private function jsonResponse(Response $response, array $data, int $statusCode = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus($statusCode);
    }
}