import { useState, useEffect } from "react";
import {
  Card,
  CardContent,
  Typography,
  Box,
  CircularProgress,
  Alert,
} from "@mui/material";
import {
  Article,
  CheckCircle,
  HourglassEmpty,
  Cancel,
  ThumbUp,
  ThumbDown,
  Report,
  Today,
  DateRange,
} from "@mui/icons-material";
import { adminService } from "../../services/adminService";
import type { AdminStats } from "../../types/admin";

interface StatCardProps {
  title: string;
  value: number;
  icon: React.ReactNode;
  color: "primary" | "success" | "warning" | "error" | "info";
}

function StatCard({ title, value, icon, color }: StatCardProps) {
  return (
    <Card sx={{ height: "100%" }}>
      <CardContent>
        <Box sx={{ display: "flex", alignItems: "center", mb: 2 }}>
          <Box
            sx={{
              p: 1,
              borderRadius: 1,
              bgcolor: `${color}.light`,
              color: `${color}.contrastText`,
              mr: 2,
            }}
          >
            {icon}
          </Box>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            {title}
          </Typography>
        </Box>
        <Typography variant="h4" component="div" color={`${color}.main`}>
          {value.toLocaleString()}
        </Typography>
      </CardContent>
    </Card>
  );
}

export function AdminDashboard() {
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      setLoading(true);
      const data = await adminService.getStats();
      setStats(data);
      setError(null);
    } catch (err) {
      setError("Error al cargar estadísticas");
      console.error("Error loading stats:", err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", mt: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ mb: 2 }}>
        {error}
      </Alert>
    );
  }

  if (!stats) {
    return null;
  }

  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Dashboard
      </Typography>

      <Box
        sx={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(250px, 1fr))",
          gap: 3,
          mb: 4,
        }}
      >
        {/* Main Stats */}
        <StatCard
          title="Total Confesiones"
          value={stats.total_confessions}
          icon={<Article />}
          color="primary"
        />

        <StatCard
          title="Aprobadas"
          value={stats.approved}
          icon={<CheckCircle />}
          color="success"
        />

        <StatCard
          title="Pendientes"
          value={stats.pending}
          icon={<HourglassEmpty />}
          color="warning"
        />

        <StatCard
          title="Rechazadas"
          value={stats.rejected}
          icon={<Cancel />}
          color="error"
        />

        {/* Engagement Stats */}
        <StatCard
          title="Total Votos Positivos"
          value={stats.total_upvotes}
          icon={<ThumbUp />}
          color="success"
        />

        <StatCard
          title="Total Votos Negativos"
          value={stats.total_downvotes}
          icon={<ThumbDown />}
          color="error"
        />

        <StatCard
          title="Reportes Pendientes"
          value={stats.pending_reports}
          icon={<Report />}
          color="warning"
        />

        <StatCard
          title="Total Reportes"
          value={stats.total_reports}
          icon={<Report />}
          color="info"
        />

        {/* Time-based Stats */}
        <StatCard
          title="Confesiones Hoy"
          value={stats.today_confessions}
          icon={<Today />}
          color="primary"
        />

        <StatCard
          title="Esta Semana"
          value={stats.week_confessions}
          icon={<DateRange />}
          color="info"
        />
      </Box>

      {/* Quick Actions */}
      <Typography variant="h5" component="h2" sx={{ mt: 4, mb: 2 }}>
        Resumen de Actividad
      </Typography>

      <Box
        sx={{
          display: "grid",
          gridTemplateColumns: { xs: "1fr", md: "1fr 1fr" },
          gap: 3,
        }}
      >
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Estado de Moderación
            </Typography>
            <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
              <Box sx={{ display: "flex", justifyContent: "space-between" }}>
                <Typography>Pendientes de revisión:</Typography>
                <Typography color="warning.main" fontWeight="bold">
                  {stats.pending}
                </Typography>
              </Box>
              <Box sx={{ display: "flex", justifyContent: "space-between" }}>
                <Typography>Reportes sin resolver:</Typography>
                <Typography color="error.main" fontWeight="bold">
                  {stats.pending_reports}
                </Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>

        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Engagement
            </Typography>
            <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
              <Box sx={{ display: "flex", justifyContent: "space-between" }}>
                <Typography>Ratio Positivo/Negativo:</Typography>
                <Typography color="primary.main" fontWeight="bold">
                  {stats.total_upvotes > 0
                    ? (
                        stats.total_upvotes / (stats.total_downvotes || 1)
                      ).toFixed(1)
                    : "0"}
                  :1
                </Typography>
              </Box>
              <Box sx={{ display: "flex", justifyContent: "space-between" }}>
                <Typography>Tasa de Aprobación:</Typography>
                <Typography color="success.main" fontWeight="bold">
                  {stats.total_confessions > 0
                    ? (
                        (stats.approved / stats.total_confessions) *
                        100
                      ).toFixed(1)
                    : "0"}
                  %
                </Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Box>
    </Box>
  );
}
