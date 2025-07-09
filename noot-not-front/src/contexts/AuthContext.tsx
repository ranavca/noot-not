import { createContext, useState, useEffect } from "react";
import type { ReactNode } from "react";
import { adminService } from "../services/adminService";
import type { AdminUser } from "../types/admin";

interface AuthContextType {
  user: AdminUser | null;
  isAuthenticated: boolean;
  login: (username: string, password: string) => Promise<boolean>;
  logout: () => void;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export { AuthContext };

interface AuthProviderProps {
  children: ReactNode;
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check if user is already authenticated
    const checkAuth = async () => {
      if (adminService.isAuthenticated()) {
        try {
          // Try to get user info from stored token
          // For now, we'll just mark as authenticated
          // In a real app, you might want to verify the token with the server
          setLoading(false);
        } catch {
          adminService.logout();
          setLoading(false);
        }
      } else {
        setLoading(false);
      }
    };

    checkAuth();
  }, []);

  const login = async (
    username: string,
    password: string
  ): Promise<boolean> => {
    try {
      setLoading(true);
      const response = await adminService.login({ username, password });
      setUser(response.user);
      return true;
    } catch (error) {
      console.error("Login failed:", error);
      return false;
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    adminService.logout();
    setUser(null);
  };

  const value = {
    user,
    isAuthenticated: adminService.isAuthenticated(),
    login,
    logout,
    loading,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
