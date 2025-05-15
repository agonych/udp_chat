const WebSocket = require("ws");
const forge = require("node-forge");
const crypto = require("crypto");

const CONNECTOR_URL = "ws://127.0.0.1:8000/ws";

const keypair = forge.pki.rsa.generateKeyPair({ bits: 2048 });
const publicKeyDer = forge.asn1.toDer(forge.pki.publicKeyToAsn1(keypair.publicKey)).getBytes();
const publicKeyBase64 = Buffer.from(publicKeyDer, "binary").toString("base64");

function generateNonce() {
    const now = BigInt(Date.now()) * 1000000n;
    const rand = BigInt(crypto.randomBytes(4).readUInt32BE());
    return now << 32n | rand;
}

function decryptWithAESGCM(keyHex, nonceHex, ciphertextHex) {
    const key = Buffer.from(keyHex, "hex");
    const nonce = Buffer.from(nonceHex, "hex");
    const ciphertext = Buffer.from(ciphertextHex, "hex");

    const decipher = crypto.createDecipheriv("aes-256-gcm", key, nonce);
    decipher.setAuthTag(ciphertext.slice(-16));
    const decrypted = Buffer.concat([
        decipher.update(ciphertext.slice(0, -16)),
        decipher.final()
    ]);
    return JSON.parse(decrypted.toString());
}

(async () => {
    const ws = new WebSocket(CONNECTOR_URL);

    ws.on("open", () => {
        console.log("[WS] Connected to bridge");

        const sessionInit = {
            type: "SESSION_INIT",
            client_key: publicKeyBase64
        };

        ws.send(JSON.stringify(sessionInit));
        console.log("[WS] Sent SESSION_INIT");
    });

    let aesKeyHex = null;
    let sessionId = null;

    ws.on("message", (data) => {
        const message = JSON.parse(data);

        if (message.type === "SESSION_INIT") {
            console.log("[WS] Received SESSION_INIT");

            sessionId = message.session_id;
            const encryptedKey = Buffer.from(message.encrypted_key, "hex");
            const signature = Buffer.from(message.signature, "hex");
            const serverPubKeyDer = Buffer.from(message.server_pubkey, "hex");

            const serverPublicKeyPem = forge.pki.publicKeyToPem(
                forge.pki.publicKeyFromAsn1(forge.asn1.fromDer(serverPubKeyDer.toString("binary")))
            );

            const serverPublicKey = crypto.createPublicKey({
                key: serverPublicKeyPem,
                format: "pem",
                type: "spki"
            });

            const aesKey = crypto.privateDecrypt({
                key: forge.pki.privateKeyToPem(keypair.privateKey),
                padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
                oaepHash: "sha256"
            }, encryptedKey);

            aesKeyHex = aesKey.toString("hex");

            console.log("[DEBUG] AES Key (hex):", aesKeyHex);
            console.log("[DEBUG] AES Key (base64):", aesKey.toString("base64"));
            console.log("[DEBUG] Signature:", signature.toString("hex"));

            const verifyResult = crypto.verify(
                "sha256",
                aesKey,
                {
                    key: serverPublicKey,
                    padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
                    saltLength: crypto.constants.RSA_PSS_SALTLEN_MAX_SIGN
                },
                signature
            );

            console.log("[DEBUG] Verification result:", verifyResult);

            if (!verifyResult) {
                console.error("Signature verification failed");
                process.exit(1);
            }

            console.log("[OK] Session key decrypted and verified. Sending HELLO...");

            const nonce = generateNonce();
            const nonceBuf = Buffer.alloc(12);
            nonceBuf.writeBigUInt64BE(nonce >> 32n);
            nonceBuf.writeUInt32BE(Number(nonce & 0xffffffffn), 8);

            const aes = crypto.createCipheriv("aes-256-gcm", aesKey, nonceBuf);
            const payload = JSON.stringify({ type: "HELLO", data: { username: "NodeTest" } });
            const encrypted = Buffer.concat([aes.update(payload, "utf8"), aes.final()]);
            const tag = aes.getAuthTag();

            const secureMsg = {
                type: "SECURE_MSG",
                session_id: sessionId,
                nonce: nonceBuf.toString("hex"),
                ciphertext: Buffer.concat([encrypted, tag]).toString("hex")
            };

            ws.send(JSON.stringify(secureMsg));
        } else if (message.type === "SECURE_MSG") {
            console.log("[WS] Received SECURE_MSG");
            try {
                const decoded = decryptWithAESGCM(
                    aesKeyHex,
                    message.nonce,
                    message.ciphertext
                );
                console.log("[SERVER RESPONSE]", decoded);
            } catch (err) {
                console.error("Decryption failed:", err);
            }
        } else {
            console.warn("Unexpected message:", message);
        }
    });

    ws.on("close", () => console.log("[WS] Connection closed"));
    ws.on("error", (err) => console.error("[WS] Error:", err));
})();
