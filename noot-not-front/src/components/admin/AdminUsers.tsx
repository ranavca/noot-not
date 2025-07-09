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
  IconButton,
  Tooltip,
} from "@mui/material";
import { Add, Edit, PersonAdd } from "@mui/icons-material";
import { adminService } from "../../services/adminService";
import type { AdminUser, AdminCreateUser } from "../../types/admin";

interface UserDialogProps {
  open: boolean;
  user: AdminUser | null;
  onClose: () => void;
  onSave: (userData: AdminCreateUser) => void;
  isCreating: boolean;
}

function UserDialog({
  open,
  user,
  onClose,
  onSave,
  isCreating,
}: UserDialogProps) {
  const [formData, setFormData] = useState<AdminCreateUser>({
    username: "",
    password: "",
    role: "admin",
  });

  useEffect(() => {
    if (user && !isCreating) {
      setFormData({
        username: user.username,
        password: "", // Don't populate password for editing
        role: user.role,
      });
    } else {
      setFormData({
        username: "",
        password: "",
        role: "admin",
      });
    }
  }, [user, isCreating]);

  const handleSubmit = () => {
    onSave(formData);
  };

  const isValid =
    formData.username.trim() !== "" &&
    (isCreating ? formData.password.trim() !== "" : true);

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>
        <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
          <PersonAdd />
          {isCreating ? "Crear Nuevo Usuario Admin" : "Editar Usuario Admin"}
        </Box>
      </DialogTitle>
      <DialogContent>
        <Box sx={{ pt: 2 }}>
          <TextField
            fullWidth
            label="Nombre de Usuario"
            value={formData.username}
            onChange={(e) =>
              setFormData({ ...formData, username: e.target.value })
            }
            sx={{ mb: 2 }}
            required
          />

          <TextField
            fullWidth
            label={isCreating ? "Contraseña" : "Nueva Contraseña (opcional)"}
            type="password"
            value={formData.password}
            onChange={(e) =>
              setFormData({ ...formData, password: e.target.value })
            }
            sx={{ mb: 2 }}
            required={isCreating}
            helperText={
              isCreating
                ? "Requerido para nuevos usuarios"
                : "Dejar vacío para mantener contraseña actual"
            }
          />

          <FormControl fullWidth>
            <InputLabel>Rol</InputLabel>
            <Select
              value={formData.role}
              onChange={(e) =>
                setFormData({
                  ...formData,
                  role: e.target.value as "admin" | "super_admin",
                })
              }
            >
              <MenuItem value="admin">Admin</MenuItem>
              <MenuItem value="super_admin">Super Admin</MenuItem>
            </Select>
          </FormControl>
        </Box>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancelar</Button>
        <Button onClick={handleSubmit} variant="contained" disabled={!isValid}>
          {isCreating ? "Crear" : "Actualizar"}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

export function AdminUsers() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null);
  const [isCreating, setIsCreating] = useState(false);

  const loadUsers = useCallback(async () => {
    try {
      setLoading(true);
      const response = await adminService.getAdminUsers();
      setUsers(response.users);
    } catch (err: unknown) {
      const errorMessage =
        err instanceof Error ? err.message : "Error al cargar usuarios";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const handleCreateNew = () => {
    setSelectedUser(null);
    setIsCreating(true);
    setDialogOpen(true);
  };

  const handleEdit = (user: AdminUser) => {
    setSelectedUser(user);
    setIsCreating(false);
    setDialogOpen(true);
  };

  const handleSave = async (userData: AdminCreateUser) => {
    try {
      if (isCreating) {
        await adminService.createAdminUser(userData);
      } else {
        // Note: Update functionality would need to be implemented in adminService
        // For now, just close the dialog
        console.log("Update user functionality not implemented yet");
      }

      setDialogOpen(false);
      await loadUsers();
    } catch (err: unknown) {
      const errorMessage =
        err instanceof Error ? err.message : "Error al guardar usuario";
      setError(errorMessage);
    }
  };

  const getRoleColor = (role: string): "primary" | "secondary" => {
    return role === "super_admin" ? "primary" : "secondary";
  };

  const getRoleLabel = (role: string): string => {
    return role === "super_admin" ? "Super Admin" : "Admin";
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
          Gestión de Usuarios Admin
        </Typography>

        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={handleCreateNew}
        >
          Nuevo Usuario
        </Button>
      </Box>

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
                <TableCell>Usuario</TableCell>
                <TableCell>Rol</TableCell>
                <TableCell>Estado</TableCell>
                <TableCell>Fecha de Creación</TableCell>
                <TableCell>Último Login</TableCell>
                <TableCell>Acciones</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {users.map((user) => (
                <TableRow key={user.id}>
                  <TableCell>{user.id}</TableCell>
                  <TableCell>
                    <Typography variant="body2" fontWeight="medium">
                      {user.username}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={getRoleLabel(user.role)}
                      color={getRoleColor(user.role)}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={user.active ? "Activo" : "Inactivo"}
                      color={user.active ? "success" : "error"}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2">
                      {new Date(user.created_at).toLocaleDateString()}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2">
                      {user.last_login
                        ? new Date(user.last_login).toLocaleDateString()
                        : "Nunca"}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Tooltip title="Editar">
                      <IconButton size="small" onClick={() => handleEdit(user)}>
                        <Edit />
                      </IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Card>

      <UserDialog
        open={dialogOpen}
        user={selectedUser}
        onClose={() => setDialogOpen(false)}
        onSave={handleSave}
        isCreating={isCreating}
      />
    </Box>
  );
}
