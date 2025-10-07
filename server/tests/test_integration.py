"""
Integration tests for the UDPChat-AI server.

Author: Andrej Kudriavcev
Last Updated: 29/09/2025
"""

import pytest
import json
import socket
import time
from unittest.mock import patch, Mock
from tests.hello import run as run_hello_test


class TestServerIntegration:
    """Integration tests for the server."""
    
    def test_server_startup(self):
        """Test that the server can start up without errors."""
        # This is a basic test to ensure the server module can be imported
        # We'll test the class structure without instantiating it
        from server.server import UDPChatServer
        
        # Basic assertions about the class
        assert UDPChatServer is not None
        assert hasattr(UDPChatServer, '__init__')
        assert hasattr(UDPChatServer, 'listen')
        assert hasattr(UDPChatServer, 'handle_message')
        
        # Test that we can create a mock instance
        server = Mock(spec=UDPChatServer)
        assert server is not None
    
    def test_packet_handling_flow(self, mock_server, db_connection, sample_user):
        """Test the complete packet handling flow."""
        mock_server.db = db_connection
        
        # Test login flow
        from protocol.packets.login import LoginPacket
        
        session = Mock()
        session.session_id = "test_session_123"
        session.user_id = None
        
        login_packet = LoginPacket(mock_server, session, {
            "email": sample_user.email,
            "password": "hashed_password"
        })
        
        login_result = login_packet.handle()
        
        assert login_result["type"] == "WELCOME"
        
        # Test room creation flow
        from protocol.packets.create_room import CreateRoomPacket
        
        session.user_id = sample_user.id
        import time
        unique_room_name = f"Integration Test Room {int(time.time() * 1000)}"
        create_room_packet = CreateRoomPacket(mock_server, session, {
            "name": unique_room_name,
            "is_private": False
        })
        
        room_result = create_room_packet.handle()
        assert room_result["type"] == "ROOM_CREATED"
    
    def test_database_operations(self, db_connection):
        """Test basic database operations."""
        from db.models import User, Room, Session, Member
        
        # Test user creation and retrieval
        import time
        timestamp = int(time.time() * 1000)
        unique_id = f"integration_test_user_{timestamp}"
        email = f"integration{timestamp}@test.com"
        user = User(
            user_id=unique_id,
            email=email,
            name="Integration Test User",
            password="33f2429083af5334fda0a1a8cdff70e0"  # MD5 hash of "hashed_password"
        )
        user.insert(db_connection)
        
        found_user = User.find_one(db_connection, user_id=unique_id)
        assert found_user is not None
        assert found_user.email == email
        
        # Test room creation
        room = Room(
            room_id=f"integration_test_room_{timestamp}",
            name=f"Integration Test Room {timestamp}",
            is_private=False
        )
        room.insert(db_connection)
        
        found_room = Room.find_one(db_connection, room_id=f"integration_test_room_{timestamp}")
        assert found_room is not None
        assert found_room.name == f"Integration Test Room {timestamp}"
        
        # Test session creation
        session = Session(
            session_id=f"integration_test_session_{timestamp}",
            user_id=found_user.id,
            session_key=f"integration_session_key_{timestamp}",
            last_active_at=None
        )
        session.insert(db_connection)
        
        found_session = Session.find_one(db_connection, session_id=f"integration_test_session_{timestamp}")
        assert found_session is not None
        assert found_session.user_id == found_user.id
        
        # Test member creation
        member = Member(
            room_id=found_room.id,
            user_id=found_user.id,
            joined_at=None
        )
        member.insert(db_connection)
        
        found_member = Member.find_one(
            db_connection, 
            room_id=found_room.id, 
            user_id=found_user.id
        )
        assert found_member is not None
    
    def test_error_handling(self, mock_server, db_connection):
        """Test error handling in packet processing."""
        mock_server.db = db_connection
        
        from protocol.packets.login import LoginPacket
        
        session = Mock()
        session.session_id = "test_session_123"
        session.user_id = None
        
        # Test with invalid email format
        login_packet = LoginPacket(mock_server, session, {
            "email": "invalid-email-format",
            "password": "wrong_password"
        })
        
        result = login_packet.handle()
        assert result["type"] == "ERROR"
        assert "Please provide a valid email address" in result["data"]["message"]
    
    def test_metrics_collection(self):
        """Test that metrics are properly collected."""
        from metrics import (
            user_logins_total, user_logouts_total, rooms_created_total,
            messages_sent_total, active_users, active_rooms
        )
        
        # Test that metrics can be incremented
        initial_logins = user_logins_total._value._value
        user_logins_total.inc()
        assert user_logins_total._value._value == initial_logins + 1
        
        initial_rooms = rooms_created_total._value._value
        rooms_created_total.inc()
        assert rooms_created_total._value._value == initial_rooms + 1
        
        # Test gauge operations
        active_users.set(5)
        assert active_users._value._value == 5
        
        active_rooms.set(3)
        assert active_rooms._value._value == 3
