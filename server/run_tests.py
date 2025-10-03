#!/usr/bin/env python3
"""
Test runner for UDPChat-AI server.

Author: Andrej Kudriavcev
Last Updated: 29/09/2025
"""

import sys
import os
import subprocess

def run_tests():
    """Run all tests using pytest."""
    # Add the server directory to Python path
    server_dir = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, server_dir)
    
    # Set up test environment
    os.environ['PYTHONPATH'] = server_dir
    
    # Run pytest
    cmd = [sys.executable, '-m', 'pytest', 'tests/', '-v', '--tb=short']
    
    try:
        result = subprocess.run(cmd, cwd=server_dir, check=True)
        print("\n✅ All tests passed!")
        return 0
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Tests failed with exit code {e.returncode}")
        return e.returncode
    except Exception as e:
        print(f"\n❌ Error running tests: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(run_tests())





