"""
Unit tests for encryption utilities.

Author: Andrej Kudriavcev
Last Updated: 29/09/2025
"""

import pytest
import base64
from utils.encryption import generate_nonce, encrypt_key_for_client


class TestEncryption:
    """Test cases for encryption utilities."""
    
    def test_generate_nonce(self):
        """Test nonce generation."""
        nonce1 = generate_nonce()
        nonce2 = generate_nonce()
        
        # Nonces should be different
        assert nonce1 != nonce2
        
        # Nonces should be 12 bytes (96 bits)
        assert len(nonce1.to_bytes(12, 'big')) == 12
        assert len(nonce2.to_bytes(12, 'big')) == 12
    
    def test_encrypt_key_for_client_format(self):
        """Test that encrypted key is in correct format."""
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.hazmat.primitives import serialization
        
        # Generate client key pair
        client_private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048
        )
        client_public_key = client_private_key.public_key()
        
        # Convert to DER format and then to Base64
        client_pubkey_der = client_public_key.public_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )
        client_pubkey_b64 = base64.b64encode(client_pubkey_der).decode()
        
        # Test data
        test_key = b"test_aes_key_32_bytes_long_12345"
        
        # Encrypt the key
        encrypted_key = encrypt_key_for_client(client_pubkey_b64, test_key)
        
        # Encrypted key should be bytes
        assert isinstance(encrypted_key, bytes)
        
        # Should be longer than original key (due to RSA padding)
        assert len(encrypted_key) > len(test_key)
    
    def test_encrypt_key_for_client_with_different_keys(self):
        """Test encrypting with different key sizes."""
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.hazmat.primitives import serialization
        
        # Test with 1024-bit key
        client_private_key_1024 = rsa.generate_private_key(
            public_exponent=65537,
            key_size=1024
        )
        client_public_key_1024 = client_private_key_1024.public_key()
        
        client_pubkey_der_1024 = client_public_key_1024.public_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )
        client_pubkey_b64_1024 = base64.b64encode(client_pubkey_der_1024).decode()
        
        test_key = b"test_aes_key_32_bytes_long_12345"
        
        # Should work with 1024-bit key
        encrypted_key_1024 = encrypt_key_for_client(client_pubkey_b64_1024, test_key)
        assert isinstance(encrypted_key_1024, bytes)
        assert len(encrypted_key_1024) > len(test_key)
        
        # Test with 2048-bit key
        client_private_key_2048 = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048
        )
        client_public_key_2048 = client_private_key_2048.public_key()
        
        client_pubkey_der_2048 = client_public_key_2048.public_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )
        client_pubkey_b64_2048 = base64.b64encode(client_pubkey_der_2048).decode()
        
        encrypted_key_2048 = encrypt_key_for_client(client_pubkey_b64_2048, test_key)
        assert isinstance(encrypted_key_2048, bytes)
        assert len(encrypted_key_2048) > len(test_key)
        
        # 2048-bit encrypted key should be longer than 1024-bit
        assert len(encrypted_key_2048) > len(encrypted_key_1024)