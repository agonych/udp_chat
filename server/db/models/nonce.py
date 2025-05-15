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