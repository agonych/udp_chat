#!/usr/bin/env python3
"""
Test script to verify PostgreSQL connection and basic operations.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

import sys
import os

# Add the server directory to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from db import get_connection, init_db
from db.models.user import User
from config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

def test_connection():
    """Test basic PostgreSQL connection."""
    print("Testing PostgreSQL connection...")
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT version()")
            version = cur.fetchone()
            print(f"✓ Connected to PostgreSQL: {version[0]}")
        return True
    except Exception as e:
        print(f"✗ Connection failed: {e}")
        return False

def test_database_creation():
    """Test database initialization."""
    print("Testing database initialization...")
    try:
        init_db()
        print("✓ Database initialized successfully")
        return True
    except Exception as e:
        print(f"✗ Database initialization failed: {e}")
        return False

def test_user_operations():
    """Test basic user model operations."""
    print("Testing user model operations...")
    try:
        conn = get_connection()
        
        # Test user creation
        user = User(
            user_id="test_user_123",
            name="Test User",
            email="test@example.com",
            is_admin=False
        )
        
        user_id = user.insert(conn)
        print(f"✓ User created with ID: {user_id}")
        
        # Test user retrieval
        found_user = User.find_one(conn, user_id=user.user_id)
        if found_user:
            print(f"✓ User retrieved: {found_user.name}")
        else:
            print("✗ User not found")
            return False
        
        # Test user update
        User.update(conn, 'id', user_id, name="Updated Test User")
        updated_user = User.find_one(conn, id=user_id)
        if updated_user and updated_user.name == "Updated Test User":
            print("✓ User updated successfully")
        else:
            print("✗ User update failed")
            return False
        
        # Test user deletion
        User.delete(conn, id=user_id)
        deleted_user = User.find_one(conn, id=user_id)
        if not deleted_user:
            print("✓ User deleted successfully")
        else:
            print("✗ User deletion failed")
            return False
        
        return True
        
    except Exception as e:
        print(f"✗ User operations failed: {e}")
        return False

def main():
    """Run all tests."""
    print("=== PostgreSQL Migration Test ===")
    print(f"Database: {DB_NAME}@{DB_HOST}:{DB_PORT}")
    print(f"User: {DB_USER}")
    print()
    
    tests = [
        test_connection,
        test_database_creation,
        test_user_operations
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print(f"=== Test Results ===")
    print(f"Passed: {passed}/{total}")
    
    if passed == total:
        print("✓ All tests passed! PostgreSQL migration is working correctly.")
        return 0
    else:
        print("✗ Some tests failed. Please check the configuration.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
