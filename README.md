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

To run the project, you need to set up three components: the server (Python), the connector (Node.js), and the client (React). Each component has its own directory with a README file for detailed instructions.
Before running the project, ensure you have python3, Node.js, and npm installed on your system.
You can check if you have them installed by running:

```bash
python3 --version
node --version
npm --version
```

If you don't have them installed, you can download and install them from their official websites:
- [Python](https://www.python.org/downloads/)
- [Node.js and npm](https://nodejs.org/en/download/)

## Server Setup

The server is built using Python and requires a few dependencies. You can set up the server by following these steps:
1. Navigate to the `server` directory.
2. Create a virtual environment and activate it:
    ```bash
    cd server
    python3 -m venv venv # Create a virtual environment
    source venv/bin/activate # Activate the virtual environment
    ```
3. Install the required dependencies:
    ```bash
    pip install -r requirements.txt
    ```
4. Create a `.env` file based on the `.env.sample` file and set your OpenAI key or local Ollama setup.
5. Initialize the database:
    ```bash
    python main.py init_db
    ```
6. Start the server:
    ```bash
    python main.py start
    ```

## Connector Setup
The connector is a Node.js application that acts as a bridge between the WebSocket frontend and the UDP server. To set it up, follow these steps:
1. Navigate to the `connector` directory.
2. Install the required dependencies:
    ```bash
    cd connector
    npm install
    ```
3. Create a `.env` file based on the `.env.sample` file and set your server's IP address and port.
4. Start the connector:
    ```bash
    npm run dev
    ```

## Client Setup
The client is a React application that provides the chat interface. To set it up, follow these steps:
1. Navigate to the `client` directory.
2. Install the required dependencies:
    ```bash
    cd client
    npm install
    ```
3. Create a `.env` file based on the `.env.sample` file and set your connector's WebSocket URL.
4. Start the client:
```bash
npm run dev
```
5. Open your browser and navigate to the client URL to access the chat interface.

## Author

**Andrej Kudriavcev**

---

Licensed under the MIT License.
