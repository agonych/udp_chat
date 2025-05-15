"""
This module handles the database connection and initialisation for the server.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

import sqlite3 # Importing sqlite3 for database operations
from server.config import DB_PATH  # Importing DB_PATH from config for database path

def get_connection():
    """
    Establishes a connection to the SQLite database.
    :return: sqlite3.Connection object
    """
    # Connect to the database with a timeout of 5 seconds
    conn = sqlite3.connect(DB_PATH, timeout=5)
    # Set the row factory to return rows as dictionaries
    conn.row_factory = sqlite3.Row
    # Enable foreign key constraints
    conn.execute("PRAGMA foreign_keys = ON")
    # Return the connection object
    return conn

def init_db():
    """
    Initialises the database by executing the schema.sql file.
    :return: None
    """
    # Use the get_connection function to establish a connection
    with get_connection() as conn:
        print("Initialising database...")
        # Read the schema.sql file and execute its content
        with open('db/schema.sql', 'r') as f:
            conn.executescript(f.read())
        print("Database initialise complete.")