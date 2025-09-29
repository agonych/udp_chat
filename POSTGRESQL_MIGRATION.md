# PostgreSQL Migration Guide

This guide explains how to migrate the UDPChat-AI project from SQLite to PostgreSQL.

## Overview

The migration involves:
- Updating database configuration
- Converting SQLite schema to PostgreSQL
- Updating database models for PostgreSQL compatibility
- Installing PostgreSQL dependencies

## Prerequisites

1. **PostgreSQL Installation**
   - Install PostgreSQL 12+ on your system
   - Or use Docker (recommended for development)

2. **Python Dependencies**
   - Install the new PostgreSQL driver: `pip install psycopg2-binary`

## Quick Start with Docker

The easiest way to get started is using Docker Compose:

```bash
# Start PostgreSQL with Docker
docker-compose -f docker-compose.postgresql.yml up -d

# Initialize the database schema
cd server
python main.py init_db
```

## Manual PostgreSQL Setup

### 1. Install PostgreSQL

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

**macOS (with Homebrew):**
```bash
brew install postgresql
brew services start postgresql
```

**Windows:**
Download and install from [postgresql.org](https://www.postgresql.org/download/windows/)

### 2. Create Database and User

```bash
# Connect to PostgreSQL as superuser
sudo -u postgres psql

# Create database and user
CREATE DATABASE udpchat;
CREATE USER udpchat_user WITH PASSWORD 'udpchat_password';
GRANT ALL PRIVILEGES ON DATABASE udpchat TO udpchat_user;
\q
```

### 3. Configure Environment

Copy the sample environment file:
```bash
cp server/env.postgresql.sample server/.env
```

Edit `server/.env` with your PostgreSQL credentials:
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=udpchat
DB_USER=udpchat_user
DB_PASSWORD=udpchat_password
```

### 4. Install Dependencies

```bash
cd server
pip install -r requirements.txt
```

### 5. Initialize Database

```bash
python main.py init_db
```

## Migration from Existing SQLite Database

If you have an existing SQLite database with data, use the migration script:

```bash
cd server
python migrate_to_postgresql.py
```

This script will:
1. Export all data from your SQLite database
2. Import it into PostgreSQL
3. Verify the migration was successful

## Key Changes Made

### 1. Database Configuration (`server/config.py`)
- Replaced SQLite path with PostgreSQL connection parameters
- Added environment variable support for database configuration

### 2. Database Connection (`server/db/__init__.py`)
- Replaced `sqlite3` with `psycopg2`
- Added database creation functionality
- Updated connection handling for PostgreSQL

### 3. Schema (`server/db/schema.sql`)
- Converted SQLite data types to PostgreSQL equivalents:
  - `INTEGER PRIMARY KEY AUTOINCREMENT` → `SERIAL PRIMARY KEY`
  - `TEXT` → `VARCHAR(255)` or `TEXT`
  - `INTEGER` timestamps → `TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
- Added PostgreSQL-specific features:
  - Automatic `updated_at` timestamp triggers
  - Additional performance indexes
  - Proper foreign key constraints

### 4. Models (`server/db/models/base.py`)
- Updated SQL parameter placeholders from `?` to `%s`
- Changed cursor handling to use context managers
- Updated `INSERT` statements to use `RETURNING id` for getting last inserted ID
- Removed manual `commit()` calls (PostgreSQL handles this automatically)

## Performance Improvements

PostgreSQL offers several advantages over SQLite:

1. **Better Concurrency**: Multiple connections can read/write simultaneously
2. **Advanced Indexing**: More sophisticated indexing options
3. **Query Optimization**: Better query planner and optimization
4. **ACID Compliance**: Full ACID transaction support
5. **Scalability**: Can handle much larger datasets
6. **Replication**: Built-in replication support for high availability

## Troubleshooting

### Connection Issues
```bash
# Test PostgreSQL connection
psql -h localhost -p 5432 -U udpchat_user -d udpchat
```

### Permission Issues
```sql
-- Grant necessary permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO udpchat_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO udpchat_user;
```

### Port Conflicts
If port 5432 is already in use, change the port in your `.env` file:
```env
DB_PORT=5433
```

## Verification

After migration, verify everything works:

1. **Start the server:**
   ```bash
   cd server
   python main.py start
   ```

2. **Test the client:**
   ```bash
   cd client
   npm run dev
   ```

3. **Check database:**
   ```sql
   -- Connect to database
   psql -h localhost -p 5432 -U udpchat_user -d udpchat
   
   -- Check tables
   \dt
   
   -- Check data
   SELECT COUNT(*) FROM users;
   SELECT COUNT(*) FROM messages;
   ```

## Rollback (if needed)

If you need to rollback to SQLite:

1. Revert the changes to `server/config.py`
2. Revert the changes to `server/db/__init__.py`
3. Revert the changes to `server/db/models/base.py`
4. Restore the original `server/db/schema.sql`
5. Remove `psycopg2-binary` from `requirements.txt`

## Support

If you encounter issues during migration:

1. Check PostgreSQL logs: `sudo journalctl -u postgresql`
2. Verify database connectivity
3. Check environment variables
4. Ensure all dependencies are installed

The migration maintains full compatibility with the existing application while providing the benefits of a robust PostgreSQL database.
