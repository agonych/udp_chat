"""
AI_MESSAGE packet handler.
This packet is used to request an AI to generate next message based on the
last 100 messages in the room or improve the last message of the user before sending it.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""
import time
from datetime import datetime

from .base import BasePacket
from db.models import Room, Member, Message, Session, User
from utils.ai import gtp_get_ai_response, ollama_get_ai_response

from config import AI_MODE

class AIMessagePacket(BasePacket):
    """
    Defines the AI_MESSAGE packet.
    """
    packet_type = "AI_MESSAGE"

    def handle(self):
        """
        Handle the AI_MESSAGE packet.
        :return: None
        """
        db = self.server.db # Get the database connection

        # Check if the user is authenticated
        if not self.session.user_id:
            return self.handle_error("Authentication required.")

        # Get room ID and message content from the data
        room_id = self.data.get("room_id", "").strip()
        content = self.data.get("content", "").strip()
        if not room_id:
            # Error, no room ID provided
            return self.handle_error("Room ID is required.")

        # Check if the room exists
        room = Room.find_one(db, room_id=room_id)
        if not room:
            # Error, room not found
            return self.handle_error("Room not found.")

        # Check if the user is a member of the room
        user = User.find_one(db, id=self.session.user_id)
        if not user:
            # Error, user not found
            return self.handle_error("User not found.")

        # Check if the user is a member of the room
        member = Member.find_one(db, room_id=room.id, user_id=self.session.user_id)
        if not member:
            # Error, user is not a member of the room
            return self.handle_error("You must join the room to request AI messages.")

        # Get the last 100 messages for context
        recent_messages = Room.last_messages(db, room_id, limit=100)

        # Get AI response using OpenAI
        try:
            if AI_MODE == "ollama":
                ai_text = ollama_get_ai_response(recent_messages, user.name, content)
            elif AI_MODE == "gpt":
                ai_text = gtp_get_ai_response(recent_messages, user.name, content)
            else:
                # Error, invalid AI mode
                return self.handle_error("Invalid AI mode configured.")
        except Exception as e:
            # Error, AI generation failed
            return self.handle_error(f"AI generation failed: {e}")

        # Save AI message to DB
        message = Message(
            room_id=room.id,
            user_id=self.session.user_id,
            content=ai_text,
            is_announcement=True,
            created_at=datetime.now()
        )
        message.insert(db)

        # Update room activity
        Room.update(db, "room_id", room.room_id, last_active_at=datetime.now())

        # Get all members of the room
        members = Room.get_member_ids(db, room.id)
        # Get active sessions for all members
        sessions = Session.find_all(db, user_id=[m["user_id"] for m in members])
        # Get session IDs
        session_ids = [s.session_id for s in sessions]

        if session_ids:
            # Broadcast the AI message to all active sessions in the room
            self.server.broadcast({
                "type": "MESSAGE",
                "data": {
                    "room_id": room.room_id,
                    "message_id": message.id,
                    "user_id": user.user_id,
                    "name": user.name,
                    "content": ai_text,
                    "timestamp": int(message.created_at.timestamp()) if message.created_at else None
                }
            }, session_ids)

        # No response needed
        return None
