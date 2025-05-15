"""
HELLO packet handler
This packet is used to test the connection to the server.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket

class HelloPacket(BasePacket):
    """
    Handles HELLO packets from clients.
    """
    def handle(self):
        # Return a welcome message
        return {
            "type": "HELLO",
            "message": "Welcome to UDPChat-AI."
        }
