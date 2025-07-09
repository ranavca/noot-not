import { useState } from "react";
import {
  Box,
  Card,
  CardContent,
  Typography,
  TextField,
  Button,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Alert,
  CircularProgress,
} from "@mui/material";
import { Save, Article } from "@mui/icons-material";
import { adminService } from "../../services/adminService";

export function AdminCreate() {
  const [content, setContent] = useState("");
  const [status, setStatus] = useState<"pending" | "approved" | "rejected">(
    "approved"
  );
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!content.trim()) {
      setError("El contenido es requerido");
      return;
    }

    try {
      setLoading(true);
      setError("");
      setSuccess("");

      await adminService.createConfession(content.trim(), status);

      setSuccess("Confesión creada exitosamente");
      setContent("");
      setStatus("approved");
    } catch (err: unknown) {
      const errorMessage =
        err instanceof Error ? err.message : "Error al crear la confesión";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography
        variant="h4"
        component="h1"
        sx={{ mb: 3, display: "flex", alignItems: "center", gap: 1 }}
      >
        <Article />
        Crear Nueva Confesión
      </Typography>

      <Card sx={{ maxWidth: 800 }}>
        <CardContent sx={{ p: 4 }}>
          {success && (
            <Alert severity="success" sx={{ mb: 2 }}>
              {success}
            </Alert>
          )}

          {error && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {error}
            </Alert>
          )}

          <Box component="form" onSubmit={handleSubmit}>
            <TextField
              fullWidth
              label="Contenido de la Confesión"
              multiline
              rows={6}
              value={content}
              onChange={(e) => setContent(e.target.value)}
              sx={{ mb: 3 }}
              required
              placeholder="Escribe el contenido de la confesión aquí..."
              helperText={`${content.length} caracteres`}
            />

            <FormControl fullWidth sx={{ mb: 3 }}>
              <InputLabel>Estado de Moderación</InputLabel>
              <Select
                value={status}
                onChange={(e) =>
                  setStatus(
                    e.target.value as "pending" | "approved" | "rejected"
                  )
                }
              >
                <MenuItem value="approved">Aprobado</MenuItem>
                <MenuItem value="pending">Pendiente</MenuItem>
                <MenuItem value="rejected">Rechazado</MenuItem>
              </Select>
            </FormControl>

            <Box sx={{ display: "flex", gap: 2 }}>
              <Button
                type="submit"
                variant="contained"
                size="large"
                startIcon={loading ? <CircularProgress size={20} /> : <Save />}
                disabled={loading || !content.trim()}
                sx={{ minWidth: 150 }}
              >
                {loading ? "Creando..." : "Crear Confesión"}
              </Button>

              <Button
                variant="outlined"
                size="large"
                onClick={() => {
                  setContent("");
                  setStatus("approved");
                  setError("");
                  setSuccess("");
                }}
                disabled={loading}
              >
                Limpiar
              </Button>
            </Box>
          </Box>

          <Box sx={{ mt: 3, p: 2, bgcolor: "grey.50", borderRadius: 1 }}>
            <Typography variant="body2" color="text.secondary">
              <strong>Nota:</strong> Las confesiones creadas desde el panel de
              administración se marcarán como creadas por un administrador. Se
              generarán imágenes automáticamente una vez que la confesión sea
              guardada.
            </Typography>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
}
