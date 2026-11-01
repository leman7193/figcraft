# Deploying FigCraft MCP Server to Render

This guide explains how to deploy the FigCraft MCP (Model Context Protocol) server to Render.com.

## What is the FigCraft MCP Server?

The FigCraft MCP server (`figcraft-cli mcp`) allows AI agents to design with FigCraft programmatically:
- Create and edit layers
- Run any menu command
- Inspect the result as JSON
- Generate PNG screenshots

It speaks newline-delimited JSON-RPC 2.0 over stdio according to the MCP protocol.

## Deployment Architecture

The Render deployment uses:
1. **Docker container** with `figcraft-cli` built from source
2. **Python bridge** to provide HTTP health checks and TCP-to-stdio bridging
3. **Persistent disk** (5 GB) mounted at `/data` for file storage
4. **Combined Blueprint** with `figcraft-server` (both in `render.yaml`)

**Blueprint Structure**:
- `render.yaml` contains both services:
  - `figcraft-server`: File hosting and collaboration (1 GB disk)
  - `figcraft-mcp`: AI agent access (5 GB disk)
- Each service runs independently
- Both share the same repository and build cache

## Prerequisites

- A GitHub account linked to Render
- A Render account (free tier works for testing, Starter+ recommended for production)
- Your FigCraft repository pushed to GitHub

## Deployment Steps

### Option 1: Deploy via Render Blueprint (Recommended)

**Note**: If you already deployed `figcraft-server` from `render.yaml`, the Blueprint will add the MCP service alongside it without affecting your existing server.

1. Push your repository to GitHub if you haven't already
2. Go to your Render Dashboard: https://dashboard.render.com
3. Click **New** → **Blueprint**
4. Connect your GitHub repository
5. Select the repository containing FigCraft
6. Render will detect `render.yaml` and show both services:
   - `figcraft-server` (if not already deployed)
   - `figcraft-mcp` (new)
7. Click **Apply** to deploy

The first deployment will take 10-15 minutes as it compiles from source. Subsequent deploys reuse the cached build.

**If you already have figcraft-server running**: Re-applying the Blueprint will skip the existing server and only add the MCP service.

### Option 2: Deploy Manually

1. Go to Render Dashboard: https://dashboard.render.com
2. Click **New** → **Web Service**
3. Connect your GitHub repository
4. Configure:
   - **Name**: `figcraft-mcp`
   - **Runtime**: Docker
   - **Dockerfile Path**: `./packaging/mcp/Dockerfile.render`
   - **Docker Context**: `.`
   - **Plan**: Starter or higher
   - **Health Check Path**: `/`
5. Add environment variables:
   - `RUST_LOG=info`
   - `FIGCRAFT_NO_SYSTEM_FONTS=0` (or `1` to disable system fonts for reproducible CI)
6. Click **Create Web Service**

## Configuration

### Environment Variables

- **`PORT`**: Auto-injected by Render (default: 47901)
- **`RUST_LOG`**: Log level (`info`, `debug`, `warn`, `error`)
- **`FIGCRAFT_NO_SYSTEM_FONTS`**: Set to `1` to use only built-in fonts (for reproducible renders)

### Filesystem Access Confinement

For security, you can confine the MCP server's file access:

```bash
figcraft-cli mcp \
  --automation-read-root /work/project \
  --automation-write-root /work/project/out
```

These flags ensure:
- Files read must be inside a read root or write root
- Files written must be inside a write root
- Invalid paths are rejected with clear error messages

To enable this in your Render deployment, modify `packaging/mcp/run-render.sh`:

```bash
exec socat TCP-LISTEN:"$LISTEN_PORT",reuseaddr,fork \
    EXEC:"/usr/local/bin/figcraft-cli mcp --automation-read-root /data --automation-write-root /data",pty,stderr
```

### System Fonts

By default, the MCP server uses system fonts plus FigCraft's built-in fonts. For CI/CD or reproducible renders, set `FIGCRAFT_NO_SYSTEM_FONTS=1` to use only built-in fonts.

## Connecting to the Deployed MCP Server

Once deployed, Render provides a URL like: `https://figcraft-mcp.onrender.com`

### From Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "figcraft-remote": {
      "command": "nc",
      "args": ["figcraft-mcp.onrender.com", "443"]
    }
  }
}
```

### From Claude Code CLI

```bash
# For remote TCP connection
claude mcp add figcraft-remote -- nc figcraft-mcp.onrender.com 443
```

### Testing the Connection

Use netcat to test:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | nc figcraft-mcp.onrender.com 443
```

You should receive an initialization response.

## Monitoring

### Health Checks

Render will monitor the service via the health check path `/`. The socat bridge responds to basic TCP connections.

### Logs

View logs in the Render Dashboard:
1. Go to your service
2. Click **Logs** tab
3. Filter by `RUST_LOG` level

### Resource Usage

The MCP server runs headless with a CPU renderer:
- Memory: ~50-200MB per connection
- CPU: Varies with rendering workload
- Disk: Minimal (unless using persistent storage)

## Persistent Storage (Optional)

The MCP service includes a 5 GB persistent disk mounted at `/data`:

```yaml
disk:
  name: figcraft-mcp-data
  mountPath: /data
  sizeGB: 5
```

This is useful for:
- Saving design files between sessions
- Caching rendered assets
- Storing plugin data

To use it, configure automation roots to point to `/data`:

Edit `packaging/mcp/run-render.sh` to add:
```bash
exec python3 /tmp/mcp-server.py --automation-write-root /data
```

## Troubleshooting

### Build Failures

- **Error**: "Compilation failed"
  - **Fix**: Check Rust version in `Dockerfile.render` matches workspace requirements
  - **Fix**: Ensure all dependencies are available in Debian Bookworm

### Connection Issues

- **Error**: "Connection refused"
  - **Fix**: Check that the service is running in Render Dashboard
  - **Fix**: Verify the PORT environment variable is set correctly
  - **Fix**: Check firewall/security group settings

### Runtime Errors

- **Error**: "Out of memory"
  - **Fix**: Upgrade to a larger Render plan
  - **Fix**: Reduce concurrent connections

- **Error**: "Missing fonts"
  - **Fix**: Set `FIGCRAFT_NO_SYSTEM_FONTS=1` to use only built-in fonts
  - **Fix**: Add font packages to `Dockerfile.render` if needed

## Limitations

1. **Stdio over TCP**: The deployment bridges TCP to stdio, which may have latency overhead
2. **Headless only**: No GUI; uses CPU renderer only
3. **No attachment mode**: Cannot use `--attach` to drive a running FigCraft app
4. **Concurrent connections**: Each connection spawns a new process (resource intensive)

## Cost Estimates

- **Starter Plan**: $7/month
  - 512 MB RAM
  - 0.5 CPU
  - Persistent disk included
  
- **Standard Plan**: $25/month
  - 2 GB RAM
  - 1 CPU
  - Better for multiple concurrent connections

## Alternative: Using SSH Tunnel

For lower latency and secure connections, you can deploy on a traditional VPS and use SSH tunneling:

```bash
# On the server
figcraft-cli mcp

# On the client
ssh -L 47901:localhost:47901 user@your-server.com
claude mcp add figcraft -- nc localhost 47901
```

## Security Considerations

1. **Access Control**: The deployed MCP server accepts any TCP connection
   - Consider adding authentication middleware
   - Use Render's IP allowlisting if available
   
2. **File Access**: Use `--automation-read-root` and `--automation-write-root` to confine file operations

3. **Rate Limiting**: Implement rate limiting to prevent abuse

4. **Secrets**: Never hardcode secrets in the repository
   - Use Render's environment variables for sensitive data

## Next Steps

- Read the full MCP documentation: `docs/mcp.md`
- Explore MCP tools and commands: `figcraft-cli mcp --help`
- Review the control protocol: `docs/control-protocol.md`

## Support

For issues specific to:
- **FigCraft**: Open an issue on the FigCraft repository
- **Render deployment**: Check Render's documentation and support
- **MCP protocol**: See https://modelcontextprotocol.io

---

Last updated: 2026-11-01
