"""
ACK packet handler.
This packet is used to acknowledge the receipt of a broadcast message.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from .base import BasePacket

class AckPacket(BasePacket):
    """
    Defines the ACK packet.
    """
    packet_type = "ACK" # Set the packet type to "ACK"

    def handle(self):
        """
        Handle the ACK packet.
        :return: None
        """
        # Get session ID and message ID from the data
        session_id = self.session.session_id
        message_id = self.data.get("msg_id")

        if not message_id:
            # Error, no message ID provided, silently ignore
            if self.server.DEBUG:
                print(f"[ACK] No message ID provided in ACK from session_id={session_id}")
            return None

        if self.server.dispatcher:
            # Acknowledge the message in the dispatcher and remove it from the queue
            self.server.dispatcher.acknowledge(session_id, message_id)

        if self.server.DEBUG:
            print(f"[ACK] Received ACK for msg_id={message_id} from session_id={session_id}")

        # No response required for ACK
        return None
