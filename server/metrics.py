"""
Prometheus metrics for UDPChat-AI Server
"""
from prometheus_client import Counter, Gauge, Histogram, start_http_server
import time

# Counters for events
user_logins_total = Counter('udpchat_user_logins_total', 'Total number of user logins')
user_logouts_total = Counter('udpchat_user_logouts_total', 'Total number of user logouts')
rooms_created_total = Counter('udpchat_rooms_created_total', 'Total number of rooms created')
rooms_deleted_total = Counter('udpchat_rooms_deleted_total', 'Total number of rooms deleted')
room_joins_total = Counter('udpchat_room_joins_total', 'Total number of room joins')
room_leaves_total = Counter('udpchat_room_leaves_total', 'Total number of room leaves')
messages_sent_total = Counter('udpchat_messages_sent_total', 'Total number of messages sent')
ai_messages_sent_total = Counter('udpchat_ai_messages_sent_total', 'Total number of AI messages sent')
udp_packets_processed_total = Counter('udpchat_udp_packets_processed_total', 'Total number of UDP packets processed')

# Gauges for current state
active_users = Gauge('udpchat_active_users', 'Number of currently active users')
active_rooms = Gauge('udpchat_active_rooms', 'Number of currently active rooms')
active_sessions = Gauge('udpchat_active_sessions', 'Number of currently active sessions')

# Histograms for performance
packet_processing_time = Histogram('udpchat_packet_processing_seconds', 'Time spent processing UDP packets')
database_operation_time = Histogram('udpchat_database_operation_seconds', 'Time spent on database operations')

def start_metrics_server(port=None):
    """Start the Prometheus metrics HTTP server"""
    if port is None:
        import os
        port = int(os.environ.get('METRICS_PORT', '8000'))
    start_http_server(port)
    print(f"Prometheus metrics server started on port {port}")

def record_packet_processing_time(func):
    """Decorator to record packet processing time"""
    def wrapper(*args, **kwargs):
        with packet_processing_time.time():
            return func(*args, **kwargs)
    return wrapper

def record_database_operation_time(func):
    """Decorator to record database operation time"""
    def wrapper(*args, **kwargs):
        with database_operation_time.time():
            return func(*args, **kwargs)
    return wrapper

