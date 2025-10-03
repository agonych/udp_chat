#!/bin/bash
set -e

echo "Starting UDP Chat Server..."

# Initialize database
echo "Initializing database..."
python main.py init_db

# Start the server
echo "Starting UDP server..."
exec python main.py start
