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

// Dynamic WebSocket URL based on environment variables
export const getWebSocketURL = () => {
  // Check for explicit WebSocket URL first
  if (import.meta.env.VITE_WS_URL) {
    console.log("[CONFIG] Using environment WebSocket URL:", import.meta.env.VITE_WS_URL);
    return import.meta.env.VITE_WS_URL;
  }
  
  // Use connector service details from environment variables
  const wsHost = import.meta.env.VITE_WS_HOST || window.location.hostname;
  const wsPort = import.meta.env.VITE_WS_PORT;
  const wsPath = import.meta.env.VITE_WS_PATH || '/ws';
  
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  
  // Build WebSocket URL
  let wsUrl;
  if (wsPort) {
    // Use explicit host:port configuration (for direct connector access)
    wsUrl = `${protocol}//${wsHost}:${wsPort}${wsPath}`;
  } else {
    // Fallback to same host with path (for nginx proxy setups)
    // For nginx proxy, use the same host and port as the current page
    const currentPort = window.location.port ? `:${window.location.port}` : '';
    wsUrl = `${protocol}//${wsHost}${currentPort}${wsPath}`;
  }
  
  console.log("[CONFIG] Generated WebSocket URL:", wsUrl);
  return wsUrl;
};

// Keep backward compatibility
export const WS_URL = getWebSocketURL();
