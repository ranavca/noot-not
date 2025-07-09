import { useState, useEffect, useCallback } from "react";
import {
  Box,
  Card,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Alert,
  CircularProgress,
  Pagination,
  IconButton,
  Tooltip,
} from "@mui/material";
import {
  Edit,
  Delete,
  Add,
  CheckCircle,
  Cancel,
  HourglassEmpty,
  Report as ReportIcon,
} from "@mui/icons-material";
import { adminService } from "../../services/adminService";
import type { AdminConfession } from "../../types/admin";

interface ConfessionDialogProps {
  open: boolean;
  confession: AdminConfession | null;
  onClose: () => void;
  onSave: (confession: Partial<AdminConfession>) => void;
  isCreating: boolean;
}

function ConfessionDialog({
  open,
  confession,
  onClose,
  onSave,
  isCreating,
}: ConfessionDialogProps) {
  const [formData, setFormData] = useState<{
    content: string;
    moderation_status: "pending" | "approved" | "rejected";
  }>({
    content: "",
    moderation_status: "pending",
  });

  useEffect(() => {
    if (confession) {
      setFormData({
        content: confession.content,
        moderation_status: confession.moderation_status,
      });
    } else {
      setFormData({
        content: "",
        moderation_status: "pending",
      });
    }
  }, [confession]);

  const handleSubmit = () => {
    onSave(formData);
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>
        {isCreating ? "Crear Nueva Confesión" : "Editar Confesión"}
      </DialogTitle>
      <DialogContent>
        <Box sx={{ pt: 2 }}>
          <TextField
            fullWidth
            label="Contenido"
            multiline
            rows={4}
            value={formData.content}
            onChange={(e) =>
              setFormData({ ...formData, content: e.target.value })
            }
            sx={{ mb: 2 }}
          />

          <FormControl fullWidth>
            <InputLabel>Estado de Moderación</InputLabel>
            <Select
              value={formData.moderation_status}
              onChange={(e) =>
                setFormData({
                  ...formData,
                  moderation_status: e.target.value as
                    | "pending"
                    | "approved"
                    | "rejected",
                })
              }
            >
              <MenuItem value="pending">Pendiente</MenuItem>
              <MenuItem value="approved">Aprobado</MenuItem>
              <MenuItem value="rejected">Rechazado</MenuItem>
            </Select>
          </FormControl>
        </Box>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancelar</Button>
        <Button onClick={handleSubmit} variant="contained">
          {isCreating ? "Crear" : "Guardar"}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

export function AdminConfessions() {
  const [confessions, setConfessions] = useState<AdminConfession[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [statusFilter, setStatusFilter] = useState("all");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [selectedConfession, setSelectedConfession] =
    useState<AdminConfession | null>(null);
  const [isCreating, setIsCreating] = useState(false);

  const loadConfessions = useCallback(async () => {
    try {
      setLoading(true);
      const response = await adminService.getConfessions(statusFilter, page);
      setConfessions(response.confessions);
      setTotalPages(response.total_pages);
    } catch (err: unknown) {
      const errorMessage =
        err instanceof Error ? err.message : "Error al cargar confesiones";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, [statusFilter, page]);

  useEffect(() => {
    loadConfessions();
  }, [loadConfessions]);

  const handleCreateNew = () => {
    setSelectedConfession(null);
    setIsCreating(true);
    setDialogOpen(true);
  };

  const handleEdit = (confession: AdminConfession) => {
    setSelectedConfession(confession);
    setIsCreating(false);
    setDialogOpen(true);
  };

  const handleSave = async (confessionData: Partial<AdminConfession>) => {
    try {
      if (isCreating) {
        await adminService.createConfession(
          confessionData.content!,
          confessionData.moderation_status!
        );
      } else if (selectedConfession) {
        await adminService.updateConfessionStatus(
          selectedConfession.id,
          confessionData.moderation_status!
        );
      }

      setDialogOpen(false);
      await loadConfessions();
    } catch (err: unknown) {
      const errorMessage =
        err instanceof Error ? err.message : "Error al guardar confesión";
      setError(errorMessage);
    }
  };

  const handleDelete = async (id: number) => {
    if (
      window.confirm("¿Estás seguro de que quieres eliminar esta confesión?")
    ) {
      try {
        await adminService.deleteConfession(id);
        await loadConfessions();
      } catch (err: unknown) {
        const errorMessage =
          err instanceof Error ? err.message : "Error al eliminar confesión";
        setError(errorMessage);
      }
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "approved":
        return <CheckCircle color="success" />;
      case "rejected":
        return <Cancel color="error" />;
      default:
        return <HourglassEmpty color="warning" />;
    }
  };

  const getStatusColor = (status: string): "success" | "error" | "warning" => {
    switch (status) {
      case "approved":
        return "success";
      case "rejected":
        return "error";
      default:
        return "warning";
    }
  };

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", mt: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      <Box
        sx={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          mb: 3,
        }}
      >
        <Typography variant="h4" component="h1">
          Gestión de Confesiones
        </Typography>

        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={handleCreateNew}
        >
          Nueva Confesión
        </Button>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <Box sx={{ mb: 2 }}>
        <FormControl size="small" sx={{ minWidth: 120 }}>
          <InputLabel>Estado</InputLabel>
          <Select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <MenuItem value="all">Todos</MenuItem>
            <MenuItem value="pending">Pendientes</MenuItem>
            <MenuItem value="approved">Aprobados</MenuItem>
            <MenuItem value="rejected">Rechazados</MenuItem>
          </Select>
        </FormControl>
      </Box>

      <Card>
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>Contenido</TableCell>
                <TableCell>Estado</TableCell>
                <TableCell>Votos</TableCell>
                <TableCell>Reportes</TableCell>
                <TableCell>Fecha</TableCell>
                <TableCell>Acciones</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {confessions.map((confession) => (
                <TableRow key={confession.id}>
                  <TableCell>{confession.id}</TableCell>
                  <TableCell>
                    <Typography
                      variant="body2"
                      sx={{
                        maxWidth: 300,
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        whiteSpace: "nowrap",
                      }}
                    >
                      {confession.content}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Chip
                      icon={getStatusIcon(confession.moderation_status)}
                      label={confession.moderation_status}
                      color={getStatusColor(confession.moderation_status)}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2">
                      👍 {confession.upvotes} / 👎 {confession.downvotes}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {confession.reports > 0 && (
                      <Chip
                        icon={<ReportIcon />}
                        label={confession.reports}
                        color="warning"
                        size="small"
                      />
                    )}
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2">
                      {new Date(confession.created_at).toLocaleDateString()}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Box sx={{ display: "flex", gap: 1 }}>
                      <Tooltip title="Editar">
                        <IconButton
                          size="small"
                          onClick={() => handleEdit(confession)}
                        >
                          <Edit />
                        </IconButton>
                      </Tooltip>

                      <Tooltip title="Eliminar">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => handleDelete(confession.id)}
                        >
                          <Delete />
                        </IconButton>
                      </Tooltip>
                    </Box>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>

        <Box sx={{ display: "flex", justifyContent: "center", p: 2 }}>
          <Pagination
            count={totalPages}
            page={page}
            onChange={(_, value) => setPage(value)}
            color="primary"
          />
        </Box>
      </Card>

      <ConfessionDialog
        open={dialogOpen}
        confession={selectedConfession}
        onClose={() => setDialogOpen(false)}
        onSave={handleSave}
        isCreating={isCreating}
      />
    </Box>
  );
}
