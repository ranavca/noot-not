// Admin types
export interface AdminUser {
  id: number;
  username: string;
  role: "admin" | "moderator" | "super_admin";
  active: boolean;
  created_at: string;
  last_login?: string;
}

export interface AdminStats {
  total_confessions: number;
  approved: number;
  pending: number;
  rejected: number;
  total_upvotes: number;
  total_downvotes: number;
  total_reports: number;
  pending_reports: number;
  today_confessions: number;
  week_confessions: number;
}

export interface AdminConfession {
  id: number;
  content: string;
  moderation_status: "pending" | "approved" | "rejected";
  upvotes: number;
  downvotes: number;
  reports: number;
  pending_reports_count: number;
  image_urls?: string[];
  created_at: string;
  created_by_admin?: number;
  moderated_by?: number;
  moderated_at?: string;
  moderation_reason?: string;
}

export interface Report {
  id: number;
  confession_id: number;
  reason: "inappropriate" | "spam" | "offensive" | "other";
  description?: string;
  status: "pending" | "resolved" | "dismissed";
  action_taken?: "dismiss" | "remove_confession" | "warn_user";
  resolved_by?: number;
  resolved_by_username?: string;
  resolved_at?: string;
  admin_notes?: string;
  created_at: string;
  content: string;
  moderation_status: string;
}

export interface LoginCredentials {
  username: string;
  password: string;
}

export interface AuthResponse {
  token: string;
  user: AdminUser;
  expires_in: number;
}

export interface AdminCreateUser {
  username: string;
  password: string;
  role?: "admin" | "moderator" | "super_admin";
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  total_pages: number;
}
