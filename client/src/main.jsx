/**
 * Entry Point for UDPChat-AI Client
 *
 * This file renders the main React application into the DOM.
 * It sets up:
 * - StrictMode for highlighting potential issues
 * - Material UI ThemeProvider and CssBaseline for consistent styling
 * - AppProvider context to manage global app state
 * - Application component (App)
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and components
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import { CssBaseline } from "@mui/material";
import { ThemeProvider } from "@mui/material/styles";
import theme from "./theme";
import { AppProvider } from "./context/AppContext";

// Create a root element for rendering
createRoot(document.getElementById("root")).render(
    <StrictMode>
        <ThemeProvider theme={theme}>
            <CssBaseline />
            <AppProvider>
                <App />
            </AppProvider>
        </ThemeProvider>
    </StrictMode>
);
