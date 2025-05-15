"""
Session model
Used to store user sessions in the database.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

import time
from .base import BaseModel


class Session(BaseModel):
    """
    Session model class representing a user session.
    """
    def __init__(
        self,
        id=None, # Primary key for the session
        session_id=None, # Unique identifier for the session
        user_id=None, # Foreign key referencing the user
        session_key=None, # Encrypted AES session key
        created_at=None, # Timestamp when the session was created
        last_active_at=None # Timestamp when the session was last active
    ):
        super().__init__(
            id=id,
            session_id=session_id,
            user_id=user_id,
            session_key=session_key,
            created_at=created_at,
            last_active_at=last_active_at
        )

    @classmethod
    def cleanup(cls, conn, timeout_seconds=600):
        """
        Cleanup old sessions from the database.
        :param conn: Database connection object
        :param timeout_seconds: Timeout in seconds for session inactivity
        :return: None
        """
        threshold = int(time.time()) - timeout_seconds
        query = f"DELETE FROM {cls.get_table_name()} WHERE last_active_at IS NOT NULL AND last_active_at < ?"
        conn.execute(query, (threshold,))
        conn.commit()
