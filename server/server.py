"""
UDPChat-AI Server

This module defines the UDPChatServer class, which implements a secure, encrypted chat server
using the UDP protocol. The server handles:

- Secure session establishment using RSA/AES key exchange
- AES-GCM encrypted message transport
- Session and nonce tracking to prevent replay attacks
- Active session management with auto-cleanup
- Packet dispatch and response via a secure dispatcher
- Thread-safe deferred database writes to ensure SQLite safety
- Real-time communication features such as broadcasting messages to users

The server uses SQLite for persistent storage of users, sessions, rooms, messages, and nonces.
It supports extensible packet types for user authentication, messaging, room management, and
status reporting.

Designed for real-time chat scenarios where performance and security are both critical.
"""


import time # Import time for timestamp calculations
import socket # Import socket for UDP communication
import json # Import json for JSON encoding/decoding
import threading # Import threading for handling concurrent connections

from queue import Queue # Import Queue for thread-safe queue
from server.db import get_connection # Import database connection function
from server.db.models import Session, Nonce # Import Session and Nonce models
# import encryption functions for secure communication
from server.utils.encryption import (
    load_or_create_server_keys, # Load or create server keys
    generate_random_id, # Generate a random session ID
    generate_session_key, # Generate a session key
    encrypt_key_for_client, # Encrypt the session key for the client
    sign_data, # Sign data with the server's private key
    get_server_pubkey_der, # Get the server's public key in DER format
    decrypt_message, # Decrypt messages using the session key
    generate_nonce, # Generate a nonce for secure communication
    encrypt_message # Encrypt messages using the session key
)
from server.dispatcher import UdpDispatcher
from server.protocol import handle_packet # Import packet handling function
from server.config import SERVER_IP, SERVER_PORT, BUFFER_SIZE, DEBUG # Import server config

class UDPChatServer:
    """
    UDPChat-AI Server class - implements the UDP server for handling chat messages.
    """
    private_key = None # Private key for signing messages
    public_key = None # Public key for encrypting messages
    fingerprint = None # Fingerprint of the server's public key
    db = None # Database connection
    sock = None # Socket for UDP communication
    shutdown_event = None # Event to signal shutdown
    active_sessions = {} # Dictionary to store active sessions
    must_cleanup = False # Flag to indicate if cleanup is needed
    dispatcher = None # Dispatcher for handling incoming messages
    db_queue = None # Queue for database operations

    def __init__(self):
        """
        Constructor for UDPChatServer.
        """
        # Load or create server keys
        self.private_key, self.public_key, self.fingerprint = load_or_create_server_keys()
        # Initialize database connection
        self.db = get_connection()
        # Bind the shutdown event
        self.shutdown_event = threading.Event()
        self.dispatcher = UdpDispatcher(self)
        self.db_queue = Queue()

    def listen(self, ip=None, port=None):
        """
        Bind the socket to the specified IP and port, and start listening for incoming messages.
        If no IP or port is specified, use the default values from the config.
        Args:
            ip (str): The IP address to bind to. Defaults to SERVER_IP.
            port (int): The port number to bind to. Defaults to SERVER_PORT.
        Returns: None
        """
        # If no IP or port is specified, use the default values from the config
        if ip is None:
            ip = SERVER_IP
        if port is None:
            port = SERVER_PORT
        # Create a UDP socket and bind it to the specified IP and port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((ip, port))
        # Set the socket timeout to 1 second for catching shutdown events
        self.sock.settimeout(1.0)
        print(f"UDPChat-AI Server is listening on {ip}:{port}")

        # Create a thread to clean up inactive sessions
        cleanup_thread = threading.Thread(
            target=self.cleanup_inactive_sessions,
            daemon=True # Set the thread as a daemon so it will exit when the main program exits
        )
        # Start the cleanup thread
        cleanup_thread.start()
        if DEBUG:
            print(f"Inactive session cleanup thread started.")

        # Start the main loop to listen for incoming messages until shutdown is signaled
        while not self.shutdown_event.is_set():
            try:
                self.process_db_queue()
                if self.must_cleanup:
                    if DEBUG:
                        print("Cleaning up old sessions from the DB...")
                    self.must_cleanup = False
                    Session.cleanup(self.db)
                # Receive data from the socket
                data, addr = self.sock.recvfrom(BUFFER_SIZE) # Buffer size of 8192 bytes
                # Decode the data and parse it as JSON
                try:
                    message = json.loads(data.decode())
                    if DEBUG:
                        print(f"Received message from {addr}: {message}")
                    # Call the handle_message method to process the received message
                    self.handle_message(message, addr)
                except Exception as e:
                    self.handle_error(f"Packet processing failure: {e}", addr)
            # If 1 second timeout occurs
            except socket.timeout:
                continue # Continue to the next iteration
            # If any other exception occurs
            except Exception as e:
                # Print the error message and continue to the next iteration
                if DEBUG:
                    print(f"Socket listen cycle error: {e}")
                continue
        # If shutdown is signaled, close the socket and exit
        print("Shutting down UDPChat-AI Server...")
        self.sock.close()
        print("Bye!")

    def broadcast(self, message, sessions=None):
        """
        Broadcast a message to all active sessions.
        Args:
            message (dict):  The message to broadcast.
            sessions (list): List of session IDs to send the message to. If
                             None, send to all active sessions.
        """
        if sessions is None:
            sessions = [session_id for session_id in self.active_sessions]
        for session_id in sessions:
            self.dispatcher.enqueue(session_id, message)

    def stop(self, *_):
        """
        Handle server shutdown signal.
        Args:
            *_: Additional arguments (not used).
        """
        if DEBUG:
            print("Server stop signal received.")
        self.shutdown_event.set()
        self.dispatcher.stop()

    def process_db_queue(self):
        """
        Process the database queue and execute deferred queries to bypass
        SQLLite's thread safety issues.
        :return:
        """
        while not self.db_queue.empty():
            task = self.db_queue.get()
            try:
                task(self.db)
            except Exception as e:
                print(f"[DB QUEUE] Error in DB task: {e}")
            self.db_queue.task_done()

    def cleanup_inactive_sessions(self, timeout=60):
        """
        Cycle to clean up inactive sessions. Also signals the main loop to
        clean up old sessions from the database every 60 seconds.
        Args:
            timeout (int): The timeout period in seconds for session to expire.
        """
        must_cleanup_count = 0 # Counter for cleanup cycles
        while not self.shutdown_event.is_set(): # Loop until shutdown is signaled
            if DEBUG:
                print("Cleaning up inactive sessions...")
            now = time.time() # Get the current time
            to_remove = [] # List to store session IDs to be removed
            # Iterate through active sessions and check if they are inactive
            for session_id, info in self.active_sessions.items():
                if now - info["last_seen"] > timeout:
                    to_remove.append(session_id) # Add inactive session ID to the list
            # Remove inactive sessions from the active sessions dictionary
            for session_id in to_remove:
                if DEBUG:
                    print(f"Removing inactive session {session_id}")
                del self.active_sessions[session_id]
            # Iterate cleanup counter
            must_cleanup_count += 1
            if must_cleanup_count >= 6: # If 6 cycles have passed = 60 seconds
                self.must_cleanup = True # Set the cleanup flag for the main loop
                must_cleanup_count = 0 # Reset the cleanup counter
            time.sleep(10)

    def handle_message(self, message, addr):
        """
        Parse and handle incoming messages.
        Args:
            message (dict): The incoming message.
            addr (tuple): The address of the sender.
        Returns: None
        """
        # Check if the message variable is a dictionary
        if not isinstance(message, dict):
            # If not, output invalid message format error
            self.handle_error(f"Invalid message format", addr)
            return
        # Get the message type
        msg_type = message.get("type")
        # Handle handshake message
        if msg_type == "SESSION_INIT":
            # Init a new session
            self.handle_session_init(message, addr)
        # Handle encrypted message
        elif msg_type == "SECURE_MSG":
            # Process secure message
            self.handle_secure_message(message, addr)
        # Handle unknown message type
        else:
            self.handle_error(f"Unknown message type '{msg_type}'", addr)
            return

    def handle_error(self, message, addr):
        """
        Return error message to the client.
        Args:
            message (str): The error message to send.
            addr (tuple): The address of the sender.
        """
        if DEBUG:
            print(f"ERROR: {message} from {addr}")
        # Create an error response message
        response = {
            "type": "SERVER_ERROR",
            "message": message,
        }
        if DEBUG:
            print(f"Sending error response to {addr}: {response}")
        # Send the error response to the client
        self.sock.sendto(json.dumps(response).encode(), addr)
        return

    def handle_session_init(self, message, addr):
        """
        Handle SESSION_INIT message from the client.
        Args:
            message (dict): The incoming message.
            addr (tuple): The address of the sender.
        Returns: None
        """
        if DEBUG:
            print(f"Received SESSION_INIT from {addr}")
        # Get the client's public key from the message
        client_key = message.get("client_key")
        if not client_key:
            # If the client's public key is missing, return an error
            self.handle_error(f"Missing client's public key", addr)
            return
        # Generate a random session ID and AES key
        session_id = generate_random_id()
        aes_key = generate_session_key()
        if DEBUG:
            print(f"Generated session ID: {session_id}")
        # Encrypt the AES key for the client using their public key
        encrypted_key = encrypt_key_for_client(client_key, aes_key)
        # Sign the AES key with the server's private key
        aes_signature = sign_data(aes_key, self.private_key)
        # Create a new session object and insert it into the database
        session = Session(
            session_id=session_id,
            session_key=aes_key.hex()
        )
        session.insert(self.db)
        # Store the session in the array of active sessions
        self.active_sessions[session_id] = {
            "session": session,
            "addr": addr,
            "last_seen": time.time()
        }

        # Create a response message with the session ID, encrypted key,
        # server's public key, signature, and fingerprint
        response = {
            "type": "SESSION_INIT",
            "session_id": session_id, # Session ID for the client
            "encrypted_key": encrypted_key.hex(), # Encrypted AES key for the client
            "server_pubkey": get_server_pubkey_der(self.public_key).hex(), # Server's public key in DER format
            "signature": aes_signature.hex(), # Signature of the AES key
            "fingerprint": self.fingerprint, # Fingerprint of the server's public key
        }
        if DEBUG:
            print(f"Sending SESSION_INIT to {addr}: {response}")
        # Send the response message to the client
        self.sock.sendto(json.dumps(response).encode(), addr)

    def handle_secure_message(self, message, addr):
        """
        Handle SECURE_MSG message from the client.
        Args:
            message (dict): The incoming message.
            addr (tuple): The address of the sender.
        Returns: None
        """
        # Get the session ID, ciphertext, and nonce from the message
        session_id = message.get("session_id")
        ciphertext = message.get("ciphertext")
        nonce = message.get("nonce")
        if DEBUG:
            print(f"Received SECURE_MSG from {addr}: {message}")
        # Check if the message format is valid
        if not session_id or not ciphertext or not nonce:
            # If the message format is incomplete, return an error
            self.handle_error(f"Message format is incomplete", addr)
            return

        # Get the session from the database using the session ID
        session = Session.find_one(self.db, session_id=session_id)
        if not session:
            # If the session ID is not found, return an error
            self.handle_error(f"Session ID '{session_id}' not found", addr)
            return
        elif DEBUG:
            print(f"Session ID '{session_id}' found in the database")
        # Check nonce
        if Nonce.find_one(self.db, session_id=session.id, nonce=nonce):
            # If the nonce is already used, return an error
            self.handle_error(f"This nonce was already used", addr)
            return
        # Save nonce to the database
        Nonce(session_id=session.id, nonce=nonce).insert(self.db)

        # Update session information in the active sessions dictionary
        self.active_sessions[session_id] = {
            "session": session,
            "addr": addr,
            "last_seen": time.time()
        }

        # Update session in the database with the current timestamp
        now = int(time.time())
        Session.update(self.db, "session_id", session_id, last_active_at=now)

        # Decrypt the message using the session key and nonce
        try:
            payload = decrypt_message(session.session_key, nonce, ciphertext)
            if DEBUG:
                print(f"Decrypted payload: {payload}")
        except Exception as e:
            # If decryption fails, return an error
            self.handle_error(f"Message decryption failed: {e}", addr)
            return

        # Process payload
        try:
            # Call the handle_packet function to process the payload
            response_data = handle_packet(self, session, payload)
            # If the response data is not None, encode and send it to the client
            if response_data:
                if DEBUG:
                    print(f"Sending Response: {response_data}")
                self.encode_and_send_message(session, response_data, addr)
        except Exception as e:
            # If processing the payload fails, return an error
            self.handle_error(f"Packet processing failure: {e}", addr)
            return

    def encode_and_send_message(self, session, response_data, addr):
        """
        Encrypts and sends a response to the client.
        Args:
            session (Session): The session object.
            response_data (dict): The response data to send.
            addr (tuple): The address of the client.
        Returns: None
        """
        # Generate a nonce for the response
        nonce = generate_nonce()
        nonce_bytes = nonce.to_bytes(12, 'big')
        # Save nonce to the database (using a deferred query)
        self.db_queue.put(
            lambda conn: Nonce(session_id=session.id, nonce=nonce_bytes.hex()).insert(conn)
        )
        # Encrypt the response data using the session key and nonce
        ciphertext = encrypt_message(session.session_key, nonce_bytes, response_data)
        # Create a response message with the session ID, nonce, and ciphertext
        response = {
            "type": "SECURE_MSG",
            "session_id": session.session_id,
            "nonce": nonce_bytes.hex(),
            "ciphertext": ciphertext.hex()
        }
        # Send the response message to the client
        self.sock.sendto(json.dumps(response).encode(), addr)