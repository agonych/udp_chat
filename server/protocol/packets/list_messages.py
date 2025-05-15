"""
LIST_MEMBERS packet handler
This packet is used to list the previous messages in a room (up to 100).

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from server.db.models import Room

class ListMessagesPacket(BasePacket):
    """
    Defines the LIST_MESSAGES packet.
    """
    packet_type = "LIST_MESSAGES"

    def handle(self):
        """
        Handle the LIST_MESSAGES packet.
        :return: ROOM_HISTORY packet or error message.
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

        # Get the last 100 messages for the room
        rows = Room.last_messages(db, room_id, limit=100)

        # Return the list of messages
        return {
            "type": "ROOM_HISTORY",
            "data": [
                {
                    "message_id": row["id"],
                    "user_id": row["sender_user_id"],
                    "name": row["sender_name"],
                    "content": row["content"],
                    "timestamp": row["created_at"]
                }
                for row in reversed(rows)  # oldest first
            ]
        }
