#!/bin/sh
# Render entrypoint for figcraft MCP server (see packaging/mcp/Dockerfile.render).
# The MCP server speaks JSON-RPC 2.0 over stdio according to the Model Context Protocol.
# It runs headless (in-process engine session, no window, CPU renderer).
#
# This script provides both:
# 1. HTTP health check endpoint for Render
# 2. WebSocket connections that bridge to MCP stdio sessions

set -eu

LISTEN_PORT="${PORT:-47901}"

cat > /tmp/mcp-server.py << 'PYEOF'
#!/usr/bin/env python3
"""
WebSocket server that bridges to figcraft-cli mcp stdio sessions.
Also provides HTTP health check endpoint for Render.
"""
import asyncio
import subprocess
import sys
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread

class HealthCheckHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Respond to health check requests"""
        if self.path in ['/', '/healthz', '/health']:
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'FigCraft MCP Server OK\n')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        """Suppress access log spam"""
        if os.environ.get('DEBUG'):
            super().log_message(format, *args)

def run_health_server(port):
    """Run HTTP server for health checks"""
    server = HTTPServer(('0.0.0.0', port), HealthCheckHandler)
    print(f"Health check server listening on port {port}", file=sys.stderr)
    server.serve_forever()

async def handle_stdio_bridge(reader, writer):
    """Bridge a TCP connection to figcraft-cli mcp stdio"""
    proc = None
    try:
        # Start figcraft-cli mcp process
        proc = await asyncio.create_subprocess_exec(
            '/usr/local/bin/figcraft-cli', 'mcp',
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

        # Bridge: client -> mcp stdin
        async def forward_to_mcp():
            try:
                while True:
                    data = await reader.read(8192)
                    if not data:
                        break
                    proc.stdin.write(data)
                    await proc.stdin.drain()
            except Exception as e:
                print(f"Error forwarding to MCP: {e}", file=sys.stderr)
            finally:
                if proc.stdin:
                    proc.stdin.close()

        # Bridge: mcp stdout -> client
        async def forward_from_mcp():
            try:
                while True:
                    data = await proc.stdout.read(8192)
                    if not data:
                        break
                    writer.write(data)
                    await writer.drain()
            except Exception as e:
                print(f"Error forwarding from MCP: {e}", file=sys.stderr)
            finally:
                writer.close()
                await writer.wait_closed()

        # Run both bridges concurrently
        await asyncio.gather(forward_to_mcp(), forward_from_mcp())

    except Exception as e:
        print(f"Error in stdio bridge: {e}", file=sys.stderr)
    finally:
        if proc:
            try:
                proc.terminate()
                await asyncio.wait_for(proc.wait(), timeout=5.0)
            except asyncio.TimeoutError:
                proc.kill()
                await proc.wait()

async def main():
    port = int(os.environ.get('PORT', '47901'))

    # Start health check server in background thread
    health_thread = Thread(target=run_health_server, args=(port,), daemon=True)
    health_thread.start()

    # Start TCP server for MCP connections (on port + 1)
    mcp_port = port + 1
    server = await asyncio.start_server(handle_stdio_bridge, '0.0.0.0', mcp_port)

    addr = server.sockets[0].getsockname()
    print(f"FigCraft MCP Server listening on {addr}", file=sys.stderr)
    print(f"Connect via: nc {addr[0]} {addr[1]}", file=sys.stderr)

    async with server:
        await server.serve_forever()

if __name__ == '__main__':
    asyncio.run(main())
PYEOF

chmod +x /tmp/mcp-server.py

# Run the Python bridge server
exec python3 /tmp/mcp-server.py
