# UDPChat-AI Server

This is the backend server for the **UDPChat-AI** project — a secure, AI-assisted group chat platform using UDP for fast and lightweight communication.

## Project Structure

```
server/
├── db/                    # Database connection and schema
│   ├── models/            # ORM-like model helpers
│   ├── __init__.py
│   └── schema.sql         # Schema definition
├── protocol/              # Core protocol logic
│   ├── packets/           # Individual packet handlers
│   └── __init__.py
├── storage/               # Persistent file/key storage
│   ├── db/
│   └── keys/
├── tests/                 # Unit and integration tests
│   ├── hello.py
│   ├── websocket.py
│   └── __init__.py
├── utils/                 # Utility functions
│   ├── ai.py              # AI helper for OpenAI/Ollama
│   ├── encryption.py      # RSA/AES encryption utilities
│   └── tools.py
├── config.py              # Server configuration
├── dispatcher.py          # Reliable UDP dispatch logic
├── main.py                # Entry point (start/init/test)
├── server.py              # Core UDP server logic
├── .env.sample            # Sample environment configuration
└── requirements.txt       # Python dependencies
```

## Features

- Encrypted communication (RSA handshake + AES-GCM payloads)
- Stateless session management using UUID tokens
- Modular packet protocol architecture
- Reliable delivery over UDP using retry queues
- Optional AI-powered replies via OpenAI or Ollama
- Client message acknowledgment and replay prevention

## Installation

```bash
pip install -r requirements.txt
```

## Usage

Initialize database:
```bash
python main.py init_db
```

Start the server:
```bash
python main.py start
```

Run a test:
```bash
python main.py test hello
```

## Configuration

Create your `.env` file based on `.env.sample` with your OpenAI key or local Ollama setup.

## Dependencies

- `cryptography~=44.0.2`
- `python-dotenv~=1.1.0`
- `fastapi~=0.115.12`
- `openai~=1.78.1`


## Author

**Andrej Kudriavcev**

---

Licensed under the MIT License.
