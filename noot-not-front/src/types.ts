export interface Confession {
  id: number;
  content: string;
  timestamp: Date;
  upvotes: number;
  downvotes: number;
  userVote?: "up" | "down" | null;
  reported: boolean;
  imageUrls?: string[];
}

export type VoteType = "up" | "down";

// API-related types
export interface PaginationInfo {
  currentPage: number;
  totalPages: number;
  totalItems: number;
  itemsPerPage: number;
}

export interface LoadingState {
  isLoading: boolean;
  error: string | null;
}
