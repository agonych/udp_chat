"""
User model
Used to store user information in the database.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""


from .base import BaseModel

class User(BaseModel):
    """
    User model class representing a user in the system.
    """
    def __init__(
        self,
        id=None, # Primary key for the user
        user_id=None, # Unique identifier for the user
        name=None, # Name of the user
        email=None, # Email address of the user
        password=None, # Password hash for the user
        is_admin=False, # Boolean indicating if the user is an admin
        created_at=None, # Timestamp when the user was created
        updated_at=None, # Timestamp when the user was last updated
        last_active_at=None # Timestamp when the user was last active
    ):
        super().__init__(
            id=id,
            user_id=user_id,
            name=name,
            email=email,
            password=password,
            is_admin=is_admin,
            created_at=created_at,
            updated_at=updated_at,
            last_active_at=last_active_at
        )