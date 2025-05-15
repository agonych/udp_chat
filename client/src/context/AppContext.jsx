/**
 * AppContext Provider
 *
 * Manages global application state for the UDPChat-AI frontend, including:
 * - Session and encryption key management
 * - User authentication and login flows
 * - Room list, current room, members, messages
 * - AI interaction modes and message input
 *
 * Includes logic for:
 * - Handling secure encrypted packets from the server
 * - Automatically acknowledging messages
 * - Updating room state dynamically (joins, leaves, messages)
 * - Triggering AI responses when in "bot" mode
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and hooks
import {createContext, useContext, useState} from "react";
import {sendEncrypted} from "../helpers/secureTransport";

// Create a context for the application
export const AppContext = createContext(null);

/**
 * AppProvider Component
 * @param children
 * @returns {JSX.Element}
 */
export const AppProvider = ({ children }) => {
    const [socket, setSocket] = useState(null); // WebSocket connection
    const [sessionId, setSessionId] = useState(null); // Session ID for the user
    const [aesKey, setAesKey] = useState(null); // Session AES encryption key
    const [user, setUser] = useState(null); // Current user object
    const [loading, setLoading] = useState(true); // Loading state for the app
    const [requirePassword, setRequirePassword] = useState(false); // Flag to indicate if password is required
    const [pendingEmail, setPendingEmail] = useState(null); // Email pending for password request
    const [roomList, setRoomList] = useState([]); // List of available chat rooms
    const [currentRoom, setCurrentRoom] = useState(null); // Current room object
    const [members, setMembers] = useState([]); // List of members in the current room
    const [messages, setMessages] = useState([]); // List of messages in the current room
    const [messageInput, setMessageInput] = useState(""); // Input value for sending messages
    const [aiMode, setAiMode] = useState("user"); // AI interaction mode (user or bot)

    /**
     * Function to log in the user
     * @param user - User object containing user details
     */
    const login = (user) => {
        console.log("Logging in user:", user);
        // Save user information
        setUser(user);
        if (user.room) {
            // If the user is already in a room, set it as the current room
            setCurrentRoom(user.room);
        } else {
            // If no room is set, clear the current room
            setCurrentRoom(null);
        }
        // Set loading state to false
        setLoading(false);
        // Clear password and email flags
        setRequirePassword(false);
        setPendingEmail(null);
    };

    /**
     * Function to log out the user
     * Clears session and user data
     */
    const logout = () => {
        console.log("Logging out user, clearing session...");
        try {
            setUser(null); // Clear user data
            setSessionId(null); // Clear session ID
            setAesKey(null); // Clear AES key
            setRequirePassword(false); // Reset password requirement
            setPendingEmail(null); // Clear pending email
        } catch (err) {
            console.warn("Error during logout:", err);
        } finally {
            // Close the WebSocket connection if it exists
            if (socket?.readyState === WebSocket.OPEN) {
                socket.close();
            }
            // Clear the socket reference
            setSocket(null);
        }
    };

    // Handle decrypted secure messages
    const handleSecurePayload = (payload) => {
        console.log("🔒 Received secure payload:", payload);
        // Get the message ID from the payload if available
        const {msg_id} = payload;
        if (msg_id) {
            // Acknowledge the message ID received by sending an ACK response
            sendEncrypted({
                type: "ACK",
                data: { msg_id }
            }, { socket, aesKey, sessionId });
        }
        // Handle different types of secure messages
        switch (payload.type) {
            case "WELCOME":
                // Handle welcome message - login the user
                login(payload.data.user);
                break;
            case "ERROR":
                // Handle error messages - display alert
                alert(payload.data.message);
                setLoading(false);
                break;
            case "STATUS":
                // Handle status messages - update user status
                setUser(payload.data.user);
                setLoading(false);
                break;
            case "PLEASE_LOGIN":
                // Handle login request - the password is required for the user
                setPendingEmail(payload.data.email);
                setRequirePassword(true);
                setLoading(false);
                break;
            case "UNAUTHORISED":
                // Handle unauthorised access - display alert
                alert("Login failed. Please try again.");
                setRequirePassword(false);
                setPendingEmail(null);
                setLoading(false);
                break;
            case "MERGE_SESSION_FAILED":
                // Handle session merge failure - fail silently
                setLoading(false);
                break;
            case "ROOM_LIST":
                // Handle room list update - set the room list state
                setRoomList(payload.data || []);
                break;
            case "ROOM_CREATED":
                // Handle room creation - set the current room
                console.log("Room created:", payload.data);
                setCurrentRoom(payload.data);
                break;
            case "JOINED_ROOM":
                // Handle room join - set the current room and update members
                setCurrentRoom(payload.data);
                break;
            case "ROOM_MEMBERS":
                // Handle room members update - set the members state
                setMembers(payload.data || []);
                break;
            case "ROOM_HISTORY":
                // Handle room history update - set the messages state
                setMessages(payload.data || []);
                break;
            case "MESSAGE":
                // Handle new message - save message to the chat history
                // Check if the message is from the current room first
                if (payload.data.room_id === currentRoom?.room_id) {
                    // Add the message to the end of the messages array
                    setMessages((prevMessages) => {
                        const newMessages = [...prevMessages];
                        // Check if the message already exists in the array
                        const index = newMessages.findIndex(message => message.message_id === payload.data.message_id);
                        if (index === -1) {
                            // If the message doesn't exist, add it to the array
                            newMessages.push(payload.data);
                        }
                        return newMessages;
                    });
                }
                // If the mode is AI bot and the message is not from the
                // current user, request a response from the AI
                if (payload.data.user_id !== user?.user_id && aiMode === "bot") {
                    // Send a secure message to the AI to request a response
                    sendEncrypted({
                        type: "AI_MESSAGE",
                        data: {
                            room_id: payload.data.room_id,
                        }
                    }, { socket, aesKey, sessionId });
                }
                break;
            case "MEMBER_JOINED":
                // Handle member join - update the members list
                if (payload.data.room_id === currentRoom?.room_id) {
                    setMembers((prevMembers) => {
                        const newMembers = [...prevMembers];
                        const index = newMembers.findIndex(member => member.user_id === payload.data.member.user_id);
                        if (index === -1) {
                            newMembers.push(payload.data.member);
                        }
                        return newMembers;
                    });
                }
                break;
            case "MEMBER_LEFT":
                // Handle member leave - update the members list
                if (payload.data.room_id === currentRoom?.room_id) {
                    setMembers((prevMembers) => {
                        return prevMembers.filter(member => member.user_id !== payload.data.member_id);
                    });
                }
                break;
            default:
                // Unknown message type - log a warning
                console.warn("Unhandled SECURE_MSG type:", payload);
        }
    };

    // Return the context provider with all the state and functions
    return (
        <AppContext.Provider
            value={{
                socket, setSocket, // WebSocket connection
                sessionId, setSessionId, // Session ID
                aesKey, setAesKey, // AES encryption key
                user, setUser, // User object
                login, logout, // Login and logout functions
                loading, setLoading, // Loading state
                requirePassword, setRequirePassword, // Password requirement flag
                pendingEmail, setPendingEmail, // Pending email for password request
                handleSecurePayload, // Function to handle secure payloads
                roomList, setRoomList, // List of available rooms
                currentRoom, setCurrentRoom, // Current room object
                members, setMembers, // List of members in the current room
                messages, setMessages, // List of messages in the current room
                messageInput, setMessageInput, // Input value for sending messages
                aiMode, setAiMode, // AI interaction mode
            }}
        >
            {children}
        </AppContext.Provider>
    );
};

/**
 * useApp Hook
 * @returns {Object} - Returns the context value
 */
export const useApp = () => {
    // Get the context value
    const context = useContext(AppContext);
    if (!context) {
        // If context is not available, throw an error
        throw new Error("useApp must be used within an AppProvider");
    }
    // Return the context value
    return context;
};