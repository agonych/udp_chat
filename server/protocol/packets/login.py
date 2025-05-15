"""
LOGIN packet handler
This packet is used to log in a user to the server. The server supports two
types of users with and without passwords. For an unknown user, the server will
automatically create a new user with the provided email address. If the user
has a password in the database, the server will require the user to provide the password
to log in. If the user does not have a password, the server will allow the user to log in
with only the email address.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket
from server.db.models import User, Session, Room
import hashlib
import uuid
import time
from server.utils.tools import is_valid_email

class LoginPacket(BasePacket):
    """
    Handles LOGIN packets from clients.
    """
    packet_type = "LOGIN"

    def handle(self):
        """
        Handle the LOGIN packet.
        :return: WELCOME packet or one of error packets.
        """
        # Get email and password from the data
        email = self.data.get("email", '')
        password = self.data.get("password", '')

        # Check if a valid email is provided
        email = email.strip().lower()
        if not is_valid_email(email):
            email = ''

        # if email is empty or invalid, return error
        if not email:
            return {
                "type": "ERROR",
                "data": {"message": "Please provide a valid email address"}
            }

        # Get the database connection
        db = self.server.db

        # Find user by email
        user = User.find_one(db, email=email)

        # If user not found, create a new user
        if not user:
            # Generate user name from email
            name = email.split("@")[0]
            # Save new user to the database
            user = User(
                user_id=str(uuid.uuid4().hex),
                name=name,
                email=email,
                is_admin=False
            )
            user.insert(db)
            user = User.find_one(db, email=email)

        # Check if user account has a password set
        if user.password:
            if not password:
                # User has a password set, but no password provided, return login prompt
                return {
                    "type": "PLEASE_LOGIN",
                    "data": {
                        "message": "Please type your password to continue",
                        "email": email
                    }
                }

            # Hash the provided password and compare with stored password
            password_hash = hashlib.md5(password.encode()).hexdigest()
            if password_hash != user.password:
                # Password does not match, return error
                return {
                    "type": "UNAUTHORISED",
                    "data": {"message": "Incorrect password"}
                }

        # Save user ID into session
        Session.update(
            db,
            pk_field="session_id",
            pk_value=self.session.session_id,
            user_id=user.id,
            last_active_at=int(time.time())
        )
        # Get the room the user was last in
        room = Room.find_by_user(db, user.user_id)
        if room:
            # If the user was in a room, get the room details
            room = {
                "room_id": room.room_id,
                "name": room.name
            }
        # Return WELCOME packet
        return {
            "type": "WELCOME",
            "data": {
                "user": {
                    "email": user.email,
                    "name": user.name,
                    "user_id": user.user_id,
                    "room": room # If user was in a room, return room details
                }
            }
        }
