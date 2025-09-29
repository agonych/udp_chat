"""
This module creates the packet dictionary and defines a function to handle packets.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from config import DEBUG
from protocol.packets import *

# Map packet types to handler classes
PACKET_REGISTRY = {
    "ACK": AckPacket,
    "HELLO": HelloPacket,
    "LOGIN": LoginPacket,
    "LOGOUT": LogoutPacket,
    "STATUS": StatusPacket,
    "MERGE_SESSION": MergeSessionPacket,
    "LIST_ROOMS": ListRoomsPacket,
    "CREATE_ROOM": CreateRoomPacket,
    "JOIN_ROOM": JoinRoomPacket,
    "LEAVE_ROOM": LeaveRoomPacket,
    "MESSAGE": MessagePacket,
    "AI_MESSAGE": AIMessagePacket,
    "LIST_MESSAGES": ListMessagesPacket,
    "LIST_MEMBERS": ListMembersPacket,
}

def handle_packet(server, session, payload):
    """
    Handle incoming packets from clients.
    :param server: Server instance
    :param session: Session instance
    :param payload: Payload data from the client
    :return: Response packet or error message
    """
    # Get the type of packet from the payload
    packet_type = payload.get("type")
    if DEBUG:
        print(f"Received packet type: {packet_type}")

    # Get the data from the payload
    data = payload.get("data", {})

    # Find the packet class based on the packet type
    packet_class = PACKET_REGISTRY.get(packet_type)
    if not packet_class:
        # If the packet type is not found, return an error message
        return {
            "type": "ERROR",
            "data": {
                "message": f"Unknown packet type: {packet_type}"
            },
        }
    else:
        # Handle the packet using the corresponding class and return the response
        return packet_class(server, session, data).handle()
