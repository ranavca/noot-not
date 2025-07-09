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
  Alert,
  CircularProgress,
  Pagination,
  IconButton,
  Tooltip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
} from "@mui/material";
import { CheckCircle, Visibility, Flag } from "@mui/icons-material";
import { adminService } from "../../services/adminService";
import type { Report } from "../../types/admin";

export function AdminReports() {
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [selectedReport, setSelectedReport] = useState<Report | null>(null);
  const [detailDialogOpen, setDetailDialogOpen] = useState(false);

  const loadReports = useCallback(async () => {
    try {
      setLoading(true);
      const response = await adminService.getReports("pending", page);
      setReports(response.reports);
      setTotalPages(Math.ceil(response.total / 20)); // Assuming 20 per page
    } catch (err: unknown) {
      const errorMessage =
        err instanceof Error ? err.message : "Error al cargar reportes";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, [page]);

  useEffect(() => {
    loadReports();
  }, [loadReports]);

  const handleResolveReport = async (reportId: number, action: string = "dismiss") => {
    try {
      await adminService.resolveReport(reportId, action);
      await loadReports();
    } catch (err: unknown) {
      const errorMessage =
        err instanceof Error ? err.message : "Error al resolver reporte";
      setError(errorMessage);
    }
  };

  const handleViewDetails = (report: Report) => {
    setSelectedReport(report);
    setDetailDialogOpen(true);
  };

  const getStatusColor = (status: string): "warning" | "success" | "info" => {
    switch (status) {
      case "resolved":
        return "success";
      case "reviewed":
        return "info";
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
      <Typography variant="h4" component="h1" sx={{ mb: 3 }}>
        Gestión de Reportes
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <Card>
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>Confesión ID</TableCell>
                <TableCell>Razón</TableCell>
                <TableCell>Estado</TableCell>
                <TableCell>Fecha</TableCell>
                <TableCell>Revisado Por</TableCell>
                <TableCell>Acciones</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {reports.map((report) => (
                <TableRow key={report.id}>
                  <TableCell>{report.id}</TableCell>
                  <TableCell>{report.confession_id}</TableCell>
                  <TableCell>
                    <Typography
                      variant="body2"
                      sx={{
                        maxWidth: 200,
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        whiteSpace: "nowrap",
                      }}
                    >
                      {report.reason || "Sin especificar"}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={report.status}
                      color={getStatusColor(report.status)}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2">
                      {new Date(report.created_at).toLocaleDateString()}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2">
                      {report.reviewed_by || "-"}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Box sx={{ display: "flex", gap: 1 }}>
                      <Tooltip title="Ver detalles">
                        <IconButton
                          size="small"
                          onClick={() => handleViewDetails(report)}
                        >
                          <Visibility />
                        </IconButton>
                      </Tooltip>

                      {report.status === "pending" && (
                        <Tooltip title="Resolver">
                          <IconButton
                            size="small"
                            color="success"
                            onClick={() => handleResolveReport(report.id)}
                          >
                            <CheckCircle />
                          </IconButton>
                        </Tooltip>
                      )}
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

      {/* Report Details Dialog */}
      <Dialog
        open={detailDialogOpen}
        onClose={() => setDetailDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
            <Flag />
            Detalles del Reporte #{selectedReport?.id}
          </Box>
        </DialogTitle>
        <DialogContent>
          {selectedReport && (
            <Box sx={{ pt: 2 }}>
              <Typography variant="h6" gutterBottom>
                Información del Reporte
              </Typography>

              <Box sx={{ mb: 2 }}>
                <Typography variant="body2" color="text.secondary">
                  Confesión ID: {selectedReport.confession_id}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Reportado el:{" "}
                  {new Date(selectedReport.created_at).toLocaleString()}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Estado: {selectedReport.status}
                </Typography>
                {selectedReport.reviewed_by && (
                  <Typography variant="body2" color="text.secondary">
                    Revisado por: {selectedReport.reviewed_by}
                  </Typography>
                )}
                {selectedReport.reviewed_at && (
                  <Typography variant="body2" color="text.secondary">
                    Revisado el:{" "}
                    {new Date(selectedReport.reviewed_at).toLocaleString()}
                  </Typography>
                )}
              </Box>

              <Typography variant="h6" gutterBottom sx={{ mt: 3 }}>
                Razón del Reporte
              </Typography>
              <Typography variant="body1">
                {selectedReport.reason || "Sin razón especificada"}
              </Typography>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDetailDialogOpen(false)}>Cerrar</Button>
          {selectedReport?.status === "pending" && (
            <Button
              variant="contained"
              color="success"
              startIcon={<CheckCircle />}
              onClick={() => {
                if (selectedReport) {
                  handleResolveReport(selectedReport.id);
                  setDetailDialogOpen(false);
                }
              }}
            >
              Resolver
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Box>
  );
}
