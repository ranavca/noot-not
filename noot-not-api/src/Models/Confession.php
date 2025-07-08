<?php

namespace App\Models;

use App\Database\Connection;
use PDO;

class Confession
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Connection::getInstance();
    }

    public function create(string $content, string $moderationResult = 'approved'): array
    {
        $createdAt = date('Y-m-d H:i:s');

        $sql = "INSERT INTO confessions (content, moderation_status, upvotes, downvotes, reports, created_at, image_urls) 
                VALUES (:content, :moderation_status, 0, 0, 0, :created_at, NULL)";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            'content' => $content,
            'moderation_status' => $moderationResult,
            'created_at' => $createdAt
        ]);

        $id = $this->db->lastInsertId();
        return $this->findById($id);
    }

    public function findById($id): ?array
    {
        $sql = "SELECT * FROM confessions WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        $stmt->execute(['id' => $id]);
        
        $result = $stmt->fetch();
        if ($result) {
            // Ensure numeric fields are properly typed
            $result['id'] = (int) $result['id'];
            $result['upvotes'] = (int) $result['upvotes'];
            $result['downvotes'] = (int) $result['downvotes'];
            $result['reports'] = (int) $result['reports'];
            
            if ($result['image_urls']) {
                $result['image_urls'] = json_decode($result['image_urls'], true);
            }
        }
        return $result ?: null;
    }

    public function getAll(int $page = 1, int $limit = 20, string $sort = 'created_at'): array
    {
        $offset = ($page - 1) * $limit;
        
        // Only show approved confessions
        $sql = "SELECT * FROM confessions 
                WHERE moderation_status = 'approved' 
                ORDER BY {$sort} DESC 
                LIMIT :limit OFFSET :offset";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        $results = $stmt->fetchAll();
        
        // Decode image_urls JSON and ensure proper typing for each confession
        foreach ($results as &$result) {
            // Ensure numeric fields are properly typed
            $result['id'] = (int) $result['id'];
            $result['upvotes'] = (int) $result['upvotes'];
            $result['downvotes'] = (int) $result['downvotes'];
            $result['reports'] = (int) $result['reports'];
            
            if ($result['image_urls']) {
                $result['image_urls'] = json_decode($result['image_urls'], true);
            }
        }
        
        return $results;
    }

    public function getTotalCount(): int
    {
        $sql = "SELECT COUNT(*) FROM confessions WHERE moderation_status = 'approved'";
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        return (int) $stmt->fetchColumn();
    }

    public function vote(string $id, string $type): bool
    {
        if (!in_array($type, ['upvote', 'downvote'])) {
            return false;
        }

        // Get voter identification
        $voterIp = $this->getClientIP();
        $voterFingerprint = $this->generateVoterFingerprint();

        try {
            $this->db->beginTransaction();

            // Check if user has already voted on this confession
            $checkSql = "SELECT vote_type FROM confession_votes 
                        WHERE confession_id = :confession_id 
                        AND voter_ip = :voter_ip 
                        AND voter_fingerprint = :voter_fingerprint";
            $checkStmt = $this->db->prepare($checkSql);
            $checkStmt->execute([
                'confession_id' => $id,
                'voter_ip' => $voterIp,
                'voter_fingerprint' => $voterFingerprint
            ]);
            $existingVote = $checkStmt->fetch();

            if ($existingVote) {
                // User has already voted
                if ($existingVote['vote_type'] === $type) {
                    // Same vote type - remove the vote (toggle off)
                    $deleteSql = "DELETE FROM confession_votes 
                                 WHERE confession_id = :confession_id 
                                 AND voter_ip = :voter_ip 
                                 AND voter_fingerprint = :voter_fingerprint";
                    $deleteStmt = $this->db->prepare($deleteSql);
                    $deleteStmt->execute([
                        'confession_id' => $id,
                        'voter_ip' => $voterIp,
                        'voter_fingerprint' => $voterFingerprint
                    ]);

                    // Decrease the vote count
                    $column = $type === 'upvote' ? 'upvotes' : 'downvotes';
                    $updateSql = "UPDATE confessions SET {$column} = GREATEST(0, {$column} - 1) 
                                 WHERE id = :id AND moderation_status = 'approved'";
                } else {
                    // Different vote type - update the vote
                    $updateVoteSql = "UPDATE confession_votes 
                                     SET vote_type = :vote_type 
                                     WHERE confession_id = :confession_id 
                                     AND voter_ip = :voter_ip 
                                     AND voter_fingerprint = :voter_fingerprint";
                    $updateVoteStmt = $this->db->prepare($updateVoteSql);
                    $updateVoteStmt->execute([
                        'vote_type' => $type,
                        'confession_id' => $id,
                        'voter_ip' => $voterIp,
                        'voter_fingerprint' => $voterFingerprint
                    ]);

                    // Update confession counts: decrease old vote, increase new vote
                    $oldColumn = $existingVote['vote_type'] === 'upvote' ? 'upvotes' : 'downvotes';
                    $newColumn = $type === 'upvote' ? 'upvotes' : 'downvotes';
                    $updateSql = "UPDATE confessions 
                                 SET {$oldColumn} = GREATEST(0, {$oldColumn} - 1),
                                     {$newColumn} = {$newColumn} + 1
                                 WHERE id = :id AND moderation_status = 'approved'";
                }
            } else {
                // New vote - insert vote record
                $insertSql = "INSERT INTO confession_votes (confession_id, voter_ip, voter_fingerprint, vote_type) 
                             VALUES (:confession_id, :voter_ip, :voter_fingerprint, :vote_type)";
                $insertStmt = $this->db->prepare($insertSql);
                $insertStmt->execute([
                    'confession_id' => $id,
                    'voter_ip' => $voterIp,
                    'voter_fingerprint' => $voterFingerprint,
                    'vote_type' => $type
                ]);

                // Increase the vote count
                $column = $type === 'upvote' ? 'upvotes' : 'downvotes';
                $updateSql = "UPDATE confessions SET {$column} = {$column} + 1 
                             WHERE id = :id AND moderation_status = 'approved'";
            }

            // Execute the confession update
            $updateStmt = $this->db->prepare($updateSql);
            $result = $updateStmt->execute(['id' => $id]);

            $this->db->commit();
            return $result;

        } catch (\Exception $e) {
            $this->db->rollBack();
            error_log('Vote error: ' . $e->getMessage());
            return false;
        }
    }

    private function getClientIP(): string
    {
        // Check for IP from shared internet
        if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
            return $_SERVER['HTTP_CLIENT_IP'];
        }
        // Check for IP passed from proxy
        elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            return $_SERVER['HTTP_X_FORWARDED_FOR'];
        }
        // Check for remote IP address
        elseif (!empty($_SERVER['REMOTE_ADDR'])) {
            return $_SERVER['REMOTE_ADDR'];
        }
        return '0.0.0.0';
    }

    private function generateVoterFingerprint(): string
    {
        // Create a fingerprint based on User-Agent and Accept headers
        $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? '';
        $acceptLang = $_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? '';
        $accept = $_SERVER['HTTP_ACCEPT'] ?? '';
        
        return hash('sha256', $userAgent . '|' . $acceptLang . '|' . $accept);
    }

    public function report(string $id): bool
    {
        $sql = "UPDATE confessions SET reports = reports + 1 WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        
        return $stmt->execute(['id' => $id]);
    }

    public function updateModerationStatus(string $id, string $status): bool
    {
        $sql = "UPDATE confessions SET moderation_status = :status WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        
        return $stmt->execute([
            'id' => $id,
            'status' => $status
        ]);
    }

    public function updateImageUrls($id, array $imageUrls): bool
    {
        $sql = "UPDATE confessions SET image_urls = :image_urls WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        
        return $stmt->execute([
            'id' => $id,
            'image_urls' => json_encode($imageUrls)
        ]);
    }
}
