# FigCraft MCP Server - Render Deployment Summary

This document summarizes the Render deployment setup for the FigCraft MCP server.

## What Was Created

### 1. Docker Configuration
- **`packaging/mcp/Dockerfile.render`** - Multi-stage Docker build
  - Stage 1: Builds `figcraft-cli` from source using Rust 1 (Bookworm)
  - Stage 2: Runtime container with Python 3 for the bridge server
  - Installs minimal dependencies (ca-certificates, python3)

### 2. Entrypoint Script
- **`packaging/mcp/run-render.sh`** - Python-based bridge server
  - HTTP health check endpoint (responds on `$PORT`)
  - TCP server for MCP connections (on `$PORT + 1`)
  - Bridges TCP connections to `figcraft-cli mcp` stdio sessions
  - Each connection spawns a new `figcraft-cli mcp` process

### 3. Render Blueprint
- **`render-mcp.yaml`** - Declarative Render configuration
  - Service type: Web Service
  - Runtime: Docker
  - Plan: Starter (minimum for production)
  - Health check: `/healthz`
  - Environment variables configurable

### 4. Documentation
- **`docs/deploy-mcp-render.md`** - Full deployment guide
  - Architecture explanation
  - Step-by-step deployment instructions
  - Configuration options
  - Security considerations
  - Troubleshooting
  
- **`packaging/mcp/README.md`** - Quick start guide
  - One-click deploy button
  - Quick connection instructions
  - Links to full docs

### 5. Test Scripts
- **`packaging/mcp/test-mcp-connection.py`** - Python test client
  - Tests TCP connection
  - Sends MCP initialize request
  - Validates JSON-RPC response

- **`packaging/mcp/test-mcp-simple.sh`** - Shell test script
  - Minimal dependencies (bash, nc/netcat)
  - Quick connection test
  - MCP protocol validation

## Deployment Flow

### Initial Deploy
1. User clicks "Deploy to Render" or uses Blueprint
2. Render builds Docker image (10-15 minutes first time)
3. Service starts with health checks
4. Two ports are exposed:
   - `$PORT` (e.g., 10000): HTTP health checks
   - `$PORT + 1` (e.g., 10001): MCP TCP connections

### Ongoing Operation
- Render monitors via HTTP health checks on `$PORT`
- Clients connect to TCP port `$PORT + 1`
- Each TCP connection gets a dedicated `figcraft-cli mcp` process
- Process lifecycle: connection open → spawn → work → connection close → cleanup

## Architecture

```
┌─────────────────┐
│  Render Cloud   │
│                 │
│  ┌───────────┐  │
│  │  Docker   │  │
│  │ Container │  │
│  │           │  │
│  │ Python    │  │       HTTP Health Checks
│  │ Bridge ───┼──┼──────► Render (port 10000)
│  │ Server    │  │
│  │     │     │  │
│  │     └─────┼──┼──────► TCP Connections (port 10001)
│  │           │  │              │
│  │    spawns │  │              │
│  │     ↓     │  │              ↓
│  │ figcraft- │  │         ┌─────────┐
│  │ cli mcp   │  │         │ Clients │
│  │  (stdio)  │  │         │ (Claude │
│  └───────────┘  │         │ Desktop)│
│                 │         └─────────┘
└─────────────────┘
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | 47901 | Injected by Render; HTTP health check port |
| `RUST_LOG` | info | Logging level for figcraft-cli |
| `FIGCRAFT_NO_SYSTEM_FONTS` | 0 | Set to 1 to use only built-in fonts |
| `DEBUG` | 0 | Set to 1 for verbose bridge logs |

## Resource Requirements

### Minimum (Testing)
- **Plan**: Starter ($7/month)
- **Memory**: 512 MB
- **CPU**: 0.5 CPU
- **Disk**: No persistent disk required

### Recommended (Production)
- **Plan**: Standard ($25/month)
- **Memory**: 2 GB
- **CPU**: 1 CPU
- **Disk**: Optional 1-10 GB for file storage
- **Reason**: Better for multiple concurrent connections

## Security Considerations

### Current Implementation
- ✓ Headless operation (no GUI attack surface)
- ✓ CPU renderer only (no GPU drivers)
- ✓ Health checks on separate port
- ✗ No authentication on MCP port
- ✗ No TLS/encryption (TCP plaintext)
- ✗ No rate limiting

### Recommended Improvements
1. **Add authentication**: Require API keys in MCP messages
2. **Use TLS**: Wrap in nginx with SSL certificates
3. **Rate limiting**: Limit connections per IP
4. **IP allowlisting**: Restrict to known clients
5. **File confinement**: Add `--automation-read-root` and `--automation-write-root`

## Connection Examples

### From Claude Desktop
Edit `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "figcraft-remote": {
      "command": "nc",
      "args": ["figcraft-mcp-XXXXX.onrender.com", "10001"]
    }
  }
}
```

### From Claude Code CLI
```bash
claude mcp add figcraft-remote -- nc figcraft-mcp-XXXXX.onrender.com 10001
```

### Test Connection
```bash
# Simple test
./packaging/mcp/test-mcp-simple.sh figcraft-mcp-XXXXX.onrender.com 10001

# Python test
python3 packaging/mcp/test-mcp-connection.py figcraft-mcp-XXXXX.onrender.com 10001

# Manual netcat test
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | nc figcraft-mcp-XXXXX.onrender.com 10001
```

## Troubleshooting

### Build Issues
- **Symptom**: Build fails during Rust compilation
- **Solution**: Check Rust version, dependencies in Dockerfile
- **Logs**: Render Dashboard → Service → Logs → Build

### Runtime Issues
- **Symptom**: Health checks failing
- **Solution**: Check Python script syntax, port bindings
- **Logs**: Render Dashboard → Service → Logs → Deploy

### Connection Issues
- **Symptom**: Cannot connect from client
- **Solution**: 
  1. Verify service is running (Render Dashboard)
  2. Check correct port (health check port + 1)
  3. Test with netcat first
  4. Verify no firewall blocking

### Performance Issues
- **Symptom**: Slow responses, timeouts
- **Solution**:
  1. Upgrade to larger Render plan
  2. Check concurrent connection count
  3. Monitor memory/CPU usage
  4. Consider horizontal scaling

## Next Steps

### To Deploy
1. Commit these files to your repository
2. Push to GitHub
3. Go to Render Dashboard
4. Click "New" → "Blueprint"
5. Select your repository
6. Click "Apply"

### To Test
1. Wait for deployment to complete
2. Note your service URL from Render
3. Run test script with your URL and port
4. Configure Claude Desktop/Code
5. Try creating a design with Claude

### To Improve
1. Add authentication middleware
2. Set up nginx reverse proxy with TLS
3. Configure rate limiting
4. Add monitoring/metrics
5. Set up backup/recovery for persistent files

## Files Created

```
figcraft/
├── render-mcp.yaml                      # Render Blueprint
├── packaging/mcp/
│   ├── Dockerfile.render                # Docker build
│   ├── run-render.sh                    # Entrypoint with bridge
│   ├── README.md                        # Quick start
│   ├── test-mcp-connection.py           # Python test client
│   └── test-mcp-simple.sh               # Shell test script
└── docs/
    └── deploy-mcp-render.md             # Full documentation
```

## Support

- **FigCraft Issues**: https://github.com/storytold/figcraft/issues
- **MCP Protocol**: https://modelcontextprotocol.io
- **Render Docs**: https://render.com/docs
- **This Summary**: For internal team reference

---

Created: 2026-11-01
Last Updated: 2026-11-01
