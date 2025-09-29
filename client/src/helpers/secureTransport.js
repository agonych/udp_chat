/**
 * Secure Transport Utilities
 *
 * Provides AES-GCM-based message encryption and decryption over WebSocket.
 * This module is responsible for sending and receiving encrypted packets
 * in the UDPChat-AI system.
 *
 * Features:
 * - `sendEncrypted()`: Encrypts a payload with AES-GCM and sends it over WebSocket.
 * - `receiveEncrypted()`: Decrypts an incoming SECURE_MSG and verifies nonce for replay protection.
 * - Uses Web Crypto API for secure key handling and encryption.
 * - Handles base16 hex conversions and nonce generation.
 * - Guards against replay attacks by tracking seen nonces.
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and utilities
import { generateNonce, hexToBytes, bytesToHex } from "./utils";

/**
 * Function to send an encrypted message over WebSocket.
 * @param payload - The payload to be encrypted and sent.
 * @param socket - The WebSocket connection to send the message through.
 * @param aesKey - The AES key used for encryption.
 * @param sessionId - The session ID for the current connection.
 * @returns {Promise<void>} - A promise that resolves when the message is sent.
 */
export async function sendEncrypted(payload, { socket, aesKey, sessionId }) {
    console.log("🔒 Sending encrypted message:", payload);
    // Check if all required parameters are provided
    if (!socket || !aesKey || !sessionId) {
        // Log a warning if any parameter is missing
        console.warn("❌ Cannot sendEncrypted - missing session state", {
            socket,
            aesKey,
            sessionId,
        });
        return;
    }

    // Generate a nonce for the message
    const nonce = generateNonce();
    // Convert the AES key from hex to bytes
    const aesKeyBytes = hexToBytes(aesKey);

    // Wrap the payload in a try-catch block to handle encryption errors
    try {
        // Check if crypto.subtle is available (requires secure context)
        if (!crypto.subtle) {
            console.error("❌ crypto.subtle not available - requires secure context (HTTPS or localhost)");
            return;
        }
        
        // Import the AES key for encryption
        const key = await crypto.subtle.importKey("raw", aesKeyBytes, "AES-GCM", false, ["encrypt"]);
        // Encrypt the payload using AES-GCM
        const encoded = new TextEncoder().encode(JSON.stringify(payload));
        // Encrypt the payload with the generated nonce
        const ciphertext = await crypto.subtle.encrypt(
            { name: "AES-GCM", iv: nonce },
            key,
            encoded
        );

        // Send the encrypted message over WebSocket
        socket.send(JSON.stringify({
            type: "SECURE_MSG", // Set the message type to SECURE_MSG
            session_id: sessionId, // Include the session ID
            nonce: bytesToHex(nonce), // Include the nonce in hex format
            ciphertext: bytesToHex(new Uint8Array(ciphertext)), // Include the ciphertext in hex format
        }));
    } catch (err) {
        // Log an error if encryption fails
        console.error("❌ AES encryption failed:", err);
    }
}

/**
 * Function to receive and decrypt an encrypted message.
 * @param message - The encrypted message to be decrypted.
 * @param aesKey - The AES key used for decryption.
 * @param handleSecurePayload - Callback function to handle the decrypted payload.
 * @param seenNonces - Set to track seen nonces and prevent replay attacks.
 * @returns {Promise<void>} - A promise that resolves when the message is processed.
 */
export async function receiveEncrypted(message, { aesKey, handleSecurePayload, seenNonces }) {
    // Get the nonce and ciphertext from the message
    const { nonce, ciphertext } = message;

    // Check if all required parameters are provided
    if (!nonce || !ciphertext || !aesKey) {
        // Log a warning if any parameter is missing
        console.warn("❌ Incomplete SECURE_MSG");
        return;
    }

    // Check if the nonce has already been seen
    if (seenNonces.has(nonce)) {
        // Log a warning if the nonce is a replay
        console.warn("⚠️ Replay detected! Nonce already seen:", nonce);
        return;
    }
    // Add the nonce to the set of seen nonces
    seenNonces.add(nonce);

    // Wrap the decryption process in a try-catch block to handle errors
    try {
        // Check if crypto.subtle is available (requires secure context)
        if (!crypto.subtle) {
            console.error("❌ crypto.subtle not available - requires secure context (HTTPS or localhost)");
            return;
        }
        
        // Import the AES key for decryption
        const aesKeyBytes = hexToBytes(aesKey);
        // Convert the ciphertext from hex to bytes
        const key = await crypto.subtle.importKey("raw", aesKeyBytes, "AES-GCM", false, ["decrypt"]);
        // Decrypt the ciphertext using AES-GCM
        const decryptedBuffer = await crypto.subtle.decrypt(
            { name: "AES-GCM", iv: hexToBytes(nonce) }, // Use the nonce as the IV
            key, // The imported AES key
            hexToBytes(ciphertext) // The ciphertext in bytes
        );

        // Get the decrypted payload and parse it as JSON
        const payload = JSON.parse(new TextDecoder().decode(decryptedBuffer));

        // Handle the decrypted payload using the provided callback function
        handleSecurePayload(payload);
    } catch (err) {
        // If any error occurs during decryption or handling, log it
        console.error("❌ Decryption failed:", err);
    }
}
