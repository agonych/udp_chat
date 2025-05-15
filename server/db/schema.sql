-- 1. Users
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT, -- Auto-incrementing user ID
    user_id TEXT UNIQUE NOT NULL, -- Randomised unique public ID
    name TEXT, -- Optional public name
    email TEXT UNIQUE NOT NULL, -- Email, compulsory for login
    password TEXT, -- Password is optional, user can choose to protect their account with a password
    is_admin BOOLEAN DEFAULT FALSE, -- Admin flag
    created_at INTEGER DEFAULT (strftime('%s','now')), -- Account creation timestamp
    updated_at INTEGER DEFAULT (strftime('%s','now')), -- Account update timestamp
    last_active_at INTEGER DEFAULT (strftime('%s','now')) -- Last active timestamp
);

-- Index on users.user_id
CREATE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id);

-- 2. Sessions
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT, -- Auto-incrementing session ID
    session_id TEXT UNIQUE NOT NULL, -- Randomised unique public session identifier
    user_id INTEGER, -- User ID, foreign key to users table
    session_key TEXT UNIQUE NOT NULL, -- Unique AES session encryption key
    created_at INTEGER DEFAULT (strftime('%s','now')), -- Session creation timestamp
    last_active_at INTEGER DEFAULT (strftime('%s','now')), -- Last active timestamp
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE -- Foreign key constraint to users table
);

-- Index on sessions.session_id
CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id);
-- Index on sessions.user_id
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
-- Index on sessions.session_key
CREATE INDEX IF NOT EXISTS idx_sessions_session_key ON sessions(session_key);

-- 3. Nonces
CREATE TABLE IF NOT EXISTS nonces (
    session_id INTEGER NOT NULL, -- Session ID, foreign key to sessions table
    nonce TEXT NOT NULL, -- Randomised unique nonce
    PRIMARY KEY (session_id, nonce), -- Composite primary key
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE -- Foreign key constraint to sessions table
);

-- Index on nonces.session_id
CREATE INDEX IF NOT EXISTS idx_nonces_session_id ON nonces(session_id);
-- Index on nonces.nonce
CREATE INDEX IF NOT EXISTS idx_nonces_nonce ON nonces(nonce);

-- 4. Rooms
CREATE TABLE IF NOT EXISTS rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT, -- Auto-incrementing room ID
    room_id TEXT UNIQUE NOT NULL, -- Randomised unique public room identifier
    name TEXT UNIQUE, -- Optional public name
    is_private BOOLEAN DEFAULT FALSE, -- Private room flag, default is public
    created_at INTEGER DEFAULT (strftime('%s','now')), -- Room creation timestamp
    last_active_at INTEGER DEFAULT (strftime('%s','now')) -- Last active timestamp
);

-- Index on rooms.room_id
CREATE INDEX IF NOT EXISTS idx_rooms_room_id ON rooms(room_id);

-- 5. Members (users in rooms)
CREATE TABLE IF NOT EXISTS members (
    room_id INTEGER NOT NULL, -- Room ID, foreign key to rooms table
    user_id INTEGER NOT NULL, -- User ID, foreign key to users table
    is_admin BOOLEAN DEFAULT FALSE, -- Admin flag for the user in the room, default is false
    joined_at INTEGER DEFAULT (strftime('%s','now')), -- Timestamp when the user joined the room
    PRIMARY KEY (room_id, user_id), -- Composite primary key
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE, -- Foreign key constraint to rooms table
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE -- Foreign key constraint to users table
);

-- Index on members.room_id
CREATE INDEX IF NOT EXISTS idx_members_room_id ON members(room_id);
-- Index on members.user_id
CREATE INDEX IF NOT EXISTS idx_members_user_id ON members(user_id);

-- 6. Messages
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT, -- Auto-incrementing message ID
    room_id INTEGER NOT NULL, -- Room ID, foreign key to rooms table
    user_id INTEGER NOT NULL, -- User ID, foreign key to users table
    content TEXT NOT NULL, -- Message content
    is_announcement BOOLEAN DEFAULT FALSE, -- Announcement flag, default is false
    created_at INTEGER DEFAULT (strftime('%s','now')), -- Message creation timestamp
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE, -- Foreign key constraint to rooms table
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE -- Foreign key constraint to users table
);

-- Index on messages.room_id
CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages(room_id);
-- Index on messages.user_id
CREATE INDEX IF NOT EXISTS idx_messages_user_id ON messages(user_id);
