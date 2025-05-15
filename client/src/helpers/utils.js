/**
 * Utility Functions for Cryptographic Operations
 *
 * Provides reusable helper functions for encoding, decoding, and nonce generation
 * used in secure WebSocket communication with AES-GCM encryption.
 *
 * Functions:
 * - hexToBytes(hex): Converts a hexadecimal string to a Uint8Array
 * - bytesToHex(bytes): Converts a Uint8Array to a hexadecimal string
 * - generateNonce(): Generates a 96-bit nonce (12 bytes) using timestamp and randomness
 *
 * These utilities are essential for encoding and decoding payloads and
 * ensuring secure, unique nonces for every encrypted message.
 *
 * Author: Andrej Kudriavcev
 * Last Updated: 15/05/2025
 */

/**
 * Converts a hexadecimal string to a Uint8Array.
 * @param hex - The hexadecimal string to convert.
 * @returns {Uint8Array} - The converted Uint8Array.
 */
export const hexToBytes = (hex) =>
    new Uint8Array(hex.match(/.{2}/g).map((b) => parseInt(b, 16)));

/**
 * Converts a Uint8Array to a hexadecimal string.
 * @param bytes - The Uint8Array to convert.
 * @returns {string} - The converted hexadecimal string.
 */
export const bytesToHex = (bytes) =>
    Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");

/**
 * Generates a 96-bit nonce (12 bytes) using the current timestamp and randomness.
 * @returns {Uint8Array} - The generated nonce as a Uint8Array.
 */
export const generateNonce = () => {
    // Get the current timestamp in nanoseconds
    const timestampNs = BigInt(Date.now()) * 1000000n;
    // Generate a random 32-bit suffix
    const randomSuffix = BigInt(Math.floor(Math.random() * 2 ** 32));
    // Combine the timestamp and random suffix into a single 96-bit integer
    const nonceBigInt = (timestampNs << 32n) | randomSuffix;
    // Convert the nonce to a hexadecimal string and pad it to 24 characters
    const hex = nonceBigInt.toString(16).padStart(24, "0");
    // Convert the hexadecimal string to a Uint8Array
    return hexToBytes(hex);
};