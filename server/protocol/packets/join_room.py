"""
JOIN_ROOM packet handler.
This packet is used to join an existing room.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from server.db.models import Room, Member, Session, User
import time

class JoinRoomPacket(BasePacket):
    """
    Defines the JOIN_ROOM packet.
    """
    packet_type = "JOIN_ROOM"

    def handle(self):
        """
        Handle the JOIN_ROOM packet.
        :return: JOINED_ROOM packet or error message.
        """
        # Get the database connection
        db = self.server.db

        # Check if the user is authenticated
        if not self.session.user_id:
            # Error, user not authenticated
            return self.handle_error("Authentication required.")

        # Get room ID from the data
        room_id = self.data.get("room_id", "").strip()
        if not room_id:
            # Error, no room ID provided
            return self.handle_error("Room ID is required.")

        # Check if the room exists
        room = Room.find_one(db, room_id=room_id)
        if not room:
            # Error, room not found
            return self.handle_error("Room not found.")

        # Check if the user is already a member of the room
        existing = Member.find_one(db, room_id=room.id, user_id=self.session.user_id)
        if existing:
            # User is already a member, nothing to do
            return None

        # Get the user object
        user = User.find_one(db, id=self.session.user_id)
        if not user:
            # Error, user not found
            return self.handle_error("User not found.")

        # build member object from user
        member  = {
            "user_id": user.user_id,
            "name": user.name,
            "is_admin": user.is_admin,
            "joined_at": int(time.time())
        }

        # Add user as a member of the room
        Member(
            room_id=room.id,
            user_id=self.session.user_id,
            joined_at=int(time.time())
        ).insert(db)

        # Get all room members
        members = Room.get_member_ids(db, room.id)
        # Get active sessions for all members
        sessions = Session.find_all(db, user_id=[member["user_id"] for member in members])
        # Get the session IDs
        session_ids = [session.session_id for session in sessions]
        # Broadcast to all active sessions
        self.server.broadcast({
            "type": "MEMBER_JOINED",
            "data": {
                "room_id": room.room_id,
                "member": member
            }
        }, session_ids)

        # Return join room confirmation packet
        return {
            "type": "JOINED_ROOM",
            "data": {
                "room_id": room.room_id,
                "name": room.name
            }
        }
