"""
Pytest configuration and fixtures for UDPChat-AI tests.

Author: Andrej Kudriavcev
Last Updated: 29/09/2025
"""

import pytest
import tempfile
import os
import sys
from unittest.mock import Mock, patch

# Add the server directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from db import get_connection
from db.models import User, Room, Session, Member
from protocol.packets.base import BasePacket


@pytest.fixture
def mock_server():
    """Create a mock server instance for testing."""
    server = Mock()
    server.db = None  # Will be set by database fixtures
    server.broadcast = Mock()
    return server


@pytest.fixture
def test_db():
    """Create a temporary test database."""
    # Use PostgreSQL test database
    test_db_name = f"udpchat_test_{os.getpid()}"
    
    # Get database connection parameters from environment or use defaults
    db_host = os.getenv('DB_HOST', 'postgresql')
    db_port = int(os.getenv('DB_PORT', '5432'))
    db_user = os.getenv('DB_USER', 'udpchat_user')
    db_password = os.getenv('DB_PASSWORD', 'udpchat_password')
    
    # Create test database
    import psycopg2
    from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
    
    # Connect to default postgres database to create test database
    conn = psycopg2.connect(
        host=db_host,
        port=db_port,
        user=db_user,
        password=db_password,
        database="postgres"
    )
    conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    
    with conn.cursor() as cur:
        # Drop test database if it exists
        cur.execute(f"DROP DATABASE IF EXISTS {test_db_name}")
        # Create test database
        cur.execute(f"CREATE DATABASE {test_db_name}")
    
    conn.close()
    
    # Set up test database URL AFTER creating the database
    os.environ['DATABASE_URL'] = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{test_db_name}"
    
    # Import and initialize database with test database
    from db import init_db
    init_db()
    
    yield test_db_name
    
    # Cleanup - drop test database
    conn = psycopg2.connect(
        host=db_host,
        port=db_port,
        user=db_user,
        password=db_password,
        database="postgres"
    )
    conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    
    with conn.cursor() as cur:
        cur.execute(f"DROP DATABASE IF EXISTS {test_db_name}")
    
    conn.close()


@pytest.fixture
def db_connection(test_db):
    """Get a database connection for testing."""
    return get_connection()


@pytest.fixture
def sample_user(db_connection):
    """Create a sample user for testing."""
    import time
    unique_id = f"test_user_{int(time.time() * 1000)}"
    user = User(
        user_id=unique_id,
        email=f"test{unique_id}@example.com",
        name="Test User",
        password="33f2429083af5334fda0a1a8cdff70e0"  # MD5 hash of "hashed_password"
    )
    user.insert(db_connection)
    return user


@pytest.fixture
def sample_room(db_connection, sample_user):
    """Create a sample room for testing."""
    import time
    unique_id = f"test_room_{int(time.time() * 1000)}"
    room = Room(
        room_id=unique_id,
        name=f"Test Room {unique_id}",
        is_private=False
    )
    room.insert(db_connection)
    return room


@pytest.fixture
def sample_session(db_connection, sample_user):
    """Create a sample session for testing."""
    import time
    unique_id = f"test_session_{int(time.time() * 1000)}"
    session = Session(
        session_id=unique_id,
        user_id=sample_user.id,
        session_key=f"test_session_key_{int(time.time() * 1000)}",
        last_active_at=None
    )
    session.insert(db_connection)
    return session


@pytest.fixture
def sample_packet_data(sample_session):
    """Create sample packet data for testing."""
    return {
        "type": "TEST_PACKET",
        "data": {"test": "data"},
        "session_id": sample_session.session_id
    }
