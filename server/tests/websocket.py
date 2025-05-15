"""
WebSocket client for testing the connector.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

import json
import base64
import asyncio
import websockets

from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from server.utils.encryption import generate_nonce

CONNECTOR_WS_URL = "ws://127.0.0.1:8000/ws"

async def run_test():
    # Generate client RSA key pair
    client_private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    client_public_key = client_private_key.public_key()
    client_pubkey_der = client_public_key.public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    client_pubkey_b64 = base64.b64encode(client_pubkey_der).decode()

    async with websockets.connect(CONNECTOR_WS_URL) as ws:
        # Step 1 – Send SESSION_INIT via WebSocket
        await ws.send(json.dumps({
            "type": "SESSION_INIT",
            "client_key": client_pubkey_b64
        }))

        # Step 2 – Receive SESSION_INIT
        try:
            session_init = json.loads(await asyncio.wait_for(ws.recv(), timeout=3))
        except asyncio.TimeoutError:
            raise SystemExit("Timeout: No response from connector/server")

        required_fields = {"session_id", "encrypted_key", "server_pubkey", "signature", "fingerprint"}
        if not required_fields.issubset(session_init):
            raise SystemExit("Error: Missing fields in SESSION_INIT")

        print(f"[OK] Connected to session {session_init['session_id']}")

        # Decode and verify
        session_id = session_init["session_id"]
        server_pubkey_der = bytes.fromhex(session_init["server_pubkey"])
        encrypted_key = bytes.fromhex(session_init["encrypted_key"])
        signature = bytes.fromhex(session_init["signature"])

        server_public_key = serialization.load_der_public_key(server_pubkey_der)
        aes_key = client_private_key.decrypt(
            encrypted_key,
            padding.OAEP(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None
            )
        )
        try:
            server_public_key.verify(
                signature,
                aes_key,
                padding.PSS(
                    mgf=padding.MGF1(hashes.SHA256()),
                    salt_length=padding.PSS.MAX_LENGTH
                ),
                hashes.SHA256()
            )
        except Exception as e:
            raise SystemExit(f"Signature verification failed: {e}")

        print("[OK] Session key decrypted and verified")

        # Step 3 – Send encrypted HELLO
        await asyncio.sleep(5)
        nonce = generate_nonce()
        nonce_bytes = nonce.to_bytes(12, 'big')
        aes = AESGCM(aes_key)

        hello_payload = {
            "type": "HELLO",
            "data": {"username": "TestClient"}
        }
        ciphertext = aes.encrypt(nonce_bytes, json.dumps(hello_payload).encode(), None)

        secure_msg = {
            "type": "SECURE_MSG",
            "session_id": session_id,
            "nonce": nonce_bytes.hex(),
            "ciphertext": ciphertext.hex()
        }
        await ws.send(json.dumps(secure_msg))

        # Step 4 – Receive encrypted response
        try:
            response = json.loads(await asyncio.wait_for(ws.recv(), timeout=3))
        except asyncio.TimeoutError:
            raise SystemExit("Timeout: No response to HELLO")

        if response.get("type") == "SECURE_MSG":
            try:
                decrypted = aes.decrypt(
                    bytes.fromhex(response["nonce"]),
                    bytes.fromhex(response["ciphertext"]),
                    None
                )
                print("[RESPONSE]", json.loads(decrypted.decode()))
            except Exception as e:
                print("Failed to decrypt server response:", e)
        else:
            print("[SERVER ERROR]", response)

def run():
    asyncio.run(run_test())

