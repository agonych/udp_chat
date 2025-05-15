/**
 * App Configuration
 *
 * Provides runtime configuration values for the frontend.
 * This includes settings like WebSocket server URL, which
 * can be overridden using environment variables.
 *
 * WebSocket URL:
 * - VITE_WS_URL must be defined in a .env file (Vite standard)
 * - Falls back to ws://127.0.0.1:8080/ws by default
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

export const WS_URL = import.meta.env.VITE_WS_URL || "ws://127.0.0.1:8080/ws";
