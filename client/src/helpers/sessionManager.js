/**
 * Session Initialisation Utility
 *
 * Establishes a secure WebSocket session with the server for UDPChat-AI.
 * Generates a 2048-bit RSA key pair using node-forge, sends the public key
 * to the server via `SESSION_INIT`, and listens for encrypted messages.
 *
 * Features:
 * - RSA key generation with async callback
 * - WebSocket connection setup and management
 * - Sends public key to the server in Base64-encoded DER format
 * - Passes all incoming messages to the global `messageRouter`
 * - Stores the generated keypair in a `ref` for use in encryption
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Import necessary libraries and utilities
import forge from "node-forge";
import workerUrl from 'node-forge/dist/prime.worker.min.js?url';
import { messageRouter } from "./messageRouter";
import { getWebSocketURL } from "../config";

/**
 * Initialises a secure WebSocket session with the server.
 * @param setSocket - Function to set the WebSocket connection
 * @param setLoading - Function to set the loading state
 * @param keypairRef - Ref to store the generated RSA keypair
 * @returns {Promise<unknown>} - A promise that resolves when the session is initialised
 */
export async function initSession({ setSocket, setLoading, keypairRef }) {
    // Set loading state to true
    setLoading(true);


    // Return a promise that resolves when the RSA key pair is generated
    return new Promise((resolve) => {
        const options = {
            bits: 1024,
            workers: -1,
            workerScript: workerUrl
        };

        forge.pki.rsa.generateKeyPair(options, async (err, keypair) => {
            // Check for errors during key generation
            if (err) {
                console.error("❌ RSA key generation failed:", err);
                setLoading(false);
                resolve(false);
                return;
            }

            // Store the generated keypair in the ref
            keypairRef.current = keypair;

            // Convert the public key to DER format and encode it in Base64
            const pubDer = forge.asn1.toDer(forge.pki.publicKeyToAsn1(keypair.publicKey)).getBytes();
            // Encode the DER format public key in Base64
            const pubBase64 = btoa(pubDer);
            console.log("[WS] Public key (Base64):", pubBase64);
            // Create a new WebSocket connection to the server
            const wsUrl = await getWebSocketURL();
            console.log("[WS] Attempting to connect to:", wsUrl);
            const ws = new WebSocket(wsUrl);
            // Set the WebSocket connection to the state
            setSocket(ws);
            // Log the connection status
            console.log("[WS] Connection saved..");

            // Set up WebSocket onopen event handler
            ws.onopen = () => {
                console.log("[WS] Connected. Sending SESSION_INIT");
                // Send the public key to the server in a SESSION_INIT message
                ws.send(JSON.stringify({ type: "SESSION_INIT", client_key: pubBase64 }));
            };

            // Set up WebSocket onmessage event handler
            ws.onmessage = (event) => {
                try {
                    // Parse the incoming message as JSON
                    const msg = JSON.parse(event.data);
                    // Send the message to the message router
                    messageRouter(msg);
                } catch (error) {
                    console.error("❌ Failed to parse WebSocket message:", error);
                }
            };

            ws.onerror = (error) => {
                console.error("❌ WebSocket error:", error);
                setLoading(false);
                setSocket(null);
            };

            // Set up WebSocket onclose event handler
            ws.onclose = () => {
                console.log("[WS] Connection closed");
                setLoading(false);
                setSocket(null);
            };

            // Set up WebSocket onerror event handler
            resolve(true);
        });
    });
}

