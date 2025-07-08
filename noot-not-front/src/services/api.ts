import axios from "axios";
import type { AxiosInstance, AxiosError } from "axios";

// API Configuration
const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:8000/api";

// Types for API responses
export interface ApiConfession {
  id: number | string; // Can be either number or string from API
  content: string;
  moderation_status: "approved" | "pending" | "rejected";
  upvotes: number;
  downvotes: number;
  reports: number;
  image_urls?: string[] | null;
  created_at: string;
  updated_at: string;
}

export interface CreateConfessionResponse {
  message: string;
  confession: ApiConfession;
}

export interface ListConfessionsResponse {
  confessions: ApiConfession[];
  pagination: {
    current_page: number;
    total_pages: number;
    total_items: number;
    items_per_page: number;
  };
}

export interface VoteResponse {
  message: string;
  confession: ApiConfession;
}

export interface ReportResponse {
  message: string;
}

export interface ApiError {
  error: string;
  reason?: string;
}

// API Service Class
class ApiService {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        "Content-Type": "application/json",
      },
      timeout: 10000, // 10 seconds timeout
    });

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError<ApiError>) => {
        const errorMessage =
          error.response?.data?.error ||
          error.message ||
          "An unexpected error occurred";
        return Promise.reject(new Error(errorMessage));
      }
    );
  }

  // Create a new confession
  async createConfession(content: string): Promise<CreateConfessionResponse> {
    const response = await this.client.post<CreateConfessionResponse>(
      "/confessions",
      { content }
    );
    return response.data;
  }

  // Get list of confessions
  async getConfessions(params?: {
    page?: number;
    limit?: number;
    sort?: "created_at" | "upvotes";
  }): Promise<ListConfessionsResponse> {
    const response = await this.client.get<ListConfessionsResponse>(
      "/confessions",
      { params }
    );
    return response.data;
  }

  // Vote on a confession
  async voteConfession(
    confessionId: number,
    voteType: "upvote" | "downvote"
  ): Promise<VoteResponse> {
    const response = await this.client.post<VoteResponse>(
      `/confessions/${confessionId}/vote`,
      {
        type: voteType,
      }
    );
    return response.data;
  }

  // Report a confession
  async reportConfession(confessionId: number): Promise<ReportResponse> {
    const response = await this.client.post<ReportResponse>(
      `/confessions/${confessionId}/report`
    );
    return response.data;
  }
}

// Create and export a singleton instance
export const apiService = new ApiService();

// Helper function to convert API confession to frontend confession format
export const convertApiConfessionToFrontend = (
  apiConfession: ApiConfession
) => {
  // Ensure id is a number and handle potential undefined/null values
  const id =
    typeof apiConfession.id === "string"
      ? parseInt(apiConfession.id, 10)
      : apiConfession.id;

  if (!id || isNaN(id)) {
    console.error(
      "Invalid confession ID:",
      apiConfession.id,
      "in confession:",
      apiConfession
    );
    throw new Error("Invalid confession data: missing or invalid ID");
  }

  return {
    id,
    content: apiConfession.content || "",
    timestamp: new Date(apiConfession.created_at),
    upvotes: apiConfession.upvotes || 0,
    downvotes: apiConfession.downvotes || 0,
    userVote: null as "up" | "down" | null, // We'll track this locally
    reported: false, // We'll track this locally
    imageUrls: apiConfession.image_urls || [],
  };
};
