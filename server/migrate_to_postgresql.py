#!/usr/bin/env python3
"""
Migration script to help transition from SQLite to PostgreSQL.

This script provides utilities to:
1. Export data from SQLite
2. Import data to PostgreSQL
3. Verify the migration

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

import json
import sqlite3
import psycopg2
import psycopg2.extras
from datetime import datetime
import sys
import os

# Add the server directory to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

def export_sqlite_data(sqlite_path):
    """
    Export data from SQLite database.
    :param sqlite_path: Path to the SQLite database file
    :return: Dictionary containing all table data
    """
    print(f"Exporting data from SQLite database: {sqlite_path}")
    
    conn = sqlite3.connect(sqlite_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # Get all table names
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
    tables = [row[0] for row in cursor.fetchall()]
    
    data = {}
    for table in tables:
        print(f"  Exporting table: {table}")
        cursor.execute(f"SELECT * FROM {table}")
        rows = cursor.fetchall()
        data[table] = [dict(row) for row in rows]
        print(f"    Exported {len(rows)} rows")
    
    conn.close()
    return data

def import_to_postgresql(data):
    """
    Import data to PostgreSQL database.
    :param data: Dictionary containing table data
    :return: None
    """
    print("Importing data to PostgreSQL database...")
    
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        conn.cursor_factory = psycopg2.extras.RealDictCursor
        
        # Define table order for proper foreign key constraints
        table_order = ['users', 'sessions', 'nonces', 'rooms', 'members', 'messages']
        
        for table in table_order:
            if table in data and data[table]:
                print(f"  Importing table: {table}")
                rows = data[table]
                
                if not rows:
                    continue
                
                # Get column names from first row
                columns = list(rows[0].keys())
                placeholders = ', '.join(['%s'] * len(columns))
                columns_str = ', '.join(columns)
                
                query = f"INSERT INTO {table} ({columns_str}) VALUES ({placeholders})"
                
                with conn.cursor() as cur:
                    for row in rows:
                        values = [row.get(col) for col in columns]
                        cur.execute(query, values)
                
                print(f"    Imported {len(rows)} rows")
        
        conn.commit()
        print("Data import completed successfully!")
        
    except psycopg2.Error as e:
        print(f"Error importing to PostgreSQL: {e}")
        raise
    finally:
        if conn:
            conn.close()

def verify_migration():
    """
    Verify that the PostgreSQL database has the correct data.
    :return: None
    """
    print("Verifying migration...")
    
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        conn.cursor_factory = psycopg2.extras.RealDictCursor
        
        tables = ['users', 'sessions', 'nonces', 'rooms', 'members', 'messages']
        
        with conn.cursor() as cur:
            for table in tables:
                cur.execute(f"SELECT COUNT(*) as count FROM {table}")
                result = cur.fetchone()
                count = result['count'] if result else 0
                print(f"  {table}: {count} rows")
        
        print("Migration verification completed!")
        
    except psycopg2.Error as e:
        print(f"Error verifying migration: {e}")
        raise
    finally:
        if conn:
            conn.close()

def main():
    """
    Main migration function.
    """
    print("=== SQLite to PostgreSQL Migration Tool ===")
    print()
    
    # Check if old SQLite database exists
    sqlite_path = os.path.join('storage', 'db', 'chat.db')
    if not os.path.exists(sqlite_path):
        print(f"SQLite database not found at: {sqlite_path}")
        print("Nothing to migrate.")
        return
    
    try:
        # Step 1: Export from SQLite
        data = export_sqlite_data(sqlite_path)
        
        # Step 2: Import to PostgreSQL
        import_to_postgresql(data)
        
        # Step 3: Verify migration
        verify_migration()
        
        print()
        print("=== Migration completed successfully! ===")
        print("You can now safely remove the SQLite database file if desired.")
        
    except Exception as e:
        print(f"Migration failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
