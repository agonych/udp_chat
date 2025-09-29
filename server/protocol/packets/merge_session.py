"""
MERGE_SESSION packet handler.
This packet is used to merge an old session with a new one.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from db.models import Session, User, Room
from datetime import datetime
import time

class MergeSessionPacket(BasePacket):
    """
    Defines the MERGE_SESSION packet.
    """
    packet_type = "MERGE_SESSION"

    def handle(self):
        """
        Handle the MERGE_SESSION packet.
        :return: MERGE_SESSION_FAILED or WELCOME packet.
        """
        # Get the ID and key of the old session from the data
        old_session_id = self.data.get("old_session_id", "").strip()
        old_session_key = self.data.get("old_session_key", "").strip()

        # Check if the old session ID and key are provided
        if not old_session_id or not old_session_key:
            # Error, old session ID or key not provided
            return { "type": "MERGE_SESSION_FAILED" }

        # Get the database connection
        db = self.server.db

        # Check if the old session exists and is valid
        old_session = Session.find_one(db, session_id=old_session_id)
        if not old_session:
            # Error, old session not found
            return { "type": "MERGE_SESSION_FAILED" }

        # Check if the old session has a key
        if not old_session.session_key:
            # Error, old session has no key
            return { "type": "MERGE_SESSION_FAILED" }

        # Check if the old session key matches
        if old_session.session_key != old_session_key:
            # Error, old session key does not match
            return { "type": "MERGE_SESSION_FAILED" }

        # Check if the old session has a user ID
        if not old_session.user_id:
            # Error, old session has no user ID
            return { "type": "MERGE_SESSION_FAILED" }

        # Find the user in the database
        user = User.find_one(db, id=old_session.user_id)
        if not user:
            # Error, user not found
            return { "type": "MERGE_SESSION_FAILED" }

        # Attach user to new session
        Session.update(
            db,
            pk_field="session_id",
            pk_value=self.session.session_id,
            user_id=user.id,
            last_active_at=datetime.now()
        )

        # Get the room data for the user
        room = Room.find_by_user(db, user.user_id)
        if room:
            room = {
                "room_id": room.room_id,
                "name": room.name
            }

        # Return the WELCOME packet with user data
        return {
            "type": "WELCOME",
            "data": {
                "user": {
                    "email": user.email,
                    "name": user.name,
                    "user_id": user.user_id,
                    "room": room # Include room data if available
                }
            }
        }
