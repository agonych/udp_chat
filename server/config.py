"""
Configuration file for the server.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

import os # imported os for path manipulations
from dotenv import load_dotenv # imported load_dotenv to load environment variables from .env file
load_dotenv()

def get_dir(base, subdir):
    """
    Returns absolute path of a subdirectory within the base directory.
    Checks if the subdirectory exists, and if not, it creates it.
    :param base: str: The base directory.
    :param subdir: str: The subdirectory to create or get.
    :return: str: The absolute path of the subdirectory.
    """
    path = os.path.join(base, subdir)
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path

# Define base directory and subdirectories
BASE_DIR = str(os.path.dirname(os.path.abspath(__file__)))
STORAGE_DIR = str(get_dir(BASE_DIR, 'storage'))
DB_DIR = str(get_dir(STORAGE_DIR, 'db'))
KEY_DIR = str(get_dir(STORAGE_DIR, 'keys'))

# Define path for database
DB_PATH = os.path.join(DB_DIR, 'chat.db')
# Define paths for keys
PRIVATE_KEY_PATH = os.path.join(KEY_DIR, 'server_private_key.pem')
PUBLIC_KEY_PATH = os.path.join(KEY_DIR, 'server_public_key.pem')

# Define server configuration
SERVER_IP = os.getenv('SERVER_IP', '127.0.0.1')
SERVER_PORT = int(os.getenv('SERVER_PORT', 9999))
BUFFER_SIZE = int(os.getenv('BUFFER_SIZE', 8192))
DEBUG = os.getenv('DEBUG', 'False').lower() in ('true', '1', 't', 'yes', 'y')

# Define OpenAI API key and AI mode
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
AI_MODE= os.getenv('AI_MODE', 'ollama')

print(f"DEBUG: {DEBUG}")
