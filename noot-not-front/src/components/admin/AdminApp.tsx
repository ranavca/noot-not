import { useState } from "react";
import { ThemeProvider, CssBaseline } from "@mui/material";
import { useAuth } from "../../hooks/useAuth";
import { AdminLogin } from "./AdminLogin";
import { AdminLayout } from "./AdminLayout";
import { AdminDashboard } from "./AdminDashboard";
import { AdminConfessions } from "./AdminConfessions";
import { AdminReports } from "./AdminReports";
import { AdminUsers } from "./AdminUsers";
import { AdminCreate } from "./AdminCreate";
import { lightTheme } from "../../theme";

export function AdminApp() {
  const { isAuthenticated, loading } = useAuth();
  const [currentPage, setCurrentPage] = useState("dashboard");

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!isAuthenticated) {
    return <AdminLogin />;
  }

  const renderCurrentPage = () => {
    switch (currentPage) {
      case "dashboard":
        return <AdminDashboard />;
      case "confessions":
        return <AdminConfessions />;
      case "reports":
        return <AdminReports />;
      case "users":
        return <AdminUsers />;
      case "create":
        return <AdminCreate />;
      default:
        return <AdminDashboard />;
    }
  };

  return (
    <ThemeProvider theme={lightTheme}>
      <CssBaseline />
      <AdminLayout currentPage={currentPage} onPageChange={setCurrentPage}>
        {renderCurrentPage()}
      </AdminLayout>
    </ThemeProvider>
  );
}
