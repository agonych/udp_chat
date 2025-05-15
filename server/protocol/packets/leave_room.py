"""
LEAVE_ROOM packet handler.
This packet is used to leave an existing room.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from server.db.models import Room, Member, Session, User

class LeaveRoomPacket(BasePacket):
    """
    Defines the LEAVE_ROOM packet.
    """
    packet_type = "LEAVE_ROOM"

    def handle(self):
        """
        Handle the LEAVE_ROOM packet.
        :return: LEFT_ROOM packet or error message.
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

        # Check if user is a member
        member = Member.find_one(db, room_id=room.id, user_id=self.session.user_id)
        if not member:
            # User is not a member of the room
            return self.handle_error("You are not a member of this room.")

        # Remove the user from the room
        Member.delete(db, room_id=room.id, user_id=self.session.user_id)

        # Get the user object
        user = User.find_one(db, id=self.session.user_id)

        # Get all members of the room
        members = Room.get_member_ids(db, room.id)
        # Get active sessions for all members
        sessions = Session.find_all(db, user_id=[member["user_id"] for member in members])
        # Get session IDs for all active sessions
        session_ids = [session.session_id for session in sessions]
        # Broadcast to all active sessions
        self.server.broadcast({
            "type": "MEMBER_LEFT",
            "data": {
                "room_id": room.room_id,
                "member_id": user.user_id,
            }
        }, session_ids)

        # Return LEFT_ROOM packet
        return {
            "type": "LEFT_ROOM",
            "data": {
                "room_id": room.room_id,
                "name": room.name
            }
        }
