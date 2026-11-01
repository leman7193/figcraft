# FigCraft MCP Server - Render Deployment

Quick deployment guide for the FigCraft MCP server on Render.com.

## Quick Deploy

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/storytold/figcraft)

**Note**: The Blueprint (`render.yaml`) deploys both `figcraft-server` and `figcraft-mcp` together. If you already have `figcraft-server` running, this will add the MCP server alongside it.

## What Gets Deployed

- **Service**: FigCraft MCP Server (headless)
- **Persistent Disk**: 5 GB mounted at `/data`
- **Ports**: 
  - HTTP health checks on `$PORT` (assigned by Render)
  - MCP connections on `$PORT+1`
- **Plan**: Starter ($7/month) or higher

## Files

- `render.yaml` - Render Blueprint (includes both figcraft-server and figcraft-mcp)
- `packaging/mcp/Dockerfile.render` - Docker build instructions
- `packaging/mcp/run-render.sh` - Entrypoint script with TCP/stdio bridge
- `docs/deploy-mcp-render.md` - Full documentation

## Connection After Deploy

Your service will be available at: `https://figcraft-mcp-XXXXX.onrender.com`

### Connect from Claude Desktop

```json
{
  "mcpServers": {
    "figcraft": {
      "command": "nc",
      "args": ["figcraft-mcp-XXXXX.onrender.com", "10001"]
    }
  }
}
```

(Replace `XXXXX` with your service's unique ID, and `10001` with your actual MCP port)

### Get Your Connection Details

1. Go to your Render Dashboard
2. Click on the `figcraft-mcp` service
3. Note the URL (e.g., `figcraft-mcp-abc123.onrender.com`)
4. The MCP port is typically the health check port + 1

## Manual Deploy

If the Deploy button doesn't work:

1. Fork/clone the FigCraft repository
2. Go to [Render Dashboard](https://dashboard.render.com)
3. Click **New** → **Blueprint**
4. Select your repository
5. Render will detect `render.yaml`
6. Click **Apply**

**Note**: If you already have `figcraft-server` deployed from the same Blueprint, you can either:
- **Option A**: Re-apply the Blueprint to add the MCP service (Render will update existing services and add new ones)
- **Option B**: Add only the MCP service manually via "New → Web Service"

## Documentation

See `docs/deploy-mcp-render.md` for:
- Architecture details
- Configuration options
- Security considerations
- Troubleshooting

## Support

- Issues: [GitHub Issues](https://github.com/storytold/figcraft/issues)
- MCP Protocol: https://modelcontextprotocol.io
- Render Support: https://render.com/docs
