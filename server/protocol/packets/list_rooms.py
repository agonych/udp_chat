"""
LIST_ROOMS packet handler.
This packet is used to list all public rooms available on the server.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from db.models import Room

class ListRoomsPacket(BasePacket):
    """
    Defines the LIST_ROOMS packet.
    """
    packet_type = "LIST_ROOMS"

    def handle(self):
        """
        Handle the LIST_ROOMS packet.
        :return: ROOM_LIST packet with all public rooms.
        """
        # Get the database connection
        db = self.server.db
        # Get all public rooms
        rooms = Room.find_all(db, is_private=False)

        # Return the list of rooms
        return {
            "type": "ROOM_LIST",
            "data": [
                {
                    "room_id": room.room_id,
                    "name": room.name,
                    "last_active_at": int(room.last_active_at.timestamp()) if room.last_active_at else None
                }
                for room in rooms
            ]
        }
