"""
STATUS packet handler
This packet is used to check the the user and update is on the client.
It is sent every 10 seconds to update the user status and keep the connection alive.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from db.models import Session, User, Room

class StatusPacket(BasePacket):
    """
    Handles STATUS packets from clients.
    """
    packet_type = "STATUS"

    def handle(self):
        """
        Handle the STATUS packet.
        :return: STATUS packet or error message.
        """

        # Get the database connection
        db = self.server.db
        # Get the session object
        session = Session.find_one(db, session_id=self.session.session_id)

        # Check if the session exists
        if not session:
            # Error, session not found
            return {
                "type": "ERROR",
                "data": { "message": "Invalid session ID" }
            }

        # initialize user info dictionary
        user_info = {}

        # Check if the user is authenticated
        if session.user_id:
            # Get the user object
            user = User.find_one(db, id=session.user_id)
            if user:
                # Check if the user is a member of a room
                room = Room.find_by_user(db, user.user_id)
                # if the user is a member of a room, get the room info
                if room:
                    room = {
                        "room_id": room.room_id,
                        "name": room.name
                    }
                # Populate user info
                user_info = {
                    "email": user.email,
                    "name": user.name,
                    "user_id": user.user_id,
                    "room": room # add room info if available
                }

        # Return the status packet
        return {
            "type": "STATUS",
            "data": {
                "session_id": session.session_id,
                "user": user_info # populate user info if available
            }
        }
