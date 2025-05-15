/**
 * useKeepAlive Hook
 *
 * Periodically sends a `STATUS` packet to the server to keep the session alive.
 * This helps prevent session timeouts and ensures the connection remains active.
 *
 * Sends a packet every 10 seconds if the socket, AES key, and session ID are available.
 * Cleans up the interval when the component using this hook unmounts.
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and hooks
import { useEffect } from "react";
import { sendEncrypted } from "../helpers/secureTransport";
import { useApp } from "../context/AppContext";

/**
 * Custom hook to send keep-alive status messages.
 */
export function useKeepAlive() {
    // Get the socket, AES key, and session ID from the App context
    const { socket, aesKey, sessionId } = useApp();

    // Effect to send keep-alive status messages
    useEffect(() => {
        // Check if all required parameters are provided
        if (!socket || !aesKey || !sessionId) return;
4
        // Set up an interval to send keep-alive status messages
        const interval = setInterval(() => {
            console.log("Sending keep-alive status");
            // Send a secure message with the status type
            sendEncrypted({ type: "STATUS" }, { socket, sessionId, aesKey }).then(() => {
                console.log("Keep-alive status sent");
            });
        }, 10000); // Every 10 seconds

        // Clear the interval when the component unmounts or dependencies change
        return () => clearInterval(interval);
    }, [socket, aesKey, sessionId]);
}