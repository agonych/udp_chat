"""
CREATE_ROOM packet handler.
This packet is used to create a new room.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from db.models import Room, Member
import uuid
import time
from datetime import datetime

class CreateRoomPacket(BasePacket):
    """
    Defines the CREATE_ROOM packet.
    """
    packet_type = "CREATE_ROOM"

    def handle(self):
        """
        Handle the CREATE_ROOM packet.
        :return: CREATED_ROOM packet or error message.
        """
        # Get the database connection
        db = self.server.db

        # Check if the user is authenticated
        if not self.session.user_id:
            # Error, user not authenticated
            return self.handle_error("Authentication required.")

        # Get room name from the data
        name = self.data.get("name", "").strip()
        if not name:
            # Error, no room name provided
            return self.handle_error("Room name is required.")

        # Ensure name is unique
        existing = Room.find_one(db, name=name)
        if existing:
            # Error, room name already exists
            return self.handle_error("Room with that name already exists.")

        # Create a new room
        room = Room(
            room_id=str(uuid.uuid4().hex),
            name=name,
            is_private=False,
            created_at=datetime.now(),
            last_active_at=datetime.now()
        )
        room.insert(db)

        # Add user as room admin
        Member(
            room_id=room.id,
            user_id=self.session.user_id,
            is_admin=True
        ).insert(db)

        # Get all public rooms
        rooms = Room.find_all(db, is_private=False)

        # Compose ROOM_LIST packet
        room_data = {
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
        # Broadcast the updated room list to all active sessions
        self.server.broadcast(room_data)

        # Return room creation confirmation packet
        return {
            "type": "ROOM_CREATED",
            "data": {
                "room_id": room.room_id,
                "name": room.name
            }
        }
