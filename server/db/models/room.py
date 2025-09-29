"""
Room model
Used to store information about chat rooms.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BaseModel

class Room(BaseModel):
    """
    Room model class representing a chat room.
    """
    def __init__(
            self,
            id=None, # Primary key for the room
            room_id=None, # Unique identifier for the room
            name=None,  # Name of the room
            is_private=False, # Boolean indicating if the room is private
            created_at=None, # Timestamp when the room was created
            last_active_at=None # Timestamp when the room was last active
    ):
        super().__init__(
            id=id,
            room_id=room_id,
            name=name,
            is_private=is_private,
            created_at=created_at,
            last_active_at=last_active_at
        )

    @classmethod
    def get_members(cls, conn, room_id):
        """
        Get all members of a room.
        :param conn: Database connection object
        :param room_id: The ID of the room to get members from
        :return: List of members in the room
        """
        query = """
        SELECT users.user_id, users.name, members.is_admin, members.joined_at
        FROM members
        JOIN users ON members.user_id = users.id
        WHERE members.room_id = %s
        ORDER BY users.name
        """
        with conn.cursor() as cur:
            cur.execute(query, (room_id,))
            return [dict(row) for row in cur.fetchall()]

    @classmethod
    def get_member_ids(cls, conn, room_id):
        """
        Get list of member IDs in a room.
        :param conn: Database connection object
        :param room_id:  The ID of the room to get member IDs from
        :return:  List of member IDs in the room
        """
        query = """
        SELECT members.user_id
        FROM members
        WHERE members.room_id = %s
        """
        with conn.cursor() as cur:
            cur.execute(query, (room_id,))
            return [dict(row) for row in cur.fetchall()]

    @classmethod
    def touch(cls, conn, room_id):
        """
        Update the last active timestamp of a room.
        :param conn: Database connection object
        :param room_id: The ID of the room to update
        :return: None
        """
        from datetime import datetime
        query = f"UPDATE {cls.get_table_name()} SET last_active_at = %s WHERE room_id = %s"
        with conn.cursor() as cur:
            cur.execute(query, (datetime.now(), room_id))

    @classmethod
    def exists_by_name(cls, conn, name):
        """
        Check if a room with the given name exists.
        :param conn: Database connection object
        :param name: The name of the room to check
        :return: True if the room exists, False otherwise
        """
        query = f"SELECT 1 FROM {cls.get_table_name()} WHERE name = %s"
        with conn.cursor() as cur:
            cur.execute(query, (name,))
            return cur.fetchone() is not None

    @classmethod
    def last_messages(cls, conn, room_id, limit=100):
        """
        Get the last messages from a room.
        :param conn: Database connection object
        :param room_id: The ID of the room to get messages from
        :param limit: The maximum number of messages to retrieve
        :return: List of messages in the room
        """
        query = """
            SELECT messages.*, users.user_id AS sender_user_id, users.name AS sender_name
            FROM messages
            JOIN users ON messages.user_id = users.id
            WHERE messages.room_id = (
                SELECT id FROM rooms WHERE room_id = %s
            )
            ORDER BY messages.created_at DESC
            LIMIT %s
        """
        with conn.cursor() as cur:
            cur.execute(query, (room_id, limit))
            return [dict(row) for row in cur.fetchall()]

    @classmethod
    def find_by_user(cls, conn, user_id):
        """
        Find the last active room for a user.
        :param conn: Database connection object
        :param user_id: The ID of the user to find the room for
        :return: Room object if found, None otherwise
        """
        query = """
            SELECT rooms.*
            FROM rooms
            JOIN members ON rooms.id = members.room_id
            WHERE members.user_id = (
                SELECT id FROM users WHERE user_id = %s
            )
            ORDER BY rooms.last_active_at DESC
            LIMIT 1
        """
        with conn.cursor() as cur:
            cur.execute(query, (user_id,))
            row = cur.fetchone()
            return cls.from_row(row) if row else None
