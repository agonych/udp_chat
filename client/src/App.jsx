/**
 * App Component
 *
 * Main entry point for the UDPChat-AI frontend.
 * Initializes key hooks and conditionally renders components based on application state:
 * - Displays login form if user is not authenticated
 * - Shows chat room if a room is joined
 * - Otherwise, displays available rooms
 *
 * Also:
 * - Establishes secure session and transport layers
 * - Keeps session alive via periodic STATUS pings
 * - Dynamically adjusts layout width based on chat state
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

import {
    Box,
    Typography,
    Paper,
    CircularProgress,
} from "@mui/material";
import { useApp } from "./context/AppContext";
import { useSession } from "./hooks/useSession";
import { useSecureTransport } from "./hooks/useSecureTransport";
import { useKeepAlive } from "./hooks/useKeepAlive";
import LoginForm from "./components/LoginForm";
import RoomList from "./components/RoomList";
import ChatRoom from "./components/ChatRoom.jsx";
import logo from "./assets/logo.svg"; // Adjust the path as necessary

/**
 * Main App Component
 * @returns {JSX.Element}
 * @constructor
 */
function App() {
    useSession(); // Initialize session management
    useSecureTransport(); // Set up secure transport for messages
    useKeepAlive(); // Keep the session alive
    // Import context and hooks
    const { user, loading, currentRoom, logout } = useApp();
    // Build the UI
    return (
        <Box
            sx={{
                minHeight: "100vh",
                display: "flex",
                justifyContent: "center",
                alignItems: "center",
                bgcolor: "#f5f5f5",
            }}
        >
            {/* Main container for the app */}
            <Paper
                elevation={3}
                sx={{
                    p: 4,
                    borderRadius: 2,
                    width: "100%",
                    maxWidth: currentRoom?1000:400, // change width if in the room
                    textAlign: "center",
                }}
            >
                {/* App logo */}
                <Typography variant="h4" gutterBottom>
                    {/* Display logo smaller and aligned to left if in room */}
                    <img
                        src={logo}
                        alt="Logo"
                        style={{ width: currentRoom?100:"100%", height: currentRoom?50:180, marginBottom: 16, marginRight: currentRoom?"100%":0 }}
                    />
                </Typography>
                {/* Loading spinner or content based on app state */}
                {loading ? (
                    // Show loading spinner if loading
                    <Box
                        display="flex"
                        justifyContent="center"
                        alignItems="center"
                        minHeight={100}
                        mt={3}
                    >
                        <CircularProgress />
                    </Box>
                ) : !user ? (
                    // Show login form if user is not authenticated
                    <LoginForm />
                ) : currentRoom ? (
                    // Show chat room if user is authenticated and in a room
                    <ChatRoom />
                ) : (
                    // Show room list if user is authenticated and not in a room
                    <>
                        <Typography variant="body1">Welcome, {user.name}</Typography>
                        <RoomList />
                        <Box mt={2}>
                            <Typography variant="body2" onClick={logout} sx={{ cursor: "pointer", color: "blue" }}>
                                Logout
                            </Typography>
                        </Box>
                    </>
                )}
            </Paper>
        </Box>
    );
}

export default App;
