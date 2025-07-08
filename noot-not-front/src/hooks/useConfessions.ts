import { useState, useEffect, useCallback } from "react";
import { apiService, convertApiConfessionToFrontend } from "../services/api";
import type {
  Confession,
  VoteType,
  PaginationInfo,
  LoadingState,
} from "../types";

// Cookie utilities
const setCookie = (name: string, value: string, days: number = 365) => {
  const expires = new Date();
  expires.setTime(expires.getTime() + days * 24 * 60 * 60 * 1000);
  document.cookie = `${name}=${value};expires=${expires.toUTCString()};path=/`;
};

const getCookie = (name: string): string | null => {
  const nameEQ = name + "=";
  const ca = document.cookie.split(";");
  for (let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) === " ") c = c.substring(1, c.length);
    if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
  }
  return null;
};

const getUserVotesFromCookies = (): Map<number, VoteType> => {
  const votesStr = getCookie("userVotes");
  if (votesStr) {
    try {
      return new Map(JSON.parse(votesStr));
    } catch {
      return new Map();
    }
  }
  return new Map();
};

const saveUserVotesToCookies = (votes: Map<number, VoteType>) => {
  setCookie("userVotes", JSON.stringify(Array.from(votes.entries())));
};

const getReportedFromCookies = (): Set<number> => {
  const reportedStr = getCookie("reportedConfessions");
  if (reportedStr) {
    try {
      return new Set(JSON.parse(reportedStr));
    } catch {
      return new Set();
    }
  }
  return new Set();
};

const saveReportedToCookies = (reported: Set<number>) => {
  setCookie("reportedConfessions", JSON.stringify(Array.from(reported)));
};

interface UseConfessionsReturn {
  confessions: Confession[];
  pagination: PaginationInfo;
  loading: LoadingState;
  createConfession: (content: string) => Promise<boolean>;
  voteConfession: (id: number, voteType: VoteType) => Promise<boolean>;
  reportConfession: (id: number) => Promise<boolean>;
  refreshConfessions: () => Promise<void>;
  loadMoreConfessions: () => Promise<void>;
}

export const useConfessions = (): UseConfessionsReturn => {
  const [confessions, setConfessions] = useState<Confession[]>([]);
  const [pagination, setPagination] = useState<PaginationInfo>({
    currentPage: 1,
    totalPages: 1,
    totalItems: 0,
    itemsPerPage: 20,
  });
  const [loading, setLoading] = useState<LoadingState>({
    isLoading: false,
    error: null,
  });
  const [userVotes, setUserVotes] = useState<Map<number, VoteType>>(new Map());
  const [reportedConfessions, setReportedConfessions] = useState<Set<number>>(
    new Set()
  );

  // Load user votes and reports from cookies
  useEffect(() => {
    setUserVotes(getUserVotesFromCookies());
    setReportedConfessions(getReportedFromCookies());
  }, []);

  // Save user votes and reports to cookies when they change
  useEffect(() => {
    saveUserVotesToCookies(userVotes);
  }, [userVotes]);

  useEffect(() => {
    saveReportedToCookies(reportedConfessions);
  }, [reportedConfessions]);

  // Load confessions from API
  const loadConfessions = useCallback(
    async (page: number = 1, append: boolean = false) => {
      setLoading((prev) => ({ ...prev, isLoading: true, error: null }));

      try {
        const response = await apiService.getConfessions({
          page,
          limit: 20,
          sort: "created_at",
        });

        const frontendConfessions = response.confessions.map(
          (apiConfession) => {
            const confessionId =
              typeof apiConfession.id === "string"
                ? parseInt(apiConfession.id, 10)
                : apiConfession.id;

            return {
              ...convertApiConfessionToFrontend(apiConfession),
              userVote: userVotes.get(confessionId) || null,
              reported: reportedConfessions.has(confessionId),
            };
          }
        );

        if (append) {
          setConfessions((prev) => [...prev, ...frontendConfessions]);
        } else {
          setConfessions(frontendConfessions);
        }

        setPagination({
          currentPage: response.pagination.current_page,
          totalPages: response.pagination.total_pages,
          totalItems: response.pagination.total_items,
          itemsPerPage: response.pagination.items_per_page,
        });

        setLoading((prev) => ({ ...prev, isLoading: false }));
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Failed to load confessions";
        setLoading({ isLoading: false, error: errorMessage });

        // If API fails, try to load from localStorage as fallback
        if (page === 1 && !append) {
          const savedConfessions = localStorage.getItem("confessions");
          if (savedConfessions) {
            const parsed = JSON.parse(savedConfessions);
            const withDates = parsed.map(
              (
                confession: Omit<Confession, "timestamp"> & {
                  timestamp: string;
                }
              ) => ({
                ...confession,
                timestamp: new Date(confession.timestamp),
              })
            );
            setConfessions(withDates);
          }
        }
      }
    },
    [userVotes, reportedConfessions]
  );

  // Initial load
  useEffect(() => {
    loadConfessions(1);
  }, [loadConfessions]);

  const createConfession = async (content: string): Promise<boolean> => {
    try {
      const response = await apiService.createConfession(content);

      // Log the response for debugging
      console.log("Create confession response:", response);

      if (!response.confession) {
        throw new Error("No confession data in response");
      }

      const newConfession = {
        ...convertApiConfessionToFrontend(response.confession),
        userVote: null as "up" | "down" | null,
        reported: false,
      };

      // Add to the beginning of the list
      setConfessions((prev) => [newConfession, ...prev]);
      return true;
    } catch (error) {
      console.error("Create confession error:", error);
      const errorMessage =
        error instanceof Error ? error.message : "Failed to create confession";
      setLoading((prev) => ({ ...prev, error: errorMessage }));
      return false;
    }
  };

  const voteConfession = async (
    id: number,
    voteType: VoteType
  ): Promise<boolean> => {
    const apiVoteType = voteType === "up" ? "upvote" : "downvote";
    const currentVote = userVotes.get(id);

    // Prevent multiple votes of the same type on the same post
    if (currentVote === voteType) {
      // If clicking the same vote type, remove the vote (toggle off)
      try {
        await apiService.voteConfession(id, apiVoteType);

        // Update local state - remove the vote
        const newUserVotes = new Map(userVotes);
        newUserVotes.delete(id);
        setUserVotes(newUserVotes);

        // Update confession in list
        setConfessions((prev) =>
          prev.map((confession) => {
            if (confession.id !== id) return confession;

            let newUpvotes = confession.upvotes;
            let newDownvotes = confession.downvotes;

            if (voteType === "up") {
              newUpvotes--;
            } else {
              newDownvotes--;
            }

            return {
              ...confession,
              upvotes: newUpvotes,
              downvotes: newDownvotes,
              userVote: null,
            };
          })
        );

        return true;
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Failed to remove vote";
        setLoading((prev) => ({ ...prev, error: errorMessage }));
        return false;
      }
    }

    // Normal voting (new vote or switching vote type)
    try {
      await apiService.voteConfession(id, apiVoteType);

      // Update local state
      const newUserVotes = new Map(userVotes);
      newUserVotes.set(id, voteType);
      setUserVotes(newUserVotes);

      // Update confession in list
      setConfessions((prev) =>
        prev.map((confession) => {
          if (confession.id !== id) return confession;

          const wasUpvote = currentVote === "up";
          const wasDownvote = currentVote === "down";
          const isUpvote = voteType === "up";

          let newUpvotes = confession.upvotes;
          let newDownvotes = confession.downvotes;

          // If switching vote types, remove the old vote first
          if (wasUpvote && !isUpvote) {
            newUpvotes--;
            newDownvotes++;
          } else if (wasDownvote && isUpvote) {
            newDownvotes--;
            newUpvotes++;
          } else if (!currentVote) {
            // New vote
            if (isUpvote) {
              newUpvotes++;
            } else {
              newDownvotes++;
            }
          }

          return {
            ...confession,
            upvotes: newUpvotes,
            downvotes: newDownvotes,
            userVote: voteType,
          };
        })
      );

      return true;
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Failed to vote";
      setLoading((prev) => ({ ...prev, error: errorMessage }));
      return false;
    }
  };

  const reportConfession = async (id: number): Promise<boolean> => {
    try {
      await apiService.reportConfession(id);

      // Update local state
      const newReportedConfessions = new Set(reportedConfessions);
      newReportedConfessions.add(id);
      setReportedConfessions(newReportedConfessions);

      // Update confession in list
      setConfessions((prev) =>
        prev.map((confession) =>
          confession.id === id ? { ...confession, reported: true } : confession
        )
      );

      return true;
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Failed to report confession";
      setLoading((prev) => ({ ...prev, error: errorMessage }));
      return false;
    }
  };

  const refreshConfessions = async (): Promise<void> => {
    await loadConfessions(1, false);
  };

  const loadMoreConfessions = async (): Promise<void> => {
    if (pagination.currentPage < pagination.totalPages) {
      await loadConfessions(pagination.currentPage + 1, true);
    }
  };

  return {
    confessions,
    pagination,
    loading,
    createConfession,
    voteConfession,
    reportConfession,
    refreshConfessions,
    loadMoreConfessions,
  };
};
