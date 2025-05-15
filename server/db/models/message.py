"""
Message model
Used to store messages in a chat room.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BaseModel

class Message(BaseModel):
    """
    Message model class for handling messages in the database.
    """
    def __init__(
        self,
        id=None, # Primary key
        room_id=None, # Foreign key to the room table
        user_id=None, # Foreign key to the user table
        content=None, # Content of the message
        is_announcement=False, # Boolean flag indicating if the message is an announcement
        created_at=None # Timestamp of when the message was created
    ):
        super().__init__(
            id=id,
            room_id=room_id,
            user_id=user_id,
            content=content,
            is_announcement=is_announcement,
            created_at=created_at
        )