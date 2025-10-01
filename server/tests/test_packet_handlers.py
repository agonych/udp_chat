"""
Unit tests for packet handlers.

Author: Andrej Kudriavcev
Last Updated: 29/09/2025
"""

import pytest
import json
from unittest.mock import Mock, patch
from protocol.packets.login import LoginPacket
from protocol.packets.create_room import CreateRoomPacket
from protocol.packets.join_room import JoinRoomPacket
from protocol.packets.leave_room import LeaveRoomPacket
from protocol.packets.message import MessagePacket


class TestLoginPacket:
    """Test cases for LoginPacket."""
    
    def test_login_success(self, mock_server, db_connection, sample_user):
        """Test successful login."""
        mock_server.db = db_connection
        
        # Create a mock session
        session = Mock()
        session.session_id = "test_session_123"
        session.user_id = None
        
        packet = LoginPacket(mock_server, session, {
            "email": sample_user.email,
            "password": "hashed_password"  # Use the actual password from sample_user
        })
        
        result = packet.handle()
        
        assert result["type"] == "WELCOME"
        assert result["data"]["user"]["email"] == sample_user.email
        assert result["data"]["user"]["name"] == sample_user.name
    
    def test_login_invalid_credentials(self, mock_server, db_connection, sample_user):
        """Test login with invalid credentials for existing user with password."""
        from db.models import User
        mock_server.db = db_connection
        
        # Set a password for the existing user
        User.update(db_connection, pk_field="id", pk_value=sample_user.id, password="correct_password_hash")
        
        session = Mock()
        session.session_id = "test_session_123"
        session.user_id = None
        
        packet = LoginPacket(mock_server, session, {
            "email": sample_user.email,
            "password": "wrong_password"
        })
        
        result = packet.handle()
        
        assert result["type"] == "UNAUTHORISED"
        assert "Incorrect password" in result["data"]["message"]


class TestCreateRoomPacket:
    """Test cases for CreateRoomPacket."""
    
    def test_create_room_success(self, mock_server, db_connection, sample_user, sample_session):
        """Test successful room creation."""
        import time
        unique_name = f"New Test Room {int(time.time() * 1000)}"
        mock_server.db = db_connection
        sample_session.user_id = sample_user.id
        
        packet = CreateRoomPacket(mock_server, sample_session, {
            "name": unique_name,
            "is_private": False
        })
        
        result = packet.handle()
        
        assert result["type"] == "ROOM_CREATED"
        assert result["data"]["name"] == unique_name
        
        # Verify room was created in database
        from db.models import Room
        rooms = Room.find_all(db_connection, name=unique_name)
        assert len(rooms) == 1
    
    def test_create_room_duplicate_name(self, mock_server, db_connection, sample_user, sample_session, sample_room):
        """Test creating room with duplicate name."""
        mock_server.db = db_connection
        sample_session.user_id = sample_user.id
        
        packet = CreateRoomPacket(mock_server, sample_session, {
            "name": sample_room.name,  # Use existing room name
            "is_private": False
        })
        
        result = packet.handle()
        
        assert result["type"] == "ERROR"
        assert "Room with that name already exists" in result["data"]["message"]


class TestJoinRoomPacket:
    """Test cases for JoinRoomPacket."""
    
    def test_join_room_success(self, mock_server, db_connection, sample_user, sample_session, sample_room):
        """Test successful room join."""
        mock_server.db = db_connection
        sample_session.user_id = sample_user.id
        
        packet = JoinRoomPacket(mock_server, sample_session, {
            "room_id": sample_room.room_id
        })
        
        result = packet.handle()
        
        assert result["type"] == "JOINED_ROOM"
        assert result["data"]["room_id"] == sample_room.room_id
        assert result["data"]["name"] == sample_room.name
        
        # Verify user was added to room
        from db.models import Member
        member = Member.find_one(db_connection, room_id=sample_room.id, user_id=sample_user.id)
        assert member is not None
    
    def test_join_nonexistent_room(self, mock_server, db_connection, sample_user, sample_session):
        """Test joining a room that doesn't exist."""
        mock_server.db = db_connection
        sample_session.user_id = sample_user.id
        
        packet = JoinRoomPacket(mock_server, sample_session, {
            "room_id": "nonexistent_room"
        })
        
        result = packet.handle()
        
        assert result["type"] == "ERROR"
        assert "Room not found" in result["data"]["message"]


class TestLeaveRoomPacket:
    """Test cases for LeaveRoomPacket."""
    
    def test_leave_room_success(self, mock_server, db_connection, sample_user, sample_session, sample_room):
        """Test successful room leave."""
        mock_server.db = db_connection
        sample_session.user_id = sample_user.id
        
        # First, add user to room
        from db.models import Member
        member = Member(
            room_id=sample_room.id,
            user_id=sample_user.id,
            joined_at=None
        )
        member.insert(db_connection)
        
        packet = LeaveRoomPacket(mock_server, sample_session, {
            "room_id": sample_room.room_id
        })
        
        result = packet.handle()
        
        assert result["type"] == "LEFT_ROOM"
        assert result["data"]["room_id"] == sample_room.room_id
        
        # Verify user was removed from room
        member = Member.find_one(db_connection, room_id=sample_room.id, user_id=sample_user.id)
        assert member is None
    
    def test_leave_room_not_member(self, mock_server, db_connection, sample_user, sample_session, sample_room):
        """Test leaving a room the user is not a member of."""
        mock_server.db = db_connection
        sample_session.user_id = sample_user.id
        
        packet = LeaveRoomPacket(mock_server, sample_session, {
            "room_id": sample_room.room_id
        })
        
        result = packet.handle()
        
        assert result["type"] == "ERROR"
        assert "You are not a member of this room" in result["data"]["message"]


class TestMessagePacket:
    """Test cases for MessagePacket."""
    
    def test_send_message_success(self, mock_server, db_connection, sample_user, sample_session, sample_room):
        """Test successful message sending."""
        mock_server.db = db_connection
        sample_session.user_id = sample_user.id
        
        # First, add user to room
        from db.models import Member
        member = Member(
            room_id=sample_room.id,
            user_id=sample_user.id,
            joined_at=None
        )
        member.insert(db_connection)
        
        packet = MessagePacket(mock_server, sample_session, {
            "room_id": sample_room.room_id,
            "content": "Hello, world!"
        })
        
        result = packet.handle()
        
        assert result["type"] == "MESSAGE_SENT"
        assert result["data"]["content"] == "Hello, world!"
        assert result["data"]["room_id"] == sample_room.room_id
    
    def test_send_message_not_in_room(self, mock_server, db_connection, sample_user, sample_session, sample_room):
        """Test sending message when not in room."""
        mock_server.db = db_connection
        sample_session.user_id = sample_user.id
        
        packet = MessagePacket(mock_server, sample_session, {
            "room_id": sample_room.room_id,
            "content": "Hello, world!"
        })
        
        result = packet.handle()
        
        assert result["type"] == "ERROR"
        assert "You must join the room before sending messages" in result["data"]["message"]
