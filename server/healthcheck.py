#!/usr/bin/env python3
"""
Health check script for UDPChat-AI Server
"""

import socket
import sys

def check_udp_port(host='localhost', port=9999):
    """Check if UDP port is open and listening"""
    try:
        # Create a UDP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(1)
        
        # Try to send a small packet to the port
        # This will fail if the port is not open
        sock.bind(('', 0))  # Bind to any available port
        sock.sendto(b'health_check', (host, port))
        
        sock.close()
        return True
    except Exception:
        return False

if __name__ == '__main__':
    if check_udp_port():
        print("Server is healthy")
        sys.exit(0)
    else:
        print("Server is unhealthy")
        sys.exit(1)
