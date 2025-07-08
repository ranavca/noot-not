<?php

namespace App\Services;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\RequestException;

class ModerationService
{
    private Client $httpClient;
    private string $apiKey;

    public function __construct()
    {
        $this->httpClient = new Client();
        $this->apiKey = $_ENV['OPENAI_API_KEY'] ?? '';
    }

    public function moderateContent(string $content): array
    {
        if (empty($this->apiKey)) {
            // If no API key, allow content but log warning
            error_log('Warning: No OpenAI API key provided, skipping moderation');
            return [
                'status' => 'approved',
                'reason' => 'No hay servicio de moderación configurado'
            ];
        }

        try {
            $response = $this->httpClient->post('https://api.openai.com/v1/chat/completions', [
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->apiKey,
                    'Content-Type' => 'application/json',
                ],
                'json' => [
                    'model' => 'gpt-3.5-turbo',
                    'messages' => [
                        [
                            'role' => 'system',
                            'content' => 'Eres un moderador de contenido. Analiza el siguiente texto y determina si debe ser aprobado o rechazado. Rechaza contenido que contenga: 1) Información personal (nombres, direcciones, números de teléfono, correos electrónicos), 2) Lenguaje extremadamente odioso o amenazante, 3) Spam o contenido promocional, 4) Contenido que pueda dañar a alguien. Responde solo con "APROBADO" o "RECHAZADO" seguido de una breve razón. No seas demasiado estricto, es una web para descargarse o saludar.'
                        ],
                        [
                            'role' => 'user',
                            'content' => $content
                        ]
                    ],
                    'max_tokens' => 50,
                    'temperature' => 0.1
                ]
            ]);

            $body = json_decode($response->getBody()->getContents(), true);
            $result = $body['choices'][0]['message']['content'] ?? '';
            
            if (strpos(strtoupper($result), 'APROBADO') !== false || strpos(strtoupper($result), 'APPROVED') !== false) {
                return [
                    'status' => 'approved',
                    'reason' => 'El contenido pasó la moderación'
                ];
            } else {
                return [
                    'status' => 'rejected',
                    'reason' => trim(str_replace(['RECHAZADO', 'REJECTED', 'APROBADO', 'APPROVED'], '', $result))
                ];
            }
        } catch (RequestException $e) {
            error_log('Moderation API error: ' . $e->getMessage());
            
            // Fallback to basic moderation
            return $this->basicModeration($content);
        }
    }

    private function basicModeration(string $content): array
    {
        // Basic checks
        $content = strtolower($content);
        
        // Check for email patterns
        if (preg_match('/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/', $content)) {
            return [
                'status' => 'rejected',
                'reason' => 'Contiene dirección de correo electrónico'
            ];
        }

        // Check for phone number patterns
        if (preg_match('/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/', $content)) {
            return [
                'status' => 'rejected',
                'reason' => 'Contiene número de teléfono'
            ];
        }

        // Check for very short content (likely spam)
        if (strlen(trim($content)) < 10) {
            return [
                'status' => 'rejected',
                'reason' => 'Contenido muy corto'
            ];
        }

        // Check for very long content (likely spam)
        if (strlen($content) > 1000) {
            return [
                'status' => 'rejected',
                'reason' => 'Contenido muy largo'
            ];
        }

        // Basic profanity/hate speech check
        $badWords = ['spam', 'advertisement', 'buy now', 'click here', 'compra ahora', 'haz clic aquí', 'publicidad'];
        foreach ($badWords as $word) {
            if (strpos($content, $word) !== false) {
                return [
                    'status' => 'rejected',
                    'reason' => 'Contiene contenido prohibido'
                ];
            }
        }

        return [
            'status' => 'approved',
            'reason' => 'Pasó la moderación básica'
        ];
    }
}
