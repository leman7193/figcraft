#!/bin/bash
# Simple shell script to test MCP server connection
# Usage: ./test-mcp-simple.sh <host> <port>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <host> <port>"
    echo "Example: $0 figcraft-mcp.onrender.com 10001"
    exit 1
fi

HOST=$1
PORT=$2

echo "Testing FigCraft MCP server at $HOST:$PORT..."
echo ""

# Test 1: TCP connection
echo "Test 1: TCP Connection"
if timeout 5 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
    echo "✓ TCP connection successful"
else
    echo "✗ TCP connection failed"
    exit 1
fi

echo ""
echo "Test 2: MCP Initialize"

# Send MCP initialize request
INIT_REQUEST='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'

# Use netcat if available, otherwise try bash /dev/tcp
if command -v nc &> /dev/null; then
    RESPONSE=$(echo "$INIT_REQUEST" | timeout 10 nc $HOST $PORT | head -1)
else
    RESPONSE=$(exec 3<>/dev/tcp/$HOST/$PORT && echo "$INIT_REQUEST" >&3 && timeout 10 cat <&3 | head -1)
fi

if echo "$RESPONSE" | grep -q '"result"'; then
    echo "✓ MCP server responded correctly"
    echo "Response: $RESPONSE"
else
    echo "✗ Invalid MCP response"
    echo "Response: $RESPONSE"
    exit 1
fi

echo ""
echo "✓ All tests passed! MCP server is working."
