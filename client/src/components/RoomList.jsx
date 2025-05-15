/**
 * RoomList Component
 *
 * Displays a list of available chat rooms.
 * Allows the user to join an existing room or create a new one.
 *
 * Automatically fetches the room list on first render using secure messaging.
 * Styled buttons provide a clear UI for room selection and creation.
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and components
import {
    Box,
    Button,
    List,
    ListItem,
    ListItemText,
    Typography,
} from "@mui/material";
import { useEffect } from "react";
import { useApp } from "../context/AppContext";
import { useSecureMessage } from "../hooks/useSecureMessage";

/**
 * RoomList Component
 * @returns {JSX.Element}
 * @constructor
 */
export default function RoomList() {
    // Context variables from AppContext
    const {
        roomList,
        socket,
        sessionId,
        aesKey,
    } = useApp();

    // Function to send secure messages
    const sendEncrypted = useSecureMessage();

    // Fetch the list of rooms on first render
    useEffect(() => {
        if (socket && sessionId && aesKey) {
            // Send a secure message to request the list of rooms
            sendEncrypted({ type: "LIST_ROOMS" });
        }
    }, [socket, sessionId, aesKey]);

    const handleCreate = () => {
        const name = prompt("Enter a name for the new room:");
        if (name?.trim() && socket && sessionId && aesKey) {
            // Send a secure message to create a new room
            sendEncrypted({ type: "CREATE_ROOM", data: { name: name.trim() } });
        }
    };

    // Render the room list
    return (
        <Box mt={3} textAlign="left">
            {/* Display available rooms or a message if none are available */}
            {roomList.length > 0 ? (
                <>
                <Typography variant="h6">
                    Available Rooms
                </Typography>
                <List dense>
                    {/* Map through the roomList and create a ListItem for each room */}
                    {roomList.map((room) => (
                        <ListItem
                            key={room.room_id}
                            button="true"
                            onClick={() => {
                                if (socket && sessionId && aesKey) {
                                    // Send a secure message to join the room
                                    sendEncrypted({ type: "JOIN_ROOM", data: { room_id: room.room_id } });
                                }
                            }}
                            sx={{
                                backgroundColor: "#e5effa",
                                color: "#1976d2",
                                border: "1px solid #1976d2",
                                borderRadius: 1,
                                textAlign: "center",
                                mb: 1,
                                '&:hover': {
                                    backgroundColor: "#1976d2",
                                    color: "#fff",
                                    cursor: "pointer",
                                },
                            }}
                        >
                            <ListItemText primary={room.name} />
                        </ListItem>
)                   )}
                </List>
                </>
            ) : (
                <Typography variant="body1" gutterBottom>
                    {/* Display a message if no rooms are available */}
                    No rooms available. Click &quot;Create Room&quot; to continue...
                </Typography>
            )}
            {/* Button to create a new room */}
            <Button
                fullWidth
                variant="contained"
                sx={{ mt: 2 }}
                onClick={handleCreate}
            >
                Create Room
            </Button>
        </Box>
    );
}
