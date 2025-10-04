/**
 * App Configuration
 *
 * Provides build-time configuration values for the frontend.
 * This includes settings like WebSocket server URL.
 *
 * Configuration Priority:
 * 1. Build-time environment variable VITE_WS_URL (base; '/ws' appended automatically)
 * 2. Default to same-origin '/ws'
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

// No runtime configuration is used anymore

/**
 * Dynamic WebSocket URL based on runtime and environment variables
 */
export const getWebSocketURL = async () => getWebSocketURLSync();

// Synchronous version for backward compatibility (uses build-time config)
export const getWebSocketURLSync = () => {
  const base = (import.meta.env.VITE_WS_URL || '').trim();
  const wsPath = '/ws';

  if (base) {
    // Ensure trailing '/ws' is present exactly once
    const noSlash = base.endsWith('/') ? base.slice(0, -1) : base;
    const url = `${noSlash}${wsPath}`;
    console.log("[CONFIG] Using VITE_WS_URL base with '/ws':", url);
    return url;
  }

  // Default to same-origin '/ws'
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const host = window.location.hostname;
  const port = window.location.port ? `:${window.location.port}` : '';
  const url = `${protocol}//${host}${port}${wsPath}`;
  console.log("[CONFIG] Using same-origin WS URL:", url);
  return url;
};

// Keep backward compatibility
export const WS_URL = getWebSocketURLSync();
