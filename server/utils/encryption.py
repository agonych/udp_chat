"""
This module implements encryption and decryption functions for secure communication.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

# Import necessary libraries
import os
import json
import hashlib
import time
import random
import secrets
import base64

from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# Get the server's private and public key paths from the config
from config import PRIVATE_KEY_PATH, PUBLIC_KEY_PATH

def load_or_create_server_keys():
    """
    Loads or creates the server's RSA private and public keys.
    If the keys already exist, they are loaded from the specified paths.
    If they do not exist, new keys are generated and saved to the specified paths.
    :return: tuple: (private_key, public_key, fingerprint)
    """
    if os.path.exists(PRIVATE_KEY_PATH) and os.path.exists(PUBLIC_KEY_PATH):
        with open(PRIVATE_KEY_PATH, 'rb') as f:
            private_key = serialization.load_pem_private_key(f.read(), password=None)
        with open(PUBLIC_KEY_PATH, 'rb') as f:
            public_key = serialization.load_pem_public_key(f.read())
    else:
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        public_key = private_key.public_key()

        with open(PRIVATE_KEY_PATH, 'wb') as f:
            f.write(private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            ))
        with open(PUBLIC_KEY_PATH, 'wb') as f:
            f.write(public_key.public_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PublicFormat.SubjectPublicKeyInfo
            ))

    fingerprint = get_fingerprint(public_key)
    return private_key, public_key, fingerprint

def generate_random_id(length=32):
    """
    Generates a secure random ID of the specified length in hexadecimal format.
    :param length: Length of the ID in characters (must be even).
    :return: str: Random ID in hexadecimal format.
    :raises ValueError: If the length is not a positive integer or not even.
    """
    # Ensure the length is a positive integer and long enough to ensure uniqueness
    if length <= 16:
        raise ValueError("Length must be at least 16 characters.")
    # Ensure the length is even to produce full bytes
    if length % 2 != 0:
        raise ValueError("Length must be even to produce full bytes.")
    return secrets.token_hex(length // 2)

def generate_session_key():
    """
    Generates a secure random session key for AES encryption.
    :return: bytes: Random session key in bytes.
    """
    return os.urandom(32)

def encrypt_key_for_client(client_pubkey, session_key):
    """
    Encrypts the session key using the client's public RSA key.
    :param client_pubkey: The client's public key in PEM format.
    :param session_key: The session key to encrypt.
    :return: bytes: The encrypted session key.
    """
    client_pubkey_der = base64.b64decode(client_pubkey)
    client_pubkey = serialization.load_der_public_key(client_pubkey_der)
    return client_pubkey.encrypt(
        session_key,
        padding.OAEP(mgf=padding.MGF1(algorithm=hashes.SHA256()), algorithm=hashes.SHA256(), label=None)
    )
def sign_data(data: bytes, private_key) -> bytes:
    """
    Signs the given data using the server's private RSA key.
    :param data: The data to sign.
    :param private_key: The server's private key.
    :return: bytes: The signature of the data.
    """
    signature = private_key.sign(
        data,
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=32
        ),
        hashes.SHA256()
    )
    return signature

def get_server_pubkey_der(public_key):
    """
    Converts the server's public key to DER format.
    :param public_key: The server's public key.
    :return: bytes: The public key in DER format.
    """
    return public_key.public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )

def get_fingerprint(public_key):
    der = get_server_pubkey_der(public_key)
    return hashlib.sha256(der).hexdigest()

def generate_nonce():
    """
    Generate a 96-bit nonce for AES encryption and protection from replay attacks.
    The nonce is generated using the current time in nanoseconds and a random suffix.
    :return: int: The generated nonce.
    """
    # Current time in nanoseconds = 64 bits
    timestamp_ns = time.time_ns()
    # Need 96 bits nonce so adding 32 random bits
    random_suffix = random.getrandbits(32)
    # Shift nonce left by 32 bits and add random bits to the right
    return (timestamp_ns << 32) | random_suffix

def encrypt_message(session_key, nonce, payload_dict):
    """
    Encrypts a message using AES-GCM with the given session key and nonce.
    :param session_key: The session key for AES encryption.
    :param nonce: The nonce for AES encryption.
    :param payload_dict: The payload dictionary to encrypt.
    :return: bytes: The encrypted payload.
    :raises ValueError: If the encryption fails.
    """
    aes = AESGCM(bytes.fromhex(session_key))
    payload_plain = json.dumps(payload_dict).encode()
    try:
        payload_encrypted = aes.encrypt(nonce, payload_plain, None)
    except Exception as e:
        raise ValueError(f"Encryption failed: {e}")
    return payload_encrypted

def decrypt_message(session_key, nonce, ciphertext):
    """
    Decrypts a message using AES-GCM with the given session key and nonce.
    :param session_key: Session key for AES encryption.
    :param nonce: Nonce for AES encryption.
    :param ciphertext: The encrypted message to decrypt.
    :return: dict: The decrypted payload as a dictionary.
    :raises ValueError: If the decryption fails.
    """
    try:
        aes = AESGCM(bytes.fromhex(session_key))
        plaintext = aes.decrypt(
            bytes.fromhex(nonce),
            bytes.fromhex(ciphertext),
            None
        )
        return json.loads(plaintext.decode())
    except:
        raise ValueError("Invalid key or message.")
