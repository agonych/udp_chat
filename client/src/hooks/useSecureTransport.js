/**
 * useSecureTransport Hook
 *
 * Registers a handler for incoming SECURE_MSG packets and decrypts them
 * using the current AES session key from AppContext. Prevents replay attacks
 * by tracking seen nonces in a ref.
 *
 * Responsibilities:
 * - Listens for SECURE_MSG messages
 * - Decrypts payloads with AES-GCM
 * - Passes decrypted data to `handleSecurePayload`
 * - Tracks and ignores reused nonces
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and hooks
import { useEffect, useRef } from "react";
import { useApp } from "../context/AppContext";
import { registerHandler } from "../helpers/messageRouter";
import { receiveEncrypted } from "../helpers/secureTransport";

/**
 * Custom hook to handle secure transport.
 */
export function useSecureTransport() {
    // Get the AES key and secure payload handler from App context
    const { aesKey, handleSecurePayload } = useApp();
    // Create a ref to track seen nonces
    const seenNonces = useRef(new Set());

    // Effect to register the SECURE_MSG handler
    useEffect(() => {
        // Register the handler for incoming SECURE_MSG messages
        registerHandler("SECURE_MSG", (msg) =>
            // Call receiveEncrypted to decrypt the message
            receiveEncrypted(
                msg, // Encrypted message
                {
                    aesKey, // AES key for decryption
                    handleSecurePayload, // Callback to handle decrypted payload
                    seenNonces: seenNonces.current, // Set to track seen nonces
                }
            )
        );
    }, [aesKey, handleSecurePayload]);
}
