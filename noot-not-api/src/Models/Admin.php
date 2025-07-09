<?php

namespace App\Models;

use App\Database\Connection;
use PDO;

class Admin
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Connection::getInstance();
    }

    public function authenticate(string $username, string $password): ?array
    {
        $stmt = $this->db->prepare("
            SELECT id, username, password_hash, role, created_at
            FROM admin_users 
            WHERE username = ? AND active = 1
        ");
        
        $stmt->execute([$username]);
        $admin = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($admin && password_verify($password, $admin['password_hash'])) {
            // Remove password hash from returned data
            unset($admin['password_hash']);
            return $admin;
        }
        
        return null;
    }

    public function createUser(string $username, string $password, string $role = 'admin'): bool
    {
        $passwordHash = password_hash($password, PASSWORD_DEFAULT);
        
        $stmt = $this->db->prepare("
            INSERT INTO admin_users (username, password_hash, role, active, created_at)
            VALUES (?, ?, ?, 1, NOW())
        ");
        
        return $stmt->execute([$username, $passwordHash, $role]);
    }

    public function getAllUsers(): array
    {
        $stmt = $this->db->prepare("
            SELECT id, username, role, active, created_at, last_login
            FROM admin_users
            ORDER BY created_at DESC
        ");
        
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function updateLastLogin(int $userId): void
    {
        $stmt = $this->db->prepare("
            UPDATE admin_users 
            SET last_login = NOW() 
            WHERE id = ?
        ");
        
        $stmt->execute([$userId]);
    }

    public function deactivateUser(int $userId): bool
    {
        $stmt = $this->db->prepare("
            UPDATE admin_users 
            SET active = 0 
            WHERE id = ?
        ");
        
        return $stmt->execute([$userId]);
    }

    public function changePassword(int $userId, string $newPassword): bool
    {
        $passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
        
        $stmt = $this->db->prepare("
            UPDATE admin_users 
            SET password_hash = ? 
            WHERE id = ?
        ");
        
        return $stmt->execute([$passwordHash, $userId]);
    }
}
