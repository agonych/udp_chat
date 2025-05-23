"""
Entry Point for UDPChat-AI Server

Provides command-line control for:
- Starting the UDP-based encrypted chat server
- Initializing the SQLite database
- Running test modules

Usage:
    python main.py start [ip] [port]    - Start the server on optional IP/port
    python main.py init_db              - Initialize the database schema
    python main.py test <test_name>     - Run a specific test module

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

import signal
import sys
import os

# Change the python path to include the parent directory
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

def start(ip=None, port=None):
    """
    Start the UDP chat server.
    :param ip: The IP address to bind the server to
    :param port: The port to bind the server to
    :return: None
    """
    # Import the UDPChatServer class
    from server.server import UDPChatServer
    # Create an instance of the UDPChatServer
    server = UDPChatServer()
    # Bind the server stop method to the SIGTERM and SIGINT signals
    signal.signal(signal.SIGTERM, server.stop)
    signal.signal(signal.SIGINT, server.stop)
    # Initialize the server
    server.listen(ip, port)

def init_db():
    """
    Function to initialize the database
    """
    # Import the init_db function from the db module
    from server.db import init_db
    # Initialize the database
    init_db()

# Main entry point
if __name__ == '__main__':
    if len(sys.argv) > 1:
        command = sys.argv[1] # Get the command from the command line arguments

        if command == 'init_db': # Initialize the database
            init_db()
        elif command == 'test': # Run a specific test
            test_name = sys.argv[2] if len(sys.argv) > 2 else None
            if not test_name: # Check if test name is provided
                print("Error: Test name is required.")
                sys.exit(1)
            # Import the run() function from the tests/<test_name>.py module if it exists
            test_module = f"tests.{test_name}"
            try:
                test = __import__(test_module, fromlist=['run'])
                test.run()
            except ImportError:
                print(f"Error: Test module {test_name} not found.")
                sys.exit(1)
        elif command == 'start': # Start the server
            ip = sys.argv[2] if len(sys.argv) > 2 else None
            port = int(sys.argv[3]) if len(sys.argv) > 3 else None
            start(ip, port)
        else: # Unknown command
            print(f"Error: Unknown command: {command}")
            print("Usage: python main.py <command>")
            sys.exit(1)
    else: # No command provided - start the server with default IP and port
        start()
