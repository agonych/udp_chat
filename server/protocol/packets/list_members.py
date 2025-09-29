"""
LIST_MEMBERS packet handler
This packet is used to list the members of a room.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from db.models import Room

class ListMembersPacket(BasePacket):
    """
    Defines the LIST_MEMBERS packet.
    """
    packet_type = "LIST_MEMBERS"

    def handle(self):
        """
        Handle the LIST_MEMBERS packet.
        :return: ROOM_MEMBERS packet or error message.
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

        # Get the list of members in the room
        members = Room.get_members(db, room.id)

        # Convert datetime fields to strings for JSON serialization
        serialized_members = []
        for member in members:
            serialized_member = {
                "user_id": member["user_id"],
                "name": member["name"],
                "is_admin": member["is_admin"],
                "joined_at": int(member["joined_at"].timestamp()) if member["joined_at"] else None
            }
            serialized_members.append(serialized_member)

        # Return the list of members
        return {
            "type": "ROOM_MEMBERS",
            "data": serialized_members # List of members in the room
        }
