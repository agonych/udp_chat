/**
 * App Configuration
 *
 * Provides runtime configuration values for the frontend.
 * This includes settings like WebSocket server URL, which
 * can be overridden using environment variables.
 *
 * WebSocket URL:
 * - VITE_WS_URL must be defined in a .env file (Vite standard)
 * - Falls back to ws://127.0.0.1/ws by default (through nginx proxy)
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// Dynamic WebSocket URL based on current hostname
export const getWebSocketURL = () => {
  if (import.meta.env.VITE_WS_URL) {
    console.log("[CONFIG] Using environment WebSocket URL:", import.meta.env.VITE_WS_URL);
    return import.meta.env.VITE_WS_URL;
  }
  
  // Use current hostname and protocol for WebSocket connection
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const hostname = window.location.hostname;
  const wsUrl = `${protocol}//${hostname}/ws`;
  console.log("[CONFIG] Generated WebSocket URL:", wsUrl);
  return wsUrl;
};

// Keep backward compatibility
export const WS_URL = getWebSocketURL();
