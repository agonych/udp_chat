"""
Nonce model
Used to store seen session nonces in the database.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BaseModel

class Nonce(BaseModel):
    """
    Nonce model class for handling nonces in the database.
    """
    def __init__(
        self,
        session_id=None, # Foreign key to the session table
        nonce=None # Nonce value
    ):
        super().__init__(
            session_id=session_id,
            nonce=nonce
        )
    
    def insert(self, conn):
        """
        Override insert method for nonces table since it doesn't have an id column.
        The nonces table uses a composite primary key (session_id, nonce).
        """
        fields = {k: v for k, v in self.as_dict().items() if v is not None}
        keys = ", ".join(fields.keys())
        placeholders = ", ".join("%s" for _ in fields)
        values = tuple(fields.values())
        query = f"INSERT INTO {self.get_table_name()} ({keys}) VALUES ({placeholders})"
        with conn.cursor() as cur:
            cur.execute(query, values)
        # Nonces table doesn't have an id column, so return None
        return None