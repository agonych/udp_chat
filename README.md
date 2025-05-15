# UDPChat-AI

**UDPChat-AI** is a secure, real-time chat system that uses a custom UDP-based protocol enhanced with modern cryptography. It supports secure messaging, user sessions, and AI-generated responses through a modular three-part architecture:

---

## Project Structure

```
client/     → Frontend React app (chat interface)
connector/  → Node.js bridge (WebSocket ↔ UDP)
server/     → Python backend (UDP server + AI logic)
```

---

## Features

- **Secure Messaging**: All communication uses AES-GCM encryption over a custom UDP protocol.
- **AI-Powered Chat**: Optionally allows AI-generated responses using OpenAI or Ollama backends.
- **Session Management**: RSA handshake with AES session key, fingerprint verification, and session resumption.
- **Chat Rooms**: Join, create, and chat in rooms with live member lists and message history.
- **Bridged Access**: WebSocket-to-UDP bridge enables frontend to communicate with the backend securely.

---

## Subproject READMEs

- [Client (React)](client/README.md)
- [Connector (Node.js)](connector/README.md)
- [Server (Python)](server/README.md)

---

## Getting Started

Each component is started independently:

```bash
# Server (Python UDP)
cd server
python3 -m venv venv # Create a virtual environment
source venv/bin/activate # Activate the virtual environment
pip install -r requirements.txt # Install dependencies
python main.py start # Start the server

# Connector (Node WebSocket bridge)
cd connector
npm install # Install dependencies
npm run dev # Start the connector

# Client (React frontend)
cd client
npm install # Install dependencies
npm run dev # Start the client
```

## Author

**Andrej Kudriavcev**

---

Licensed under the MIT License.
