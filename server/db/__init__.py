"""
This module handles the database connection and initialisation for the server.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

import psycopg2
import psycopg2.extras
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_URL

def get_connection():
    """
    Establishes a connection to the PostgreSQL database.
    :return: psycopg2.Connection object
    """
    try:
        # Connect to the database
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        # Set the row factory to return rows as dictionaries
        conn.cursor_factory = psycopg2.extras.RealDictCursor
        # Enable autocommit for DDL operations
        conn.autocommit = True
        return conn
    except psycopg2.Error as e:
        print(f"Error connecting to PostgreSQL: {e}")
        raise

def create_database():
    """
    Creates the database if it doesn't exist.
    :return: None
    """
    conn = None
    try:
        # Connect to PostgreSQL server (not to specific database)
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database='postgres',  # Connect to default postgres database
            user=DB_USER,
            password=DB_PASSWORD
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        
        with conn.cursor() as cur:
            # Check if database exists
            cur.execute(f"SELECT 1 FROM pg_database WHERE datname = '{DB_NAME}'")
            exists = cur.fetchone()
            
            if not exists:
                # Create database
                cur.execute(f"CREATE DATABASE {DB_NAME}")
                print(f"Database '{DB_NAME}' created successfully.")
            else:
                print(f"Database '{DB_NAME}' already exists.")
                
    except psycopg2.Error as e:
        print(f"Error creating database: {e}")
        raise
    finally:
        if conn:
            conn.close()

def init_db():
    """
    Initialises the database by creating it and executing the schema.sql file.
    :return: None
    """
    # First create the database if it doesn't exist
    create_database()
    
    # Use the get_connection function to establish a connection
    with get_connection() as conn:
        print("Initialising database schema...")
        # Read the schema.sql file and execute its content
        with open('db/schema.sql', 'r') as f:
            schema_sql = f.read()
            # Execute the entire schema as one statement to handle $$ delimiters
            with conn.cursor() as cur:
                try:
                    cur.execute(schema_sql)
                except Exception as e:
                    # If schema already exists, that's okay for tests
                    if "already exists" in str(e) or "duplicate" in str(e).lower():
                        print(f"Schema already exists, continuing...")
                    else:
                        raise e
        print("Database schema initialised successfully.")
