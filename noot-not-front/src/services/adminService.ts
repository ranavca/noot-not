import axios from "axios";
import type {
  LoginCredentials,
  AuthResponse,
  AdminStats,
  AdminConfession,
  Report,
  AdminCreateUser,
  AdminUser,
} from "../types/admin";

const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8001";

class AdminService {
  private token: string | null = null;

  constructor() {
    this.token = localStorage.getItem("admin_token");
    if (this.token) {
      this.setAuthHeader();
    }
  }

  private setAuthHeader() {
    if (this.token) {
      axios.defaults.headers.common["Authorization"] = `Bearer ${this.token}`;
    } else {
      delete axios.defaults.headers.common["Authorization"];
    }
  }

  async login(credentials: LoginCredentials): Promise<AuthResponse> {
    try {
      const response = await axios.post(
        `${API_BASE_URL}/api/admin/login`,
        credentials
      );
      const data = response.data;

      this.token = data.token;
      localStorage.setItem("admin_token", this.token!);
      this.setAuthHeader();

      return data;
    } catch (error) {
      console.error("Login error:", error);
      throw new Error("Invalid credentials");
    }
  }

  logout() {
    this.token = null;
    localStorage.removeItem("admin_token");
    delete axios.defaults.headers.common["Authorization"];
  }

  isAuthenticated(): boolean {
    return !!this.token;
  }

  async getStats(): Promise<AdminStats> {
    const response = await axios.get(`${API_BASE_URL}/api/admin/stats`);
    return response.data;
  }

  async getConfessions(
    status: string = "all",
    page: number = 1,
    limit: number = 20
  ): Promise<{
    confessions: AdminConfession[];
    total: number;
    page: number;
    limit: number;
    total_pages: number;
  }> {
    const response = await axios.get(`${API_BASE_URL}/api/admin/confessions`, {
      params: { status, page, limit },
    });
    return response.data;
  }

  async createConfession(
    content: string,
    status: string = "approved"
  ): Promise<void> {
    await axios.post(`${API_BASE_URL}/api/admin/confessions`, {
      content,
      status,
    });
  }

  async updateConfessionStatus(
    id: number,
    status: string,
    reason?: string
  ): Promise<void> {
    await axios.put(`${API_BASE_URL}/api/admin/confessions/${id}/status`, {
      status,
      reason,
    });
  }

  async deleteConfession(id: number): Promise<void> {
    await axios.delete(`${API_BASE_URL}/api/admin/confessions/${id}`);
  }

  async regenerateImages(id: number): Promise<void> {
    await axios.post(
      `${API_BASE_URL}/api/admin/confessions/${id}/regenerate-images`
    );
  }

  async getReports(
    status: string = "pending",
    page: number = 1,
    limit: number = 20
  ): Promise<{
    reports: Report[];
    total: number;
    page: number;
    limit: number;
    total_pages: number;
  }> {
    const response = await axios.get(`${API_BASE_URL}/api/admin/reports`, {
      params: { status, page, limit },
    });
    return response.data;
  }

  async resolveReport(
    id: number,
    action: string,
    notes?: string
  ): Promise<void> {
    await axios.put(`${API_BASE_URL}/api/admin/reports/${id}/resolve`, {
      action,
      notes,
    });
  }

  async getAdminUsers(): Promise<{ users: AdminUser[] }> {
    const response = await axios.get(`${API_BASE_URL}/api/admin/users`);
    return response.data;
  }

  async createAdminUser(userData: AdminCreateUser): Promise<void> {
    await axios.post(`${API_BASE_URL}/api/admin/users`, userData);
  }
}

export const adminService = new AdminService();
