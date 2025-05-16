"""
LEAVE_ROOM packet handler.
This packet is used to leave an existing room. If the room becomes empty
after the user leaves, the room is deleted automatically.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from server.db.models import Room, Member, Session, User
from server.config import DEBUG


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
        db = self.server.db

        # Ensure user is authenticated
        if not self.session.user_id:
            return self.handle_error("Authentication required.")

        # Get and validate room_id
        room_id = self.data.get("room_id", "").strip()
        if not room_id:
            return self.handle_error("Room ID is required.")

        room = Room.find_one(db, room_id=room_id)
        if not room:
            return self.handle_error("Room not found.")

        # Check membership
        member = Member.find_one(db, room_id=room.id, user_id=self.session.user_id)
        if not member:
            return self.handle_error("You are not a member of this room.")

        # Remove the user from the room
        Member.delete(db, room_id=room.id, user_id=self.session.user_id)

        # Notify remaining members
        user = User.find_one(db, id=self.session.user_id)
        members = Room.get_member_ids(db, room.id)
        if members:
            sessions = Session.find_all(db, user_id=[m["user_id"] for m in members])
            session_ids = [s.session_id for s in sessions]

            self.server.broadcast({
                "type": "MEMBER_LEFT",
                "data": {
                    "room_id": room.room_id,
                    "member_id": user.user_id,
                }
            }, session_ids)

            # If the room is now empty, delete it
        else:
            # No members left in the room, delete it
            Room.delete(db, room_id=room.room_id)
            if DEBUG:
                print(f"Room '{room.name}' deleted because it has no members.")

            # Get all public rooms
            rooms = Room.find_all(db, is_private=False)

            # Compose ROOM_LIST packet
            room_data = {
                "type": "ROOM_LIST",
                "data": [
                    {
                        "room_id": room.room_id,
                        "name": room.name,
                        "last_active_at": room.last_active_at
                    }
                    for room in rooms
                ]
            }

            # Broadcast the updated room list to all active sessions
            self.server.broadcast(room_data)

        # Return LEFT_ROOM response
        return {
            "type": "LEFT_ROOM",
            "data": {
                "room_id": room.room_id,
                "name": room.name
            }
        }
