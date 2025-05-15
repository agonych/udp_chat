"""
UDPChat-AI Dispatcher

This module defines the UdpDispatcher class, responsible for managing outbound UDP messages
that require delivery confirmation through retries. Since UDP does not guarantee delivery,
this component attempts to deliver encrypted packets up to a maximum number of retries.

Features:
- Retries undelivered messages up to MAX_RETRIES with configurable RETRY_INTERVAL
- Thread-safe queue using locks
- Runs in a dedicated background thread
- Integrates with the main UDPChatServer to access active sessions and send encrypted packets
- Cleans up expired delivery attempts after reaching retry limits

Used by the UDPChatServer to dispatch messages to clients in a reliable way, compensating for
UDP's inherent lack of delivery assurance.
"""

import time # Import time for time-based operations
import threading # Import threading for concurrent execution
import uuid # Import uuid for unique message IDs

from server.config import DEBUG

MAX_RETRIES = 5 # Maximum number of retries for sending a message
RETRY_INTERVAL = 2  # Interval in seconds between retries

class UdpDispatcher:
    """
    UdpDispatcher class for managing outbound UDP messages with delivery confirmation.
    """
    def __init__(self, server):
        """
        Initialize the UdpDispatcher.
        :param server: Reference to the main server instance.
        """
        self.server = server # Reference to the main server instance
        self.lock = threading.Lock() # Lock for thread-safe operations
        self.queue = []  # list of tasks to be processed
        self.running = True # Flag to control the dispatcher thread
        self.thread = threading.Thread(target=self.run, daemon=True) # Create a thread for the dispatcher
        self.thread.start() # Start the dispatcher thread

    def stop(self):
        """
        Method to stop the dispatcher thread.
        """
        self.running = False
        self.thread.join()

    def enqueue(self, session_id, payload_dict):
        """
        Enqueue a message for delivery.
        :param session_id: The session ID of the client to send the message to.
        :param payload_dict: The payload dictionary containing the message data.
        :return: None
        """
        # Get session information from the list of active sessions
        session_info = self.server.active_sessions.get(session_id)
        # If session is not found, stop processing
        if not session_info:
            return
        # Generate a unique message ID for the payload
        msg_id = str(uuid.uuid4().hex)
        # Add the message ID to the payload dictionary
        payload_dict["msg_id"] = msg_id
        # Create a task dictionary with session info, payload, and retry count
        task = {
            "msg_id": msg_id,
            "session": session_info["session"],
            "addr": session_info["addr"],
            "payload": payload_dict,
            "retry_count": 0,
            "last_sent": 0
        }

        # Append the task to the queue in a thread-safe manner
        with self.lock:
            self.queue.append(task)

    def run(self):
        """
        Main loop for the dispatcher thread.
        This method runs in a separate thread and processes the queue of tasks.
        """
        # Run the dispatcher loop until stopped
        while self.running:
            # Get the current time
            now = time.time()
            to_resend = []
            # Process the queue of tasks in a thread-safe manner
            with self.lock:
                # Iterate over the tasks in the queue
                for task in self.queue[:]:
                    # if task have been attempted to send too many times - remove it
                    if task["retry_count"] >= MAX_RETRIES:
                        self.queue.remove(task)
                        continue
                    # Check if task is to be sent or resent
                    if now - task["last_sent"] >= RETRY_INTERVAL:
                        # Send the message using the server's method
                        self.server.encode_and_send_message(task["session"], task["payload"], task["addr"])
                        # Update the task with the current time and increment retry count
                        task["retry_count"] += 1
                        task["last_sent"] = now
            # No more tasks to process, sleep for a bit
            time.sleep(1)

    def acknowledge(self, session_id, message_id):
        """
        Acknowledge successful receipt of a message and remove it from the queue.
        :param session_id: The session ID of the client that acknowledged the message.
        :param message_id: The message ID of the acknowledged message.
        :return: None
        """
        # process the queue of tasks in a thread-safe manner
        with self.lock:
            # Get the original length of the queue
            original_len = len(self.queue)
            # Filter the queue to remove the acknowledged message
            self.queue = [
                # Loop through the tasks in the queue
                task for task in self.queue
                # Only keep tasks that do not match the session ID and message ID
                if not (
                    task["session"].session_id == session_id and
                    task["payload"].get("msg_id") == message_id
                )
            ]
            if DEBUG and len(self.queue) < original_len:
                print(f"[DISPATCHER] Acknowledged and removed message {message_id} for session {session_id}")
