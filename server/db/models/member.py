"""
Member Model
Used to store information about members in a chat room.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BaseModel

class Member(BaseModel):
    """
    Model class representing a member in a chat room.
    """
    def __init__(
        self,
        room_id=None, # Foreign key to the room table
        user_id=None, # Foreign key to the user table
        is_admin=False, # Boolean indicating if the user is an admin
        joined_at=None # Timestamp of when the user joined the room
    ):
        super().__init__(
            room_id=room_id,
            user_id=user_id,
            is_admin=is_admin,
            joined_at=joined_at
        )