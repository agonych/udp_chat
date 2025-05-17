# UDPChat-AI Client

This is the frontend React client for **UDPChat-AI**, a secure, encrypted group chat system using AES and RSA encryption over a custom UDP protocol. This client connects to the Node-based WebSocket bridge and communicates securely with the backend server.

## Features

- Secure login using public-key encryption
- Session establishment and AES key negotiation
- Encrypted messaging with nonce-based replay protection
- AI-powered chat replies using local models (e.g., Ollama)
- Toggle modes for User, AI Helper, and AI Bot
- Automatic reconnection and session merging
- Responsive and accessible UI with Material UI

## Getting Started

### Prerequisites

- Node.js 18+
- NPM
- Backend and connector services running locally

### Installation

```bash
npm install
```

### Running the Dev Server

```bash
npm run dev
```

### Building for Production

```bash
npm run build
```

## Configuration

The WebSocket server URL is configured in `config.js`. By default, it connects to:

```
ws://127.0.0.1:8080/ws
```

You can change this for deployment or testing purposes.

## Project Structure

- `public/`
    - `icon.svg`: Favicon for the app
- `src/`
    - `assets/`: Static files such as logos
        - `logo.svg`: Logo for the app
    - `components/`: Reusable components
        - `ChatRoom.jsx`: Chat Room component
        - `LoginForm.jsx`: Login form component
        - `RoomList.jsx`: List of chat rooms
    - `context/`: Context providers for state management
        - `AppContext.jsx`: Context for app
    - `helpers/`: Helper functions
        - `messageRouter.js`: Routing messages to appropriate handlers
        - `secureTransport.js`: Secure transport layer for WebSocket
        - `sessionManager.js`: Session management
        - `utils.js`: Utility functions
    - `hooks/`: Custom hooks for state management
        - `useKeepAlive.js`: Hook for keeping WebSocket connection alive
        - `useSecureMessage.js`: Hook for sendEncrypted wrapper
        - `useSecureTransport.js`: Hook for secure transport layer
        - `useSession.js`: Hook for session management
    - `App.jsx`: Main UI logic
    - `config.js`: Configuration for WebSocket server
    - `main.jsx`: Entry point for the React app
    - `theme.js`: Theme configuration for Material UI
- `.env`: Environment variables
- `.env.sample`: Sample environment variables
- `eslint.json`: Code Linter configuration
- `index.html`: Main HTML file
- `package.json`: Project metadata and dependencies
- `package-lock.json`: Dependency lock file
- `vite.config.mjs`: Vite configuration file

## Dependencies

### Runtime

- `react` ^19.0.0 – React UI library
- `react-dom` ^19.0.0 – DOM bindings for React
- `@mui/material` ^7.0.2 – Material UI components
- `@mui/icons-material` ^7.0.2 – MUI Icons
- `@emotion/react` ^11.14.0 – Emotion styling for MUI
- `@emotion/styled` ^11.14.0 – Styled components using Emotion
- `node-forge` ^1.3.1 – RSA key generation, encryption, and signatures

### Dev Dependencies

- `vite` ^6.3.1 – Fast frontend build tool
- `@vitejs/plugin-react` ^4.3.4 – React plugin for Vite
- `eslint` ^9.22.0 – JavaScript/React linting
- `@eslint/js` ^9.22.0 – ESLint core rules
- `eslint-plugin-react-hooks` ^5.2.0 – Rules for React hooks
- `eslint-plugin-react-refresh` ^0.4.19 – React Fast Refresh linting
- `@types/react` ^19.0.10 – TypeScript types for React
- `@types/react-dom` ^19.0.4 – TypeScript types for React DOM
- `globals` ^16.0.0 – Global variable definitions


## Author

**Andrej Kudriavcev**

---

Licensed under the MIT License.
