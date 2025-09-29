"""

This file implement tools for the server.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""


import re

def is_valid_email(email):
    """
    Validate an email address using a regular expression
    :param email: Email address to validate
    :return: True if valid, False otherwise
    """
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None
