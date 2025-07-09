import React, { useState } from "react";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import {
  ThemeProvider,
  CssBaseline,
  Container,
  Box,
  Typography,
  Fab,
  Snackbar,
  Alert,
  Button,
  CircularProgress,
} from "@mui/material";
import { Add, DataObject } from "@mui/icons-material";
import { lightTheme, darkTheme } from "./theme";
import { ThemeContextProvider } from "./contexts/ThemeContext";
import { AuthProvider } from "./contexts/AuthContext";
import { useThemeContext } from "./hooks/useThemeContext";
import { useConfessions } from "./hooks/useConfessions";
import { Header } from "./components/Header";
import { ConfessionForm } from "./components/ConfessionForm";
import { ConfessionCard } from "./components/ConfessionCard";
import { AdminApp } from "./components/admin/AdminApp";
import type { VoteType } from "./types";

const AppContent: React.FC = () => {
  const { isDarkMode } = useThemeContext();
  const {
    confessions,
    pagination,
    loading,
    createConfession,
    voteConfession,
    reportConfession,
    refreshConfessions,
    loadMoreConfessions,
  } = useConfessions();

  const [showForm, setShowForm] = useState(false);
  const [showOpenSourceBanner, setShowOpenSourceBanner] = useState(() => {
    const dismissed = localStorage.getItem("openSourceBannerDismissed");
    return !dismissed;
  });
  const [snackbar, setSnackbar] = useState<{
    open: boolean;
    message: string;
    severity: "success" | "info" | "warning" | "error";
  }>({ open: false, message: "", severity: "success" });

  const handleSubmitConfession = async (content: string) => {
    const success = await createConfession(content);

    if (success) {
      setShowForm(false);
      setSnackbar({
        open: true,
        message: "¡Tu confesión ha sido publicada de forma anónima!",
        severity: "success",
      });
    } else {
      setSnackbar({
        open: true,
        message: loading.error || "Error al publicar la confesión",
        severity: "error",
      });
    }
  };

  const handleVote = async (id: number, voteType: VoteType) => {
    const success = await voteConfession(id, voteType);

    if (!success) {
      setSnackbar({
        open: true,
        message: loading.error || "Error al votar",
        severity: "error",
      });
    }
  };

  const handleReport = async (id: number) => {
    const success = await reportConfession(id);

    if (success) {
      setSnackbar({
        open: true,
        message:
          "La confesión ha sido reportada. Gracias por mantener nuestra comunidad segura.",
        severity: "info",
      });
    } else {
      setSnackbar({
        open: true,
        message: loading.error || "Error al reportar la confesión",
        severity: "error",
      });
    }
  };

  const handleCloseSnackbar = () => {
    setSnackbar((prev) => ({ ...prev, open: false }));
  };

  const handleCloseBanner = () => {
    setShowOpenSourceBanner(false);
    localStorage.setItem("openSourceBannerDismissed", "true");
  };

  const handleRefresh = async () => {
    await refreshConfessions();
  };

  const handleLoadMore = async () => {
    await loadMoreConfessions();
  };

  const sortedConfessions = [...confessions].sort(
    (a, b) => b.timestamp.getTime() - a.timestamp.getTime()
  );

  return (
    <ThemeProvider theme={isDarkMode ? darkTheme : lightTheme}>
      <CssBaseline />
      <Box sx={{ minHeight: "100vh", backgroundColor: "background.default" }}>
        <Header />

        {showOpenSourceBanner && (
          <Container maxWidth="md" sx={{ mb: 2 }}>
            <Alert
              severity="info"
              onClose={handleCloseBanner}
              icon={<DataObject />}
              sx={{
                border: "1px solid",
                borderColor: "info.main",
                borderRadius: 1,
                "& .MuiAlert-message": {
                  width: "100%",
                },
              }}
            >
              <Typography variant="body2" sx={{ fontWeight: 500 }}>
                🎉 Noot Not es <strong>open-source</strong>, puedes contribuir a
                dejar más OP el proyecto.
                <br />
                <Typography
                  variant="body2"
                  component="span"
                  sx={{
                    color: "info.main",
                    textDecoration: "underline",
                    cursor: "pointer",
                    fontWeight: 600,
                  }}
                  onClick={() =>
                    window.open("https://github.com/ranavca/noot-not", "_blank")
                  }
                >
                  ¡Participa en GitHub!
                </Typography>
              </Typography>
            </Alert>
          </Container>
        )}

        <Container maxWidth="md" sx={{ pb: 10 }}>
          {loading.error && (
            <Alert
              severity="error"
              sx={{ mb: 2 }}
              action={
                <Button color="inherit" size="small" onClick={handleRefresh}>
                  Reintentar
                </Button>
              }
            >
              {loading.error}
            </Alert>
          )}

          {showForm && (
            <ConfessionForm
              onSubmit={handleSubmitConfession}
              onClose={() => setShowForm(false)}
            />
          )}

          {sortedConfessions.length === 0 && !showForm && !loading.isLoading ? (
            <Box sx={{ textAlign: "center", mt: 8 }}>
              <Typography
                variant="h5"
                color="text.secondary"
                sx={{
                  mb: 2,
                  fontWeight: 600,
                }}
              >
                Aún no hay confesiones
              </Typography>
              <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
                ¡Sé el primero en compartir una confesión anónima!
              </Typography>
              <Button
                variant="outlined"
                onClick={() => setShowForm(true)}
                sx={{
                  borderRadius: 3,
                  px: 4,
                  py: 1.5,
                  fontWeight: 600,
                  borderColor: "primary.main",
                  color: "primary.main",
                  "&:hover": {
                    backgroundColor: "primary.main",
                    color: "white",
                    transform: "translateY(-1px)",
                  },
                  transition: "all 0.2s ease-in-out",
                }}
              >
                Escribir una Confesión
              </Button>
            </Box>
          ) : (
            <Box>
              {loading.isLoading && sortedConfessions.length === 0 ? (
                <Box sx={{ display: "flex", justifyContent: "center", mt: 4 }}>
                  <CircularProgress />
                </Box>
              ) : (
                <>
                  {sortedConfessions.map((confession) => (
                    <ConfessionCard
                      key={confession.id}
                      confession={confession}
                      onVote={handleVote}
                      onReport={handleReport}
                    />
                  ))}

                  {pagination.currentPage < pagination.totalPages && (
                    <Box
                      sx={{ display: "flex", justifyContent: "center", mt: 3 }}
                    >
                      <Button
                        variant="outlined"
                        onClick={handleLoadMore}
                        disabled={loading.isLoading}
                        sx={{
                          borderRadius: 3,
                          px: 4,
                          py: 1.5,
                          fontWeight: 600,
                        }}
                      >
                        {loading.isLoading
                          ? "Cargando..."
                          : "Cargar más confesiones"}
                      </Button>
                    </Box>
                  )}
                </>
              )}
            </Box>
          )}
        </Container>

        {!showForm && (
          <Fab
            color="primary"
            sx={{
              position: "fixed",
              bottom: 24,
              right: 24,
              boxShadow: "0 8px 25px rgba(220, 38, 38, 0.3)",
              "&:hover": {
                transform: "scale(1.1)",
                boxShadow: "0 12px 35px rgba(220, 38, 38, 0.4)",
              },
              transition: "all 0.3s ease-in-out",
            }}
            onClick={() => setShowForm(true)}
          >
            <Add />
          </Fab>
        )}

        <Snackbar
          open={snackbar.open}
          autoHideDuration={4000}
          onClose={handleCloseSnackbar}
          anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
        >
          <Alert
            onClose={handleCloseSnackbar}
            severity={snackbar.severity}
            sx={{
              border: "1px solid",
              borderColor: `${snackbar.severity}.main`,
              borderRadius: 2,
            }}
          >
            {snackbar.message}
          </Alert>
        </Snackbar>
      </Box>
    </ThemeProvider>
  );
};

function App() {
  return (
    <AuthProvider>
      <ThemeContextProvider>
        <Router>
          <Routes>
            <Route path="/" element={<MainApp />} />
            <Route path="/admin/*" element={<AdminApp />} />
          </Routes>
        </Router>
      </ThemeContextProvider>
    </AuthProvider>
  );
}

function MainApp() {
  return <AppContent />;
}

export default App;
