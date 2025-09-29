/**
 * useSession Hook
 *
 * Handles session initialization, secure key exchange, and session merging for UDPChat-AI.
 *
 * Features:
 * - Establishes a secure session via RSA handshake using Web Crypto and node-forge
 * - Verifies server public key using a fingerprint with SHA-256
 * - Decrypts AES session key and validates signature from the server
 * - Stores verified fingerprint in localStorage for TOFU (Trust On First Use) model
 * - Persists and merges previous session if available
 *
 * Depends on:
 * - AppContext for session state (socket, sessionId, aesKey, etc.)
 * - registerHandler() to bind SESSION_INIT handler
 * - initSession() to start key generation and WebSocket handshake
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */


import {useEffect, useRef} from "react";
import forge from "node-forge";

// Disable workers globally to prevent prime.worker.js requests
forge.options = forge.options || {};
forge.options.workers = 0;
import {useApp} from "../context/AppContext";
import {bytesToHex, hexToBytes} from "../helpers/utils";
import {registerHandler} from "../helpers/messageRouter";
import {initSession} from "../helpers/sessionManager";
import { sendEncrypted } from "../helpers/secureTransport";

/**
 * Verifies the server's fingerprint against the public key.
 * @param serverPubkeyHex - Hexadecimal representation of the server's public key
 * @param claimedFingerprint - The claimed fingerprint to verify against
 * @returns {Promise<boolean>} - True if the fingerprint matches, false otherwise
 */
export async function verifyServerFingerprint(serverPubkeyHex, claimedFingerprint) {
    // Check if crypto.subtle is available (requires HTTPS)
    if (!crypto.subtle) {
        console.warn("[FINGERPRINT] crypto.subtle not available (requires HTTPS), skipping fingerprint verification");
        return true; // Skip verification on HTTP
    }
    
    // Convert the server public key from hex to bytes
    const pubkeyBytes = new Uint8Array(serverPubkeyHex.match(/.{2}/g).map(b => parseInt(b, 16)));
    // Hash the public key using SHA-256
    const hashBuffer = await crypto.subtle.digest("SHA-256", pubkeyBytes);
    // Convert the hash to a hexadecimal string
    const hashHex = Array.from(new Uint8Array(hashBuffer))
        .map(b => b.toString(16).padStart(2, "0")) // Convert each byte to hex
        .join(""); // Join the hex values into a single string

    // Compare the computed hash with the claimed fingerprint
    return hashHex === claimedFingerprint.toLowerCase();
}

/**
 * Custom hook to manage the session state and handle session initialization.
 */
export function useSession() {
    // Get the necessary state and functions from the App context
    const { socket, setSocket, sessionId, setSessionId, aesKey, setAesKey, setLoading } = useApp();
    // Create refs to store the RSA keypair and initialization state
    const keypairRef = useRef(null);
    // Ref to track if the session has been initialized
    const hasInitialized = useRef(false);

    // Effect to register the SESSION_INIT handler
    useEffect(() => {
        // Register the handler for incoming SESSION_INIT messages
        registerHandler("SESSION_INIT", async (msg) => {
            // Check if the socket is available
            const keypair = keypairRef.current;
            if (!keypair) return;

            // Get the necessary data from the incoming message
            const { session_id, encrypted_key, signature, server_pubkey, fingerprint } = msg;

            // Check if the server fingerprint is already stored
            const old_fingerprint = localStorage.getItem("server-fingerprint");
            if (!old_fingerprint) {
                // If missing will trust the first connection (TOFU)
                console.warn("⚠️ No server fingerprint found. This is the first connection.");
            } else if (old_fingerprint !== fingerprint) {
                // If the fingerprint doesn't match, warn about a possible MITM attack
                console.warn("⚠️ Server fingerprint mismatch. Possible MITM attack!");
                return;
            }

            // verify server fingerprint
            const valid = await verifyServerFingerprint(server_pubkey, fingerprint);
            if (!valid) {
                // If the fingerprint verification fails, log an error
                console.error("❌ Server fingerprint does not match public key!");
                return;
            }
            // If the fingerprint matches, log a success message
            console.log("✅ Server fingerprint verified.");

            // Save the server fingerprint to localStorage for future reference
            localStorage.setItem("server-fingerprint", fingerprint);

            // Decrypt the AES key using the RSA private key
            let decryptedKey;
            try {
                // Decrypt the AES key using the private key
                decryptedKey = keypair.privateKey.decrypt(
                    forge.util.hexToBytes(encrypted_key), // Encrypted AES key
                    "RSA-OAEP", // RSA encryption scheme
                    {
                        md: forge.md.sha256.create(), // Hash function
                        mgf1: { md: forge.md.sha256.create() }, // Mask generation function
                    }
                );
            } catch (err) {
                // If decryption fails, log an error
                console.error("❌ Failed to decrypt AES key:", err);
                return;
            }

            // Convert the decrypted key to a hexadecimal string
            const decryptedKeyBytes = new Uint8Array(Array.from(decryptedKey, c => c.charCodeAt(0)));
            // Check if the decrypted key is valid
            const aesKeyHex = bytesToHex(decryptedKeyBytes);
            // Convert the server public key from hex to bytes
            const serverKeyBytes = hexToBytes(server_pubkey);
            // Convert the signature from hex to bytes
            const sigBytes = hexToBytes(signature);
            try {
                // Check if crypto.subtle is available (requires HTTPS)
                if (!window.crypto.subtle) {
                    console.warn("[SIGNATURE] crypto.subtle not available (requires HTTPS), skipping signature verification");
                    // Save the session ID and AES key to the state, set loading to false
                    setSessionId(session_id);
                    setAesKey(aesKeyHex);
                    setLoading(false);
                    console.log("✅ Session established.");
                    return;
                }
                
                // Import the server public key for signature verification
                const cryptoKey = await window.crypto.subtle.importKey(
                    "spki",
                    serverKeyBytes.buffer,
                    { name: "RSA-PSS", hash: "SHA-256" },
                    false,
                    ["verify"]
                );

                // Verify the signature using the server public key
                const verified = await window.crypto.subtle.verify(
                    { name: "RSA-PSS", saltLength: 32 },
                    cryptoKey,
                    sigBytes.buffer,
                    decryptedKeyBytes.buffer
                );

                // Check if the signature verification was successful
                if (!verified) {
                    // If the verification fails, log an error
                    console.error("❌ Signature verification failed");
                    return;
                }

                // Save the session ID and AES key to the state, set loading to false
                setSessionId(session_id);
                setAesKey(aesKeyHex);
                setLoading(false);
                // Log success message
                console.log("✅ Session established.");
            } catch (err) {
                // If signature verification fails, log an error
                console.error("❌ Signature validation error:", err);
            }
        });
    }, [setSessionId, setAesKey, setLoading]);

    // Effect to handle session merging
    useEffect(() => {
        // Check if the socket, session ID, and AES key are available
        if (!socket || !sessionId || !aesKey) return;

        // Get the old session ID and key from localStorage
        const old_session_id = localStorage.getItem("session-id");
        const old_session_key = localStorage.getItem("session-key");

        // Save the current session ID and AES key to localStorage
        localStorage.setItem("session-id", sessionId);
        localStorage.setItem("session-key", aesKey);

        // Compare the old session ID with the current session ID
        if (old_session_id && old_session_key && old_session_id !== sessionId) {
            // If they are different, send a session merge request to the server
            sendEncrypted({
                type: "MERGE_SESSION",
                data: {
                    old_session_id,
                    old_session_key,
                },
            }, { socket, aesKey, sessionId }).then(() => {
                // Log merge request success
                console.log("Session merge request sent");
            });
        }
    }, [socket, sessionId, aesKey]);


    // Effect to initialize the session
    useEffect(() => {
        // Check that initialization has not already occurred
        if (hasInitialized.current) return;
        hasInitialized.current = true;

        // Initialize the session
        initSession({ setSocket, setLoading, keypairRef }).then((success) => {
            if (!success) {
                // If initialization fails, log an error and set loading to false
                console.error("❌ Session initialization failed.");
                setLoading(false);
                return;
            }
            // If initialization is successful, log a success message
            console.log("✅ Session initialized.");
        });
    }, []);
}
