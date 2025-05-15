/**
 * LoginForm Component
 *
 * Handles user authentication in two stages:
 * - Initial login request with email
 * - Password prompt if required by server
 *
 * Displays loading indicator during network activity,
 * disables inputs when waiting, and switches between
 * email and password modes based on app state.
 *
 * Uses secure messaging (AES-encrypted) to transmit credentials.
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and components
import { useState } from "react";
import {
    Button,
    TextField,
    Typography,
    Box,
    CircularProgress,
} from "@mui/material";
import { useApp } from "../context/AppContext.jsx";
import { useSecureMessage } from "../hooks/useSecureMessage";

/**
 * LoginForm Component
 * @returns {JSX.Element}
 * @constructor
 */
export default function LoginForm() {
    // State variables for email and password
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");

    // Context variables from AppContext
    const {
        setLoading,
        loading,
        requirePassword,
        pendingEmail
    } = useApp();

    // Function to send secure messages
    const sendEncrypted = useSecureMessage();

    // Handle form submission
    const handleSubmit = (e) => {
        // Prevent default form submission
        e.preventDefault();
        // Set loading state
        setLoading(true);

        // Check if password is required
        if (requirePassword) {
            // If password is required, send email and password
            sendEncrypted({
                type: "LOGIN",
                data: { email: pendingEmail, password },
            });
        } else {
            // If password is not required, send email only
            sendEncrypted({
                type: "LOGIN",
                data: { email },
            });
        }
    };

    return (
        <Box component="form" onSubmit={handleSubmit} noValidate>
            {/* Display title based on app state */}
            <Typography variant="body1" gutterBottom>
                {requirePassword ? "Enter your password" : "Please log in"}
            </Typography>

            {/* Display email input field if password is not required */}
            {!requirePassword && (
                <TextField
                    fullWidth
                    label="Email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    type="email"
                    margin="normal"
                    required
                    disabled={loading}
                />
            )}

            {requirePassword && (
                <TextField
                    fullWidth
                    label="Password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    type="password"
                    margin="normal"
                    required
                    autoFocus
                    disabled={loading}
                />
            )}

            {/* Submit button */}
            <Box mt={2}>
                <Button
                    fullWidth
                    type="submit"
                    variant="contained"
                    disabled={loading || (!requirePassword && !email)}
                >
                    {loading ? <CircularProgress size={20} /> : "Login"}
                </Button>
            </Box>
        </Box>
    );
};

