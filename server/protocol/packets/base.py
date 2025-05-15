"""
Abstract base class for server client packet handlers.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from abc import ABC, abstractmethod # Abstract base class and abstract method

class BasePacket(ABC):
    """
    Abstract base class for packet handlers.
    """
    session = None # Session object
    data = None # Packet data
    server = None # Server object
    packet_type = 'ABSTRACT' # Default packet type

    def __init__(self, server, session, data):
        """
        Class constructor to initialize the packet data.
        :param server: Server object
        :param session: Session object
        :param data: Packet data
        """
        self.server = server
        self.session = session
        self.data = data

    @abstractmethod
    def handle(self):
        """
        Abstract method to handle the packet.
        This method should be implemented by subclasses to define the specific handling logic.
        """
        return self.handle_error("Packet handler not implemented.")


    def handle_error(self, message):
        """
        Handle error messages.
        """
        return {
            "type": "ERROR",
            "data": {
                "message": message
            },
        }
