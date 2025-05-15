/**
 * Message Router Utility
 *
 * Provides a simple registry-based mechanism for routing decrypted secure messages
 * by their `type` field to registered handler functions.
 *
 * Usage:
 * - Use `registerHandler(type, fn)` to register a callback for a given message type.
 * - Call `messageRouter(msg)` to dispatch a message to its registered handler.
 *
 * If no handler is found for a given type, a warning is logged.
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */


// Define a registry for message handlers
const handlers = {};

/**
 * Register a handler for a specific message type.
 * @param type - The type of message to handle.
 * @param fn - The function to call when a message of this type is received.
 */
export const registerHandler = (type, fn) => {
    // Add the handler to the registry
    handlers[type] = fn;
};

/**
 * Route a message to its registered handler.
 * @param msg - The message object to route.
 */
export const messageRouter = (msg) => {
    // Check if the message type is registered
    if (handlers[msg.type]) {
        // Call the registered handler with the message
        handlers[msg.type](msg);
    } else {
        // Log a warning if no handler is found
        console.warn("Unhandled message type:", msg.type);
    }
};
