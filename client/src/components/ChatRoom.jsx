/**
 * ChatRoom Component
 *
 * This component renders the main group chat interface. It includes:
 * - Message display with styling for user's own vs others' messages
 * - Auto-scrolling to the latest message
 * - AI Mode toggle (No AI, AI Helper, AI Bot)
 * - Input field and send/leave controls
 * - Dynamic list of room members
 *
 * AI Mode Behaviours:
 * - "user": Sends raw user messages
 * - "ai": Improves user's message using AI
 * - "bot": Lets AI generate the reply automatically
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and components
import {
    Box,
    Button,
    Divider,
    List,
    ListItem,
    ListItemText,
    Paper,
    TextField,
    Typography,
    ToggleButtonGroup,
    ToggleButton
} from "@mui/material";

import { useApp } from "../context/AppContext"; // Custom hook to access app context
import { useSecureMessage } from "../hooks/useSecureMessage"; // Function to send encrypted messages
import { useEffect, useRef } from "react"; // Hook to manage side effects

/**
 * ChatRoom Component
 * @returns {JSX.Element}
 * @constructor
 */
export default function ChatRoom() {
    // Accessing context values and functions
    const {
        currentRoom, setCurrentRoom,
        socket, sessionId, aesKey, user,
        members, setMembers, messages, setMessages, setMessageInput, messageInput,
        aiMode, setAiMode
    } = useApp();

    // Function to send encrypted messages
    const sendEncrypted = useSecureMessage();

    // Ref to scroll to the bottom of the messages
    const bottomRef = useRef(null);

    // Scroll to the bottom of the messages when new messages are added
    useEffect(() => {
        if (bottomRef.current) {
            bottomRef.current.scrollIntoView({ behavior: "smooth" });
        }
    }, [messages]);

    // Function to get AI hint based on the current mode
    const getAiHint = () => {
        switch (aiMode) {
            case "ai":
                return "AI Helper active";
            case "bot":
                return "AI Bot active";
            default:
                return "AI inactive";
        }
    }

    // Function to get AI prompt based on the current mode
    const getAiPrompt = () => {
        switch (aiMode) {
            case "ai":
                return "AI will improve your message...";
            case "bot":
                return "AI will reply...";
            default:
                return "Type your message...";
        }
    }

    // Function to load room data (members and message history) on mount
    const loadRoomData = () => {
        if (socket && sessionId && aesKey && currentRoom?.room_id) {
            sendEncrypted({ type: "LIST_MEMBERS", data: { room_id: currentRoom.room_id } });
            sendEncrypted({ type: "LIST_MESSAGES", data: { room_id: currentRoom.room_id } });
        }
    };

    // Load room data when the component mounts or when currentRoom, socket, sessionId, or aesKey changes
    useEffect(() => {
        loadRoomData();
    }, [currentRoom, socket, sessionId, aesKey]);

    // Handle ROOM_MEMBERS and ROOM_HISTORY messages from the server
    // This will fire when "roomdata" event is dispatched
    useEffect(() => {
        const handler = (e) => {
            const msg = e.detail;
            if (msg.type === "ROOM_MEMBERS") {
                setMembers(msg.data || []);
            } else if (msg.type === "ROOM_HISTORY") {
                setMessages(msg.data || []);
            }
        };
        window.addEventListener("roomdata", handler);
        return () => window.removeEventListener("roomdata", handler);
    }, []);


    // Handle sending messages
    const handleSend = () => {
        // Get the message content and check if the current room is set
        const content = messageInput.trim();
        if (!content || !currentRoom) return;

        // Send the encrypted message to the server
        sendEncrypted({
            type: aiMode === "user" ? "MESSAGE" : "AI_MESSAGE", // Use AI message type if AI mode is active
            data: {
                room_id: currentRoom.room_id, // Room ID
                content // Message content
            }
        });
        // Clear the message input field
        setMessageInput("");
    };

    // Handle leaving the room
    const handleLeave = () => {
        if (currentRoom) {
            // Send a leave room message to the room
            sendEncrypted({
                type: "LEAVE_ROOM",
                data: { room_id: currentRoom.room_id }
            });
            // Reset the room data
            setCurrentRoom(null);
            setMembers([]);
            setMessages([]);
        }
    };

    // Render the chat room interface
    return (
        <Box display="flex" height="80vh" width="100%" maxWidth="1000px" mx="auto" mt={4}>
            {/* Left column: Messages + Input */}
            <Box flex={1} display="flex" flexDirection="column">
                {/* Message display area */}
                <Paper sx={{ p: 2, flex: 1, overflowY: "auto", bgcolor: "#fAfAfA" }}>
                    <Typography variant="h6" gutterBottom>
                        <b>Room:</b> {currentRoom.name}
                    </Typography>
                    <Divider sx={{ mb: 2 }} />
                    {/* Message list */}
                    <List dense>
                        {messages.map((msg, index) => {
                            const isMine = msg.user_id === user?.user_id;
                            const isLast = index === messages.length - 1;
                            return (
                                <ListItem
                                    key={msg.message_id}
                                    ref={isLast ? bottomRef : null}
                                    sx={{
                                        alignItems: isMine?"flex-end":"flex-start",
                                        justifyContent: "flex-start",
                                        flexDirection: "column",
                                        px: 0,
                                    }}
                                >
                                    {/* Message timestamp and sender name */}
                                    <Typography variant="body2" color={isMine?"#659fb6":"#999"} sx={{ mb: 0.5 }}>
                                        <b>
                                            {isMine?"Me":msg.name}
                                        </b> | <em>
                                            {(() => {
                                                const ts = new Date(msg.timestamp * 1000);
                                                const date = ts.toLocaleDateString("en-AU", {
                                                    day: "2-digit",
                                                    month: "2-digit",
                                                    year: "numeric",
                                                });
                                                const time = ts.toLocaleTimeString("en-AU", {
                                                    hour: "2-digit",
                                                    minute: "2-digit",
                                                    hour12: true,
                                                });
                                                return `${date} ${time}`;
                                            })()}
                                        </em>
                                    </Typography>
                                    {/* Message content */}
                                    <Box
                                        sx={{
                                            maxWidth: "70%",
                                            bgcolor: isMine ? "#d0f0fd" : "#e0e0e0",
                                            color: "black",
                                            p: 1.5,
                                            borderRadius: 2,
                                            ml: isMine ? "auto" : 0,
                                            mr: isMine ? 0 : "auto",
                                            minWidth: "60%",
                                        }}
                                    >
                                        <Typography variant="body1">{msg.content}</Typography>
                                    </Box>
                                </ListItem>
                            );
                        })}
                    </List>
                </Paper>
                {/* AI mode switch */}
                <Box display="flex" flexDirection="column" mt={2}>
                    <Box display="flex" justifyContent="space-between" alignItems="center" mb={1}>
                        {/* AI mode toggle buttons */}
                        <ToggleButtonGroup
                            value={aiMode}
                            exclusive
                            onChange={(e, newMode) => newMode && setAiMode(newMode)}
                            size="small"
                        >
                            <ToggleButton value="user">No AI</ToggleButton>
                            <ToggleButton value="ai">AI Helper</ToggleButton>
                            <ToggleButton value="bot">AI Bot</ToggleButton>
                        </ToggleButtonGroup>
                        {/* AI mode hint */}
                        <Typography variant="caption" color="textSecondary">
                            Mode: {getAiHint()}
                        </Typography>
                    </Box>
                    {/* Message controls */}
                    <Box display="flex">
                        {/* Message input field */}
                        <TextField
                            fullWidth
                            variant="outlined"
                            value={messageInput}
                            onChange={(e) => setMessageInput(e.target.value)}
                            onKeyDown={(e) => e.key === "Enter" && handleSend()}
                            placeholder={getAiPrompt()}
                        />
                        {/* Send and leave buttons */}
                        <Button variant="contained" sx={{ ml: 1 }} onClick={handleSend}>
                            Send
                        </Button>
                        <Button variant="outlined" sx={{ ml: 1 }} onClick={handleLeave}>
                            Leave
                        </Button>
                    </Box>
                </Box>

            </Box>
            {/* Right column: Members */}
            <Paper sx={{ width: 250, p: 2, ml: 2, overflowY: "auto", bgcolor: "#fAfAfA" }}>
                {/* Room members title */}
                <Typography variant="h6" gutterBottom>
                    <b>Members</b>
                </Typography>
                <Divider sx={{ mb: 2 }} />
                {/* Members list */}
                <List dense>
                    {members.map((m, index) => (
                        <Box key={m.user_id}>
                            <ListItem sx={{ py: 0.1, px: 0 }}>
                                <ListItemText primary={m.name} primaryTypographyProps={{ fontSize: 14 }} />
                            </ListItem>
                            {index !== members.length - 1 && <Divider />}
                        </Box>
                    ))}
                </List>
            </Paper>
        </Box>
    );
}
