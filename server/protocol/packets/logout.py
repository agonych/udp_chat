"""
LOGOUT packet handler
This packet logs out the current user by removing their user ID from the session.

It does not delete the session itself (which is used for transport security), but simply clears
the associated user, effectively ending the authenticated state.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from db.models import Session
from datetime import datetime
import time
from metrics import user_logouts_total, active_users

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
            last_active_at=datetime.now()
        )
        
        # Record logout
        user_logouts_total.inc()
        active_users.dec()

        return {
            "type": "STATUS",
            "data": {
                "session_id": session.session_id,
                "user": None
            }
        }
