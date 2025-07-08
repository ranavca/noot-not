<?php

namespace App\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Models\Confession;
use App\Services\ModerationService;

class ConfessionController
{
    private Confession $confessionModel;
    private ModerationService $moderationService;
    private string $imageApiUrl;

    public function __construct()
    {
        $this->confessionModel = new Confession();
        $this->moderationService = new ModerationService();
        $this->imageApiUrl = $_ENV['IMAGE_API_URL'] ?? 'http://localhost:8001';
    }

    public function create(Request $request, Response $response): Response
    {
        try {
            $data = $request->getParsedBody();
            
            if (!isset($data['content']) || empty(trim($data['content']))) {
                return $this->jsonResponse($response, [
                    'error' => 'El contenido es requerido'
                ], 400);
            }

            $content = trim($data['content']);
            
            // Content length validation
            if (strlen($content) < 10) {
                return $this->jsonResponse($response, [
                    'error' => 'El contenido debe tener al menos 10 caracteres'
                ], 400);
            }

            if (strlen($content) > 1000) {
                return $this->jsonResponse($response, [
                    'error' => 'El contenido debe tener menos de 1000 caracteres'
                ], 400);
            }

            // Moderate content
            $moderationResult = $this->moderationService->moderateContent($content);
            
            if ($moderationResult['status'] === 'rejected') {
                return $this->jsonResponse($response, [
                    'error' => '¡Hey! Relajate, no puedes publicar eso.',
                    'reason' => $moderationResult['reason']
                ], 400);
            }

            // Create confession
            $confession = $this->confessionModel->create($content, $moderationResult['status']);
            
            // Trigger image generation for approved confessions via webhook
            if ($moderationResult['status'] === 'approved') {
                $this->triggerImageGeneration($confession['id'], $content);
            }
            
            return $this->jsonResponse($response, [
                'message' => 'Confesión creada exitosamente',
                'confession' => $confession
            ], 201);

        } catch (\Exception $e) {
            error_log('Error creating confession: ' . $e->getMessage());
            return $this->jsonResponse($response, [
                'error' => 'Error interno del servidor'
            ], 500);
        }
    }

    public function list(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            
            $page = max(1, (int)($queryParams['page'] ?? 1));
            $limit = min(50, max(1, (int)($queryParams['limit'] ?? 20)));
            $sort = in_array($queryParams['sort'] ?? '', ['created_at', 'upvotes']) 
                ? $queryParams['sort'] 
                : 'created_at';

            $confessions = $this->confessionModel->getAll($page, $limit, $sort);
            $total = $this->confessionModel->getTotalCount();
            
            $totalPages = ceil($total / $limit);
            
            return $this->jsonResponse($response, [
                'confessions' => $confessions,
                'pagination' => [
                    'current_page' => $page,
                    'total_pages' => $totalPages,
                    'total_items' => $total,
                    'items_per_page' => $limit
                ]
            ]);

        } catch (\Exception $e) {
            error_log('Error listing confessions: ' . $e->getMessage());
            return $this->jsonResponse($response, [
                'error' => 'Error interno del servidor'
            ], 500);
        }
    }

    public function vote(Request $request, Response $response): Response
    {
        try {
            $id = $request->getAttribute('id');
            $data = $request->getParsedBody();
            
            if (!isset($data['type']) || !in_array($data['type'], ['upvote', 'downvote'])) {
                return $this->jsonResponse($response, [
                    'error' => 'El tipo de voto debe ser "upvote" o "downvote"'
                ], 400);
            }

            // Check if confession exists
            $confession = $this->confessionModel->findById($id);
            if (!$confession) {
                return $this->jsonResponse($response, [
                    'error' => 'Confesión no encontrada'
                ], 404);
            }

            if ($confession['moderation_status'] !== 'approved') {
                return $this->jsonResponse($response, [
                    'error' => 'No se puede votar en esta confesión'
                ], 400);
            }

            $success = $this->confessionModel->vote($id, $data['type']);
            
            if (!$success) {
                return $this->jsonResponse($response, [
                    'error' => 'Error al registrar el voto'
                ], 500);
            }

            // Get updated confession
            $updatedConfession = $this->confessionModel->findById($id);
            
            return $this->jsonResponse($response, [
                'message' => 'Voto registrado exitosamente',
                'confession' => $updatedConfession
            ]);

        } catch (\Exception $e) {
            error_log('Error voting on confession: ' . $e->getMessage());
            return $this->jsonResponse($response, [
                'error' => 'Error interno del servidor'
            ], 500);
        }
    }

    public function report(Request $request, Response $response): Response
    {
        try {
            $id = $request->getAttribute('id');
            
            // Check if confession exists
            $confession = $this->confessionModel->findById($id);
            if (!$confession) {
                return $this->jsonResponse($response, [
                    'error' => 'Confesión no encontrada'
                ], 404);
            }

            $success = $this->confessionModel->report($id);
            
            if (!$success) {
                return $this->jsonResponse($response, [
                    'error' => 'Error al registrar el reporte'
                ], 500);
            }

            return $this->jsonResponse($response, [
                'message' => 'Reporte registrado exitosamente'
            ]);

        } catch (\Exception $e) {
            error_log('Error reporting confession: ' . $e->getMessage());
            return $this->jsonResponse($response, [
                'error' => 'Error interno del servidor'
            ], 500);
        }
    }

    public function updateImages(Request $request, Response $response): Response
    {
        try {
            $id = $request->getAttribute('id');
            $data = $request->getParsedBody();
            
            if (!isset($data['image_urls']) || !is_array($data['image_urls'])) {
                return $this->jsonResponse($response, [
                    'error' => 'image_urls array is required'
                ], 400);
            }

            // Check if confession exists
            $confession = $this->confessionModel->findById($id);
            if (!$confession) {
                return $this->jsonResponse($response, [
                    'error' => 'Confesión no encontrada'
                ], 404);
            }

            // Update confession with image URLs
            $success = $this->confessionModel->updateImageUrls($id, $data['image_urls']);
            
            if (!$success) {
                return $this->jsonResponse($response, [
                    'error' => 'Error al actualizar las imágenes'
                ], 500);
            }

            return $this->jsonResponse($response, [
                'message' => 'Imágenes actualizadas exitosamente',
                'confession_id' => $id,
                'image_urls' => $data['image_urls']
            ]);

        } catch (\Exception $e) {
            error_log('Error updating images: ' . $e->getMessage());
            return $this->jsonResponse($response, [
                'error' => 'Error interno del servidor'
            ], 500);
        }
    }

    private function triggerImageGeneration(string $confessionId, string $content): void
    {
        try {
            $payload = [
                'confession_id' => $confessionId,
                'content' => $content
            ];

            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => [
                        'Content-Type: application/json',
                        'Content-Length: ' . strlen(json_encode($payload))
                    ],
                    'content' => json_encode($payload),
                    'timeout' => 5, // Don't wait too long for image generation
                    'ignore_errors' => true // Don't throw errors on HTTP error codes
                ]
            ]);

            // Fire and forget - don't block confession creation on image generation
            $webhookUrl = $this->imageApiUrl . '/webhook/confession-created';
            $result = @file_get_contents($webhookUrl, false, $context);
            
            // Log success or failure for debugging
            if ($result === false) {
                error_log("Image generation webhook failed for confession $confessionId");
            } else {
                error_log("Image generation webhook triggered successfully for confession $confessionId");
            }
            
        } catch (\Exception $e) {
            // Log the error but don't fail the confession creation
            error_log('Failed to trigger image generation webhook: ' . $e->getMessage());
        }
    }

    private function jsonResponse(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus($status);
    }
}
