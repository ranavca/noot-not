import React from "react";
import { Box, Typography, IconButton, Container } from "@mui/material";
import { DarkMode, LightMode } from "@mui/icons-material";
import { useThemeContext } from "../hooks/useThemeContext";
import Pingu from "../assets/pingu.png"; // Assuming you have a Pingu image in your assets

export const Header: React.FC = () => {
  const { isDarkMode, toggleTheme } = useThemeContext();

  return (
    <Box sx={{ py: 4, mb: 2 }}>
      <Container maxWidth="md">
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
            <img src={Pingu} alt="Noot Not" style={{ height: 60 }} />
            <Box>
              <Typography
                variant="h1"
                sx={{
                  fontSize: { xs: "1.5rem", sm: "2rem" },
                  fontWeight: 700,
                  color: "text.primary",
                  lineHeight: 1.2,
                }}
              >
                Noot Not
              </Typography>
              <Typography
                variant="body2"
                sx={{
                  color: "text.secondary",
                  fontWeight: 500,
                  letterSpacing: "0.05em",
                }}
              >
                After-rajazo en la FCFM.
              </Typography>
            </Box>
          </Box>

          <IconButton
            onClick={toggleTheme}
            sx={{
              backgroundColor: "background.paper",
              border: "1px solid",
              borderColor: "divider",
              "&:hover": {
                backgroundColor: "action.hover",
                transform: "scale(1.05)",
              },
              transition: "all 0.2s ease-in-out",
            }}
          >
            {isDarkMode ? <LightMode /> : <DarkMode />}
          </IconButton>
        </Box>
      </Container>
    </Box>
  );
};
