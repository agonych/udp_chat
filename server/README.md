# UDPChat-AI Server

This is the backend server for the **UDPChat-AI** project — a secure, AI-assisted group chat platform using UDP for fast and lightweight communication.

## Project Features

- End-to-end encrypted communication with asymmetric and symmetric keys (RSA handshake + AES-GCM payloads)
- Stateless session management using UUID tokens
- Modular database architecture with built-in CRUD operations
- Modular and extendable packet protocol architecture
- Reliable delivery over UDP using retry queues
- Broadcast packet dispatcher for efficient message routing to multiple clients
- Client message acknowledgment and replay prevention
- Optional AI-powered replies via OpenAI or Ollama

## Project Structure

- `db/`: Database functionality
    - `models/`: Database model objects
        - `__init__.py`: Single point of access for all models
        - `base.py`: Abstract base model class for common CRUD operations functionality
        - `user.py`: User model
        - `session.py`: Session model
        - `nonce.py`: Seen nonce registry model
        - `room.py`: Chat room model
        - `member.py`: Chat room member model
        - `message.py`: Message model
    - `__init__.py`: Database connection and initialization
    - `schema.sql`: Database schema
- `protocol/`: UDP protocol implementation
    - `packets/`: Packet classes
        - `__init__.py`: Signgle point of access for all packets
        - `base.py`: Abstract base packet class implementing the common packet logic
        - `ack.py`: Broadcast acknowledgment packet
        - `hello.py`: Hello packet for server testing
        - `status.py`: Status packet for connection status, user and room information
        - `login.py`: Login packet for user authentication
        - `logout.py`: Logout packet for user logout
        - `merge_session.py`: Merge session packet
        - `list_rooms.py`: List rooms packet
        - `create_room.py`: Create room packet
        - `join_room.py`: Join room packet
        - `leave_room.py`: Leave room packet
        - `list_members.py`: List members packet
        - `list_messages.py`: List message history packet
        - `message.py`: Message packet
        - `ai_message.py`: AI message request packet
      - `__init__.py`: Packet registry and router
- `storage/`: Storage folder for DB and key files
    - `keys/`: RSA keys for encryption
        - `server_private_key.pem`: Private key
        - `server_public_key.pem`: Public key
    - `db/`: SQLite database file
        - `chat.db`: SQLite database file
- `tests/`: Unit tests for the protocol
    - `__init__.py`: Python package marker
    - `hello.py`: Simple hello packet test
- `utils/`: Utility functions
    - `__init__.py`: Python package marker
    - `ai.py`: Prompt generation and AI model functions
    - `encryption.py`: Encryption and decryption functions
    - `tools.py`: Helper functions
- `.env`: Environment variables
- `.env.sample`: Sample environment variables
- `__init__.py`: Python package marker
- `config.py`: Configuration file
- `server.py`: Main server class
- `dispatcher.py`: Broadcast packet dispatcher class
- `main.py`: Main entry point for the server
- `requirements.txt`: Python dependencies


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
python main.py start [IP] [PORT]
```

Run a test:

```bash
python main.py test hello
```

## Configuration

Create your `.env` file based on `.env.sample` with your OpenAI key or local Ollama setup.

## Dependencies

- [cryptography](https://pypi.org/project/cryptography/) - for key generation and encryption (version 44.0.2)
- [python-dotenv](https://pypi.org/project/python-dotenv/) - for environment variable management (version 1.0.0)
- [openai](https://pypi.org/project/openai/) - for OpenAI ChatGTP API access (version 1.78.1)
- [ollama](https://pypi.org/project/ollama/) - for Ollama model access (version 0.4.8)


## Author

**Andrej Kudriavcev**

---

Licensed under the MIT License.
