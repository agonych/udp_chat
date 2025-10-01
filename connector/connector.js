/**
 * WebSocket-to-UDP bridge for forwarding encrypted client messages to a local UDP server.
 *
 * This script acts as a bridge between browser-based WebSocket clients and a UDP server
 * running on localhost. Each WebSocket connection is assigned a unique session and a dedicated
 * UDP socket. Messages from the browser are forwarded to the UDP server, and responses from
 * the server are sent back to the corresponding WebSocket client.
 *
 * Key features:
 * - Maintains individual UDP sockets per WebSocket session
 * - Automatically cleans up sessions after 10 minutes of inactivity
 * - Handles connection errors and disconnections gracefully
 *
 * Usage:
 * - Start this bridge on a host where the UDP server is accessible via UDP_SERVER_HOST:UDP_SERVER_PORT
 * - Clients should connect via WebSocket to ws://<host>:WS_PORT
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

require('dotenv').config(); // Load environment variables from .env file

const dgram = require('dgram'); // UDP socket library
const WebSocket = require('ws'); // WebSocket library
const { v4: uuidv4 } = require('uuid'); // UUID library for generating unique session IDs
const { register, websocketConnections, websocketMessagesReceived, websocketMessagesSent, udpMessagesReceived, udpMessagesSent, messageProcessingTime } = require('./metrics');

const UDP_SERVER_HOST = process.env.UDP_SERVER_HOST || '127.0.0.1'; // UDP server host
const UDP_SERVER_PORT = parseInt(process.env.UDP_SERVER_PORT, 10) || 9999; // UDP server port
const WS_PORT = parseInt(process.env.WS_PORT, 10) || 8000; // WebSocket server port
const METRICS_PORT = parseInt(process.env.METRICS_PORT, 10) || 3000; // Metrics server port
const INACTIVITY_TIMEOUT_MS = parseInt(process.env.INACTIVITY_TIMEOUT_MS, 10) || 600000; // 10 minutes

// Create HTTP server for metrics
const http = require('http');
const metricsServer = http.createServer(async (req, res) => {
  if (req.url === '/metrics') {
    res.setHeader('Content-Type', register.contentType);
    res.end(await register.metrics());
  } else {
    res.statusCode = 404;
    res.end('Not found');
  }
});

metricsServer.listen(METRICS_PORT, () => {
  console.log(`[Bridge] Metrics server listening on http://localhost:${METRICS_PORT}/metrics`);
});

// Create a UDP socket for sending messages to the UDP server
const wss = new WebSocket.Server({ port: WS_PORT });
console.log(`[Bridge] WebSocket server listening on ws://localhost:${WS_PORT}`);

// Array to hold active sessions
const sessions = new Map(); // sessionId -> { udpSocket, ws, timer }

/**
 * Function to clean up a session after a period of inactivity.
 * Closes the UDP socket and WebSocket connection, and removes the session from the sessions map.
 * @param {string} sessionId - The ID of the session to clean up.
 * @returns {void}
 */
function cleanupSession(sessionId) {
    // Get the session associated with the sessionId
    const session = sessions.get(sessionId);
    // If the session exists
    if (session) {
        console.log(`[Bridge] Cleaning up session ${sessionId}`);
        session.udpSocket.close(); // Close the UDP socket
        // Close the WebSocket connection if it's open
        if (session.ws.readyState === WebSocket.OPEN) {
            session.ws.close();
        }
        // Clear the timer to prevent further cleanup
        clearTimeout(session.timer);
        // Remove the session from the sessions map
        sessions.delete(sessionId);
    }
}

/**
 * Function to reset the inactivity timeout for a session.
 * Clears the existing timer and sets a new one for the session.
 * @param {string} sessionId - The ID of the session to reset the timeout for.
 * @returns {void}
 */
function resetTimeout(sessionId) {
    // Get the session associated with the sessionId
    const session = sessions.get(sessionId);
    // If the session exists
    if (session) {
        clearTimeout(session.timer); // Clear the existing timer
        // Set a new timer to clean up the session after the inactivity timeout
        session.timer = setTimeout(() => {
            cleanupSession(sessionId);
        }, INACTIVITY_TIMEOUT_MS);
    }
}

// Handle incoming WebSocket connections
wss.on('connection', (ws) => {
    // Generate a unique session ID for the new connection
    const sessionId = uuidv4();
    console.log(`[<<<] WebSocket client connected (session: ${sessionId})`);

    // Increment WebSocket connections counter
    websocketConnections.inc();

    // Set up a message handler for the WebSocket connection
    const udpSocket = dgram.createSocket('udp4');
    // Bind the UDP socket to a random (not specified) port
    udpSocket.bind(() => {
        // Get the port assigned to the UDP socket
        const udpPort = udpSocket.address().port;
        console.log(`[!!!] UDP socket bound to port ${udpPort}`);
    });

    // Set up a message handler for incoming UDP messages
    udpSocket.on('message', (msg) => {
        console.log(`[>>>] UDP message from server (session: ${sessionId})`);
        // Increment UDP messages received counter
        udpMessagesReceived.inc();
        // Send the UDP message to the WebSocket client
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(msg.toString());
            // Increment WebSocket messages sent counter
            websocketMessagesSent.inc();
            // Reset the inactivity timeout for the session
            resetTimeout(sessionId);
        }
    });

    // Set up a message handler for incoming WebSocket messages
    ws.on('message', (data) => {
        console.log(`[<<<] Message from WebSocket client (session: ${sessionId})`);
        // Increment WebSocket messages received counter
        websocketMessagesReceived.inc();
        // Send the message to the UDP server
        udpSocket.send(data, UDP_SERVER_PORT, UDP_SERVER_HOST);
        // Increment UDP messages sent counter
        udpMessagesSent.inc();
        console.log(`[>>>] Forwarded message to UDP server (session: ${sessionId})`);
        resetTimeout(sessionId);
    });

    // Set up a close handler for the WebSocket connection
    ws.on('close', () => {
        console.log(`[XXX] WebSocket closed (session: ${sessionId})`);
        // Decrement WebSocket connections counter
        websocketConnections.dec();
        // Clean up the session when the WebSocket connection is closed
        cleanupSession(sessionId);
    });

    // Set up an error handler for the WebSocket connection
    ws.on('error', (err) => {
        console.error(`[!!!] WebSocket error (session: ${sessionId}):`, err);
        // Clean up the session on error
        cleanupSession(sessionId);
    });

    // Save the session information in the sessions array
    sessions.set(sessionId, {
        udpSocket, // UDP socket for this session
        ws, // WebSocket connection for this session
        timer: setTimeout(() => cleanupSession(sessionId), INACTIVITY_TIMEOUT_MS) // Inactivity timer
    });
});
