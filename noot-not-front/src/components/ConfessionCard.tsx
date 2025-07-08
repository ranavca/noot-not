import React from "react";
import {
  Card,
  CardContent,
  Typography,
  Box,
  IconButton,
  Chip,
  Menu,
  MenuItem,
  Divider,
  Avatar,
} from "@mui/material";
import {
  MoreVert,
  Flag,
  AccessTime,
  ExpandLess,
  ExpandMore,
} from "@mui/icons-material";
import type { Confession, VoteType } from "../types";

interface ConfessionCardProps {
  confession: Confession;
  onVote: (id: number, voteType: VoteType) => void;
  onReport: (id: number) => void;
}

export const ConfessionCard: React.FC<ConfessionCardProps> = ({
  confession,
  onVote,
  onReport,
}) => {
  const [anchorEl, setAnchorEl] = React.useState<null | HTMLElement>(null);
  const open = Boolean(anchorEl);

  const handleMenuClick = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
  };

  const handleReport = () => {
    onReport(confession.id);
    handleMenuClose();
  };

  const formatTimeAgo = (date: Date) => {
    const now = new Date();
    const diffInMinutes = Math.floor(
      (now.getTime() - date.getTime()) / (1000 * 60)
    );

    if (diffInMinutes < 1) return "recién ahora";
    if (diffInMinutes < 60) return `hace ${diffInMinutes}m`;
    if (diffInMinutes < 1440) return `hace ${Math.floor(diffInMinutes / 60)}h`;
    return `hace ${Math.floor(diffInMinutes / 1440)}d`;
  };

  const getVoteScore = () => confession.upvotes - confession.downvotes;

  return (
    <Card sx={{ mb: 3, maxWidth: 600, mx: "auto", position: "relative" }}>
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
              <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
                <AccessTime sx={{ fontSize: 14, color: "text.secondary" }} />
                <Typography variant="caption" color="text.secondary">
                  {formatTimeAgo(confession.timestamp)}
                </Typography>
              </Box>
            </Box>
          </Box>

          <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
            {confession.reported && (
              <Chip
                label="Reportado"
                size="small"
                color="warning"
                variant="outlined"
                sx={{ fontSize: "0.75rem" }}
              />
            )}
            <IconButton size="small" onClick={handleMenuClick}>
              <MoreVert sx={{ fontSize: 18 }} />
            </IconButton>
          </Box>
        </Box>

        {/* Content */}
        <Typography
          variant="body1"
          sx={{
            mb: 3,
            lineHeight: 1.7,
            color: "text.primary",
            fontSize: "1rem",
          }}
        >
          {confession.content}
        </Typography>

        <Divider sx={{ mb: 2 }} />

        {/* Actions */}
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
            <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
              <IconButton
                size="small"
                onClick={() => onVote(confession.id, "up")}
                sx={{
                  backgroundColor:
                    confession.userVote === "up"
                      ? "primary.main"
                      : "transparent",
                  color:
                    confession.userVote === "up" ? "white" : "text.secondary",
                  "&:hover": {
                    backgroundColor: "primary.main",
                    color: "white",
                    transform: "scale(1.1)",
                  },
                  transition: "all 0.2s ease-in-out",
                  border: "1px solid",
                  borderColor:
                    confession.userVote === "up" ? "primary.main" : "divider",
                }}
              >
                <ExpandLess sx={{ fontSize: 16 }} />
              </IconButton>
              <Typography
                variant="body2"
                sx={{ minWidth: 24, textAlign: "center", fontWeight: 500 }}
              >
                {confession.upvotes}
              </Typography>
            </Box>

            <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
              <IconButton
                size="small"
                onClick={() => onVote(confession.id, "down")}
                sx={{
                  backgroundColor:
                    confession.userVote === "down"
                      ? "text.secondary"
                      : "transparent",
                  color:
                    confession.userVote === "down" ? "white" : "text.secondary",
                  "&:hover": {
                    backgroundColor: "text.secondary",
                    color: "white",
                    transform: "scale(1.1)",
                  },
                  transition: "all 0.2s ease-in-out",
                  border: "1px solid",
                  borderColor:
                    confession.userVote === "down"
                      ? "text.secondary"
                      : "divider",
                }}
              >
                <ExpandMore sx={{ fontSize: 16 }} />
              </IconButton>
              <Typography
                variant="body2"
                sx={{ minWidth: 24, textAlign: "center", fontWeight: 500 }}
              >
                {confession.downvotes}
              </Typography>
            </Box>
          </Box>

          {/* Vote Score */}
          <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
            <Typography
              variant="body2"
              sx={{
                fontWeight: 600,
                color:
                  getVoteScore() > 0
                    ? "success.main"
                    : getVoteScore() < 0
                    ? "error.main"
                    : "text.secondary",
              }}
            >
              {getVoteScore() > 0 ? `+${getVoteScore()}` : getVoteScore()}
            </Typography>
          </Box>
        </Box>

        <Menu
          anchorEl={anchorEl}
          open={open}
          onClose={handleMenuClose}
          anchorOrigin={{
            vertical: "bottom",
            horizontal: "right",
          }}
          transformOrigin={{
            vertical: "top",
            horizontal: "right",
          }}
          PaperProps={{
            sx: {
              border: "1px solid",
              borderColor: "divider",
              boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
            },
          }}
        >
          <MenuItem onClick={handleReport} disabled={confession.reported}>
            <Flag sx={{ mr: 1, fontSize: 18 }} />
            {confession.reported ? "Ya reportado" : "Reportar"}
          </MenuItem>
        </Menu>
      </CardContent>
    </Card>
  );
};
