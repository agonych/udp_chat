"""
LOGOUT packet handler
This packet logs out the current user by removing their user ID from the session.

It does not delete the session itself (which is used for transport security), but simply clears
the associated user, effectively ending the authenticated state.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from server.db.models import Session
import time

class LogoutPacket(BasePacket):
    """
    Handles LOGOUT packets from clients.
    """
    packet_type = "LOGOUT"

    def handle(self):
        db = self.server.db
        session = self.session

        if not session.user_id:
            return {
                "type": "ERROR",
                "data": {"message": "You are not logged in."}
            }

        # Clear user from session
        Session.update(
            db,
            pk_field="session_id",
            pk_value=session.session_id,
            user_id=None,
            last_active_at=int(time.time())
        )

        return {
            "type": "STATUS",
            "data": {
                "session_id": session.session_id,
                "user": None
            }
        }
