#!/bin/bash
set -e

echo "Starting UDP Chat Server..."

# Initialize database
echo "Initializing database..."
python -c "from db import init_db; init_db()"

# Start the server with default configuration
echo "Starting UDP server..."
echo "About to execute: python main.py start"
exec python main.py start
