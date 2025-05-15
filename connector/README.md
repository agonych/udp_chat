# WebSocket-to-UDP Bridge

This Node.js application acts as a bridge between browser-based WebSocket clients and a local UDP server. Each client that connects via WebSocket is assigned a unique session and a dedicated UDP socket, allowing two-way communication between the browser and the UDP-based backend service.

## Features

- Handles multiple WebSocket clients, each with its own UDP socket
- Forwards messages from WebSocket to a local UDP server and vice versa
- Cleans up inactive sessions after a configurable timeout (default: 10 minutes)
- Gracefully handles dropped connections and network errors
- Configuration via `.env` file or environment variables

## Usage

### 1. Install dependencies

```
npm install
```

### 2. Create a `.env` file

You can override default configuration values by creating a .env file in the root directory:

```
UDP_SERVER_HOST=127.0.0.1
UDP_SERVER_PORT=9999
WS_PORT=8000
INACTIVITY_TIMEOUT_MS=600000
```

### 3. Start the bridge

```
node connector.js
```

This will start a WebSocket server listening on `ws://localhost:8000` (or the configured `WS_PORT`).

## How It Works

- When a WebSocket client connects, a unique session is created.
- The server binds a UDP socket for that session.
- Messages sent from the client are forwarded to the configured UDP server.
- Responses from the UDP server are sent back over the WebSocket connection.
- If there is no activity for `INACTIVITY_TIMEOUT_MS`, the session is 
  automatically cleaned up.

## Configuration

| Variable	                | Description	                             | Default            |
|--------------------------|------------------------------------------|--------------------|
| `UDP_SERVER_HOST`        | 	Host of the UDP server                  | 	`127.0.0.1`       |
| `UDP_SERVER_PORT`        | 	Port of the UDP server                  | `9999`             |
| `WS_PORT`	               | Port for incoming WebSocket connections	 | `8000`             | 
| `INACTIVITY_TIMEOUT_MS`	 | Timeout in milliseconds for inactivity   | 	`600000` (10 min) | 

## Dependencies

- [dgram](https://nodejs.org/api/dgram.html) – UDP socket support (built-in)
- [ws](https://www.npmjs.com/package/ws) – WebSocket support
- [uuid](https://www.npmjs.com/package/uuid) – For unique session IDs
- [dotenv](https://www.npmjs.com/package/dotenv) – To load configuration from `.env`


## Author

**Andrej Kudriavcev**

---

Licensed under the MIT License.
