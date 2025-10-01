# UDPChat-AI Server Tests

This directory contains unit and integration tests for the UDPChat-AI server.

## Test Structure

- `conftest.py` - Pytest configuration and fixtures
- `test_database_models.py` - Unit tests for database models (User, Room, Session, Member)
- `test_packet_handlers.py` - Unit tests for packet handlers (Login, CreateRoom, JoinRoom, etc.)
- `test_encryption.py` - Unit tests for encryption utilities
- `test_integration.py` - Integration tests for complete workflows
- `hello.py` - Integration test for UDP communication

## Running Tests

### Local Development
```bash
# Run all tests
cd server
python run_tests.py

# Run specific test file
python -m pytest tests/test_database_models.py -v

# Run with coverage
python -m pytest tests/ --cov=. --cov-report=html
```

### Docker Environment
```bash
# Run tests in Docker container
make test-docker

# Run database connection test
make test-db
```

## Test Categories

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test complete workflows and component interactions
- **Database Tests**: Test database operations with temporary test database
- **Encryption Tests**: Test cryptographic functions and key management

## Fixtures

- `mock_server` - Mock server instance for testing
- `test_db` - Temporary SQLite database for testing
- `db_connection` - Database connection for testing
- `sample_user` - Pre-created test user
- `sample_room` - Pre-created test room
- `sample_session` - Pre-created test session

## Test Coverage

The tests cover:
- ✅ Database model operations (CRUD)
- ✅ Packet handler logic
- ✅ Encryption/decryption functions
- ✅ Error handling
- ✅ User authentication flow
- ✅ Room management
- ✅ Message handling
- ✅ Metrics collection

## Adding New Tests

1. Create test functions with `test_` prefix
2. Use existing fixtures or create new ones
3. Mock external dependencies
4. Test both success and error cases
5. Use descriptive test names

Example:
```python
def test_create_user_success(db_connection):
    """Test creating a new user successfully."""
    user = User(user_id="test", email="test@example.com", ...)
    user.insert(db_connection)
    
    found_user = User.find_one(db_connection, user_id="test")
    assert found_user is not None
    assert found_user.email == "test@example.com"
```


