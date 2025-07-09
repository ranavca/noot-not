import { useState } from "react";
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Alert,
  Container,
  Avatar,
  CssBaseline,
  ThemeProvider,
} from "@mui/material";
import { AdminPanelSettings } from "@mui/icons-material";
import { useAuth } from "../../hooks/useAuth";
import { lightTheme } from "../../theme";

export function AdminLogin() {
  const [credentials, setCredentials] = useState({
    username: "admin",
    password: "password",
  });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const success = await login(credentials.username, credentials.password);
      if (!success) {
        setError("Credenciales inválidas");
      }
    } catch {
      setError("Error al iniciar sesión");
    } finally {
      setLoading(false);
    }
  };

  const handleChange =
    (field: "username" | "password") =>
    (e: React.ChangeEvent<HTMLInputElement>) => {
      setCredentials((prev) => ({ ...prev, [field]: e.target.value }));
    };

  return (
    <ThemeProvider theme={lightTheme}>
      <CssBaseline />
      <Container component="main" maxWidth="xs">
        <Box
          sx={{
            marginTop: 8,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            minHeight: "100vh",
          }}
        >
          <Avatar sx={{ m: 1, bgcolor: "primary.main" }}>
            <AdminPanelSettings />
          </Avatar>

          <Typography component="h1" variant="h5" sx={{ mb: 3 }}>
            Panel de Administración
          </Typography>

          <Card sx={{ width: "100%", maxWidth: 400 }}>
            <CardContent sx={{ p: 4 }}>
              <Typography
                variant="body2"
                color="text.secondary"
                sx={{ mb: 2, textAlign: "center" }}
              >
                Credenciales por defecto: admin / password
              </Typography>

              {error && (
                <Alert severity="error" sx={{ mb: 2 }}>
                  {error}
                </Alert>
              )}

              <Box component="form" onSubmit={handleSubmit}>
                <TextField
                  margin="normal"
                  required
                  fullWidth
                  id="username"
                  label="Usuario"
                  name="username"
                  autoComplete="username"
                  autoFocus
                  value={credentials.username}
                  onChange={handleChange("username")}
                  disabled={loading}
                />

                <TextField
                  margin="normal"
                  required
                  fullWidth
                  name="password"
                  label="Contraseña"
                  type="password"
                  id="password"
                  autoComplete="current-password"
                  value={credentials.password}
                  onChange={handleChange("password")}
                  disabled={loading}
                />

                <Button
                  type="submit"
                  fullWidth
                  variant="contained"
                  sx={{ mt: 3, mb: 2 }}
                  disabled={
                    loading || !credentials.username || !credentials.password
                  }
                >
                  {loading ? "Iniciando sesión..." : "Iniciar Sesión"}
                </Button>
              </Box>
            </CardContent>
          </Card>

          <Typography
            variant="body2"
            color="text.secondary"
            sx={{ mt: 4, textAlign: "center" }}
          >
            Panel de administración de Noot Not
            <br />
            Solo personal autorizado
          </Typography>
        </Box>
      </Container>
    </ThemeProvider>
  );
}
