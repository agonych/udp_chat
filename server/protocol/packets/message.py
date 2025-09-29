"""
MESSAGE packet handler.
This packet is used to send a message to a room.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from db.models import Room, Member, Message, Session, User
from datetime import datetime

class MessagePacket(BasePacket):
    """
    Defines the MESSAGE packet.
    """
    packet_type = "MESSAGE"

    def handle(self):
        """
        Handle the MESSAGE packet.
        :return: None
        """
        # Get the database connection
        db = self.server.db

        # Check if the user is authenticated
        if not self.session.user_id:
            # Error, user not authenticated
            return self.handle_error("Authentication required.")

        # Get room ID and content from the data
        room_id = self.data.get("room_id", "").strip()
        content = self.data.get("content", "").strip()

        # Check if room ID and content are provided
        if not room_id or not content:
            # Error, no room ID or content provided
            return self.handle_error("Room ID and content are required.")

        # Check if the room exists
        room = Room.find_one(db, room_id=room_id)
        if not room:
            # Error, room not found
            return self.handle_error("Room not found.")

        # Get the user object
        user = User.find_one(db, id=self.session.user_id)

        # Check membership
        member = Member.find_one(db, room_id=room.id, user_id=self.session.user_id)
        if not member:
            # Error, user is not a member of the room
            return self.handle_error("You must join the room before sending messages.")

        # Insert message
        message = Message(
            room_id=room.id,
            user_id=self.session.user_id,
            content=content,
            is_announcement=False,
            created_at=datetime.now()
        )
        message.insert(db)

        # Update room activity
        Room.update(db, "room_id", room.room_id, last_active_at=datetime.now())

        # Get all members of the room
        members = Room.get_member_ids(db, room.id)
        # Get active sessions for all members
        sessions = Session.find_all(db, user_id=[member["user_id"] for member in members])
        # Get session IDs for all active sessions
        session_ids = [session.session_id for session in sessions]

        # Broadcast the message to all active sessions
        self.server.broadcast({
            "type": "MESSAGE",
            "data": {
                "room_id": room.room_id,
                "message_id": message.id,
                "user_id": user.user_id,
                "name": user.name,
                "content": content,
                "timestamp": int(message.created_at.timestamp()) if message.created_at else None
            }
        }, session_ids)
        
        # Return message confirmation packet
        return {
            "type": "MESSAGE_SENT",
            "data": {
                "message_id": message.id,
                "room_id": room.room_id,
                "content": content,
                "timestamp": int(message.created_at.timestamp()) if message.created_at else None
            }
        }
