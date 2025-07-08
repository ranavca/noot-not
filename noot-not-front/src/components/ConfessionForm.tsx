import React, { useState } from "react";
import {
  Card,
  CardContent,
  TextField,
  Button,
  Box,
  Typography,
  Alert,
  Avatar,
  Divider,
} from "@mui/material";
import { Send, Close } from "@mui/icons-material";

interface ConfessionFormProps {
  onSubmit: (content: string) => Promise<void>;
  onClose: () => void;
}

export const ConfessionForm: React.FC<ConfessionFormProps> = ({
  onSubmit,
  onClose,
}) => {
  const [content, setContent] = useState("");
  const [error, setError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const maxLength = 500;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!content.trim()) {
      setError("Por favor escribe tu confesión");
      return;
    }

    if (content.length > maxLength) {
      setError(`La confesión debe tener ${maxLength} caracteres o menos`);
      return;
    }

    setIsSubmitting(true);
    setError("");

    try {
      await onSubmit(content.trim());
      setContent("");
    } catch (err) {
      setError("Error al publicar la confesión. Inténtalo de nuevo.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setContent(value);

    if (error) {
      setError("");
    }
  };

  return (
    <Card sx={{ mb: 3, maxWidth: 600, mx: "auto" }}>
      <CardContent sx={{ p: 3 }}>
        {/* Header */}
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            mb: 2,
          }}
        >
          <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
            <Avatar
              sx={{
                width: 32,
                height: 32,
                bgcolor: "primary.main",
                fontSize: "0.875rem",
                fontWeight: 600,
              }}
            >
              A
            </Avatar>
            <Box>
              <Typography
                variant="body2"
                sx={{ fontWeight: 600, color: "text.primary" }}
              >
                Anónimo
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Comparte tus pensamientos
              </Typography>
            </Box>
          </Box>

          <Button
            onClick={onClose}
            size="small"
            sx={{
              minWidth: "auto",
              p: 1,
              color: "text.secondary",
              "&:hover": { backgroundColor: "action.hover" },
            }}
          >
            <Close sx={{ fontSize: 18 }} />
          </Button>
        </Box>

        <Divider sx={{ mb: 2 }} />

        {error && (
          <Alert
            severity="error"
            sx={{ mb: 2, border: "1px solid", borderColor: "error.main" }}
          >
            {error}
          </Alert>
        )}

        <Box component="form" onSubmit={handleSubmit}>
          <TextField
            fullWidth
            multiline
            rows={4}
            placeholder="¿Qué tienes en mente? Comparte tus pensamientos de forma anónima..."
            value={content}
            onChange={handleChange}
            variant="outlined"
            sx={{
              mb: 2,
              "& .MuiOutlinedInput-root": {
                borderRadius: 2,
                "&:hover .MuiOutlinedInput-notchedOutline": {
                  borderColor: "primary.main",
                },
              },
            }}
            InputProps={{
              sx: {
                fontSize: "1rem",
                lineHeight: 1.6,
              },
            }}
          />

          <Box
            sx={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <Typography
              variant="caption"
              sx={{
                color:
                  content.length > maxLength ? "error.main" : "text.secondary",
                fontWeight: 500,
              }}
            >
              {content.length}/{maxLength} caracteres
            </Typography>

            <Button
              type="submit"
              variant="contained"
              startIcon={<Send sx={{ fontSize: 16 }} />}
              disabled={
                !content.trim() || content.length > maxLength || isSubmitting
              }
              sx={{
                borderRadius: 3,
                px: 3,
                py: 1,
                fontWeight: 600,
                boxShadow: "none",
                "&:hover": {
                  boxShadow: "0 4px 12px rgba(220, 38, 38, 0.3)",
                  transform: "translateY(-1px)",
                },
                "&:disabled": {
                  backgroundColor: "action.disabledBackground",
                  color: "action.disabled",
                },
                transition: "all 0.2s ease-in-out",
              }}
            >
              {isSubmitting ? "Publicando..." : "Publicar"}
            </Button>
          </Box>
        </Box>
      </CardContent>
    </Card>
  );
};
