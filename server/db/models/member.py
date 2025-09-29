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

    def insert(self, conn):
        """
        Override insert method for members table since it doesn't have an id column.
        The members table uses a composite primary key (room_id, user_id).
        """
        fields = {k: v for k, v in self.as_dict().items() if v is not None}
        keys = ", ".join(fields.keys())
        placeholders = ", ".join("%s" for _ in fields)
        values = tuple(fields.values())
        query = f"INSERT INTO {self.get_table_name()} ({keys}) VALUES ({placeholders})"
        with conn.cursor() as cur:
            cur.execute(query, values)
        # Members table doesn't have an id column, so return None
        return None