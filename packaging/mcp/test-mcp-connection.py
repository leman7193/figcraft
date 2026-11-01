#!/usr/bin/env python3
"""
Test script for FigCraft MCP server deployment.
Usage: python3 test-mcp-connection.py <host> <port>
Example: python3 test-mcp-connection.py figcraft-mcp.onrender.com 10001
"""

import socket
import json
import sys

def test_mcp_connection(host, port):
    """Test the MCP server connection and initialization."""
    try:
        print(f"Connecting to {host}:{port}...")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect((host, int(port)))
        print("✓ Connected successfully")

        # Send MCP initialize request
        init_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        }

        message = json.dumps(init_request) + "\n"
        print(f"Sending: {message.strip()}")
        sock.sendall(message.encode('utf-8'))

        # Receive response
        print("Waiting for response...")
        response = b""
        while b"\n" not in response:
            chunk = sock.recv(4096)
            if not chunk:
                break
            response += chunk

        if response:
            response_str = response.decode('utf-8').strip()
            print(f"✓ Received response: {response_str}")

            try:
                response_json = json.loads(response_str)
                if "result" in response_json:
                    print("✓ MCP server initialized successfully!")
                    print(f"  Server info: {response_json.get('result', {}).get('serverInfo', {})}")
                    return True
                else:
                    print(f"✗ Unexpected response format: {response_json}")
                    return False
            except json.JSONDecodeError as e:
                print(f"✗ Invalid JSON response: {e}")
                return False
        else:
            print("✗ No response received")
            return False

    except socket.timeout:
        print("✗ Connection timed out")
        return False
    except ConnectionRefusedError:
        print("✗ Connection refused - is the server running?")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False
    finally:
        sock.close()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 test-mcp-connection.py <host> <port>")
        print("Example: python3 test-mcp-connection.py figcraft-mcp.onrender.com 10001")
        sys.exit(1)

    host = sys.argv[1]
    port = sys.argv[2]

    success = test_mcp_connection(host, port)
    sys.exit(0 if success else 1)
