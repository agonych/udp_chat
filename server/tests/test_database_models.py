"""
Unit tests for database models.

Author: Andrej Kudriavcev
Last Updated: 29/09/2025
"""

import pytest
from datetime import datetime
from db.models import User, Room, Session, Member


class TestUser:
    """Test cases for User model."""
    
    def test_user_creation(self, db_connection):
        """Test creating a new user."""
        import time
        unique_id = f"test_user_{int(time.time() * 1000)}"
        user = User(
            user_id=unique_id,
            email=f"test{unique_id}@example.com",
            name="Test User 456",
            password="hashed_password_456"
        )
        user.insert(db_connection)
        
        # Verify user was created
        found_user = User.find_one(db_connection, user_id=unique_id)
        assert found_user is not None
        assert found_user.email == f"test{unique_id}@example.com"
        assert found_user.name == "Test User 456"
    
    def test_user_find_by_email(self, db_connection, sample_user):
        """Test finding user by email."""
        found_user = User.find_one(db_connection, email=sample_user.email)
        assert found_user is not None
        assert found_user.user_id == sample_user.user_id
    
    def test_user_find_all(self, db_connection, sample_user):
        """Test finding all users."""
        users = User.find_all(db_connection)
        assert len(users) >= 1
        assert any(user.user_id == sample_user.user_id for user in users)


class TestRoom:
    """Test cases for Room model."""
    
    def test_room_creation(self, db_connection, sample_user):
        """Test creating a new room."""
        import time
        unique_id = f"test_room_{int(time.time() * 1000)}"
        room = Room(
            room_id=unique_id,
            name=f"Test Room {unique_id}",
            is_private=True
        )
        room.insert(db_connection)
        
        # Verify room was created
        found_room = Room.find_one(db_connection, room_id=unique_id)
        assert found_room is not None
        assert found_room.name == f"Test Room {unique_id}"
        assert found_room.is_private is True
    
    def test_room_find_by_user(self, db_connection, sample_user, sample_room):
        """Test finding room by user."""
        # First, add user to room
        member = Member(
            room_id=sample_room.id,
            user_id=sample_user.id,
            joined_at=datetime.now()
        )
        member.insert(db_connection)
        
        # Find room by user
        found_room = Room.find_by_user(db_connection, sample_user.user_id)
        assert found_room is not None
        assert found_room.room_id == sample_room.room_id
    
    def test_room_get_member_ids(self, db_connection, sample_user, sample_room):
        """Test getting member IDs for a room."""
        # Add user to room
        member = Member(
            room_id=sample_room.id,
            user_id=sample_user.id,
            joined_at=datetime.now()
        )
        member.insert(db_connection)
        
        # Get member IDs
        member_ids = Room.get_member_ids(db_connection, sample_room.id)
        assert len(member_ids) == 1
        assert member_ids[0]["user_id"] == sample_user.id  # Compare with database ID, not user_id string


class TestSession:
    """Test cases for Session model."""
    
    def test_session_creation(self, db_connection, sample_user):
        """Test creating a new session."""
        import time
        unique_id = f"test_session_{int(time.time() * 1000)}"
        session = Session(
            session_id=unique_id,
            user_id=sample_user.id,
            session_key=f"test_session_key_{int(time.time() * 1000)}",
            last_active_at=datetime.now()
        )
        session.insert(db_connection)
        
        # Verify session was created
        found_session = Session.find_one(db_connection, session_id=unique_id)
        assert found_session is not None
        assert found_session.user_id == sample_user.id
    
    def test_session_find_by_user(self, db_connection, sample_user, sample_session):
        """Test finding sessions by user."""
        sessions = Session.find_all(db_connection, user_id=sample_user.id)
        assert len(sessions) >= 1
        assert any(session.session_id == sample_session.session_id for session in sessions)


class TestMember:
    """Test cases for Member model."""
    
    def test_member_creation(self, db_connection, sample_user, sample_room):
        """Test creating a new member."""
        member = Member(
            room_id=sample_room.id,
            user_id=sample_user.id,
            joined_at=datetime.now()
        )
        member.insert(db_connection)
        
        # Verify member was created
        found_member = Member.find_one(
            db_connection, 
            room_id=sample_room.id, 
            user_id=sample_user.id
        )
        assert found_member is not None
        assert found_member.room_id == sample_room.id
        assert found_member.user_id == sample_user.id
    
    def test_member_deletion(self, db_connection, sample_user, sample_room):
        """Test deleting a member."""
        # Create member
        member = Member(
            room_id=sample_room.id,
            user_id=sample_user.id,
            joined_at=datetime.now()
        )
        member.insert(db_connection)
        
        # Delete member
        Member.delete(db_connection, room_id=sample_room.id, user_id=sample_user.id)
        
        # Verify member was deleted
        found_member = Member.find_one(
            db_connection, 
            room_id=sample_room.id, 
            user_id=sample_user.id
        )
        assert found_member is None
