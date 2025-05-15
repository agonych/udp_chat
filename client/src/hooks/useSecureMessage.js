/**
 * useSecureMessage Hook
 *
 * Provides a convenient wrapper around `sendEncrypted`, binding it
 * to the current session's socket, AES key, and session ID from AppContext.
 *
 * Usage:
 *   const sendSecure = useSecureMessage();
 *   sendSecure({ type: "LOGIN", data: {...} });
 *
 * Ensures that encryption context is always up to date with the current app state.
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */


import {useCallback} from "react";
import {useApp} from "../context/AppContext";
import {sendEncrypted as coreSendEncrypted} from "../helpers/secureTransport";

/**
 * Custom hook to send encrypted messages.
 * @returns {function(*): Promise<void>}
 */
export function useSecureMessage() {
    // Get the socket, session ID, and AES key from the App context
    const { socket, sessionId, aesKey } = useApp();

    // Return a memoized function that sends encrypted messages
    return useCallback((payload) => {
        return coreSendEncrypted(payload, {socket, sessionId, aesKey});
    }, [socket, sessionId, aesKey]);
}
