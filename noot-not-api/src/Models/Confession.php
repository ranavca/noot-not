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

    // Admin-specific methods
    public function getAdminStats(): array
    {
        $sql = "SELECT 
            COUNT(*) as total_confessions,
            SUM(CASE WHEN moderation_status = 'approved' THEN 1 ELSE 0 END) as approved,
            SUM(CASE WHEN moderation_status = 'pending' THEN 1 ELSE 0 END) as pending,
            SUM(CASE WHEN moderation_status = 'rejected' THEN 1 ELSE 0 END) as rejected,
            SUM(upvotes) as total_upvotes,
            SUM(downvotes) as total_downvotes,
            SUM(reports) as total_reports,
            COUNT(CASE WHEN DATE(created_at) = CURDATE() THEN 1 END) as today_confessions,
            COUNT(CASE WHEN DATE(created_at) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN 1 END) as week_confessions
        FROM confessions";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        $stats = $stmt->fetch(PDO::FETCH_ASSOC);
        
        // Get pending reports count
        $reportsSql = "SELECT COUNT(*) as pending_reports FROM confession_reports WHERE status = 'pending'";
        $reportsStmt = $this->db->prepare($reportsSql);
        $reportsStmt->execute();
        $reportsData = $reportsStmt->fetch(PDO::FETCH_ASSOC);
        
        $stats['pending_reports'] = $reportsData['pending_reports'];
        
        return $stats;
    }

    public function getAdminConfessions(string $status = 'all', int $limit = 20, int $offset = 0): array
    {
        $whereClause = $status !== 'all' ? "WHERE moderation_status = :status" : "";
        
        $sql = "SELECT c.*, 
                   (SELECT COUNT(*) FROM confession_reports cr WHERE cr.confession_id = c.id AND cr.status = 'pending') as pending_reports_count
                FROM confessions c 
                {$whereClause}
                ORDER BY c.created_at DESC 
                LIMIT :limit OFFSET :offset";
        
        $stmt = $this->db->prepare($sql);
        
        if ($status !== 'all') {
            $stmt->bindValue('status', $status, PDO::PARAM_STR);
        }
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($results as &$result) {
            $result['id'] = (int) $result['id'];
            $result['upvotes'] = (int) $result['upvotes'];
            $result['downvotes'] = (int) $result['downvotes'];
            $result['reports'] = (int) $result['reports'];
            $result['pending_reports_count'] = (int) $result['pending_reports_count'];
            
            if ($result['image_urls']) {
                $result['image_urls'] = json_decode($result['image_urls'], true);
            }
        }
        
        return $results;
    }

    public function getAdminConfessionsCount(string $status = 'all'): int
    {
        $whereClause = $status !== 'all' ? "WHERE moderation_status = :status" : "";
        $sql = "SELECT COUNT(*) FROM confessions {$whereClause}";
        
        $stmt = $this->db->prepare($sql);
        if ($status !== 'all') {
            $stmt->bindValue('status', $status, PDO::PARAM_STR);
        }
        $stmt->execute();
        
        return (int) $stmt->fetchColumn();
    }

    public function createAdminConfession(string $content, string $status, int $adminId): int
    {
        $sql = "INSERT INTO confessions (content, moderation_status, upvotes, downvotes, reports, created_at, created_by_admin) 
                VALUES (:content, :status, 0, 0, 0, NOW(), :admin_id)";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            'content' => $content,
            'status' => $status,
            'admin_id' => $adminId
        ]);

        return (int) $this->db->lastInsertId();
    }

    public function updateStatus(int $confessionId, string $status, int $adminId, ?string $reason = null): bool
    {
        $sql = "UPDATE confessions 
                SET moderation_status = :status, 
                    moderated_by = :admin_id, 
                    moderated_at = NOW(),
                    moderation_reason = :reason
                WHERE id = :id";
        
        $stmt = $this->db->prepare($sql);
        return $stmt->execute([
            'status' => $status,
            'admin_id' => $adminId,
            'reason' => $reason,
            'id' => $confessionId
        ]);
    }

    public function deleteById(int $confessionId, int $adminId): bool
    {
        // First log the deletion
        $logSql = "INSERT INTO admin_actions (admin_id, action, target_type, target_id, performed_at) 
                   VALUES (:admin_id, 'delete_confession', 'confession', :confession_id, NOW())";
        $logStmt = $this->db->prepare($logSql);
        $logStmt->execute([
            'admin_id' => $adminId,
            'confession_id' => $confessionId
        ]);

        // Then delete the confession
        $sql = "DELETE FROM confessions WHERE id = :id";
        $stmt = $this->db->prepare($sql);
        return $stmt->execute(['id' => $confessionId]);
    }

    public function getById(int $confessionId): ?array
    {
        return $this->findById($confessionId);
    }

    // Report management methods
    public function getReports(string $status = 'pending', int $limit = 20, int $offset = 0): array
    {
        // First check if the table exists and has any data
        $countSql = "SELECT COUNT(*) FROM confession_reports";
        $countStmt = $this->db->prepare($countSql);
        $countStmt->execute();
        $totalReports = $countStmt->fetchColumn();
        
        if ($totalReports == 0) {
            return []; // Return empty array if no reports exist
        }
        
        $sql = "SELECT cr.*, c.content, c.moderation_status,
                       au.username as resolved_by_username
                FROM confession_reports cr
                JOIN confessions c ON cr.confession_id = c.id
                LEFT JOIN admin_users au ON cr.resolved_by = au.id
                WHERE cr.status = :status
                ORDER BY cr.created_at DESC
                LIMIT :limit OFFSET :offset";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindValue('status', $status, PDO::PARAM_STR);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getReportsCount(string $status = 'pending'): int
    {
        $sql = "SELECT COUNT(*) FROM confession_reports WHERE status = :status";
        $stmt = $this->db->prepare($sql);
        $stmt->bindValue('status', $status, PDO::PARAM_STR);
        $stmt->execute();
        
        return (int) $stmt->fetchColumn();
    }

    public function resolveReport(int $reportId, string $action, int $adminId, ?string $notes = null): bool
    {
        try {
            $this->db->beginTransaction();

            // Get report details
            $reportSql = "SELECT confession_id FROM confession_reports WHERE id = :id";
            $reportStmt = $this->db->prepare($reportSql);
            $reportStmt->execute(['id' => $reportId]);
            $report = $reportStmt->fetch(PDO::FETCH_ASSOC);

            if (!$report) {
                $this->db->rollBack();
                return false;
            }

            // Update report status
            $updateSql = "UPDATE confession_reports 
                         SET status = 'resolved', 
                             action_taken = :action, 
                             resolved_by = :admin_id, 
                             resolved_at = NOW(),
                             admin_notes = :notes
                         WHERE id = :id";
            $updateStmt = $this->db->prepare($updateSql);
            $updateStmt->execute([
                'action' => $action,
                'admin_id' => $adminId,
                'notes' => $notes,
                'id' => $reportId
            ]);

            // If action is to remove confession, update its status
            if ($action === 'remove_confession') {
                $this->updateStatus($report['confession_id'], 'rejected', $adminId, 'Removed due to report');
            }

            $this->db->commit();
            return true;

        } catch (\Exception $e) {
            $this->db->rollBack();
            error_log('Report resolution error: ' . $e->getMessage());
            return false;
        }
    }

    public function createReport(string $confessionId, string $reason, ?string $description = null): bool
    {
        $reporterIp = $this->getClientIP();
        $reporterFingerprint = $this->generateVoterFingerprint();
        
        try {
            $this->db->beginTransaction();
            
            // Check if user has already reported this confession
            $checkSql = "SELECT id FROM confession_reports 
                        WHERE confession_id = :confession_id 
                        AND reporter_ip = :reporter_ip 
                        AND reporter_fingerprint = :reporter_fingerprint
                        AND status = 'pending'";
            $checkStmt = $this->db->prepare($checkSql);
            $checkStmt->execute([
                'confession_id' => $confessionId,
                'reporter_ip' => $reporterIp,
                'reporter_fingerprint' => $reporterFingerprint
            ]);
            
            if ($checkStmt->fetch()) {
                // User has already reported this confession
                $this->db->rollBack();
                return false;
            }
            
            // Create report record
            $insertSql = "INSERT INTO confession_reports 
                         (confession_id, reason, description, reporter_ip, reporter_fingerprint, status, created_at)
                         VALUES (:confession_id, :reason, :description, :reporter_ip, :reporter_fingerprint, 'pending', NOW())";
            $insertStmt = $this->db->prepare($insertSql);
            $result = $insertStmt->execute([
                'confession_id' => $confessionId,
                'reason' => $reason,
                'description' => $description,
                'reporter_ip' => $reporterIp,
                'reporter_fingerprint' => $reporterFingerprint
            ]);
            
            // Increment reports count on confession
            if ($result) {
                $updateSql = "UPDATE confessions SET reports = reports + 1 WHERE id = :id";
                $updateStmt = $this->db->prepare($updateSql);
                $updateStmt->execute(['id' => $confessionId]);
            }
            
            $this->db->commit();
            return $result;
            
        } catch (\Exception $e) {
            $this->db->rollBack();
            error_log('Report creation error: ' . $e->getMessage());
            return false;
        }
    }
}
