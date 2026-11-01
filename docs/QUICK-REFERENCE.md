# FigCraft MCP Server - Quick Reference Card

## 🚀 Deploy to Render

### Via Blueprint (Easiest)
```bash
# 1. Push to GitHub
git push origin main

# 2. Open Render Dashboard
https://dashboard.render.com

# 3. New → Blueprint → Select Repo → Apply
```

### Via Web UI
```
Dashboard → New → Web Service
Runtime: Docker
Dockerfile: ./packaging/mcp/Dockerfile.render
Plan: Starter
Health Check: /healthz
```

## 📍 Service URLs

After deployment, Render provides:
- **Service URL**: `https://figcraft-mcp-XXXXX.onrender.com`
- **Health Check**: `https://figcraft-mcp-XXXXX.onrender.com/healthz`
- **MCP TCP Port**: Extract from logs or use default pattern

## 🔌 Connect from Claude

### Claude Desktop
```json
{
  "mcpServers": {
    "figcraft": {
      "command": "nc",
      "args": ["figcraft-mcp-XXXXX.onrender.com", "PORT"]
    }
  }
}
```

### Claude Code
```bash
claude mcp add figcraft -- nc figcraft-mcp-XXXXX.onrender.com PORT
```

## 🧪 Test Connection

### Quick Test (Shell)
```bash
./packaging/mcp/test-mcp-simple.sh HOST PORT
```

### Python Test
```bash
python3 packaging/mcp/test-mcp-connection.py HOST PORT
```

### Manual Test (netcat)
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | nc HOST PORT
```

## 📊 Port Reference

| Port | Purpose |
|------|---------|
| `$PORT` (e.g., 10000) | HTTP health checks (Render) |
| `$PORT+1` (e.g., 10001) | MCP TCP connections (clients) |

## ⚙️ Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | (Render injects) | Health check port |
| `RUST_LOG` | `info` | Log level |
| `FIGCRAFT_NO_SYSTEM_FONTS` | `0` | Use only built-in fonts |
| `DEBUG` | `0` | Verbose logging |

## 📁 File Locations

```
figcraft/
├── render-mcp.yaml                      # Render Blueprint
├── packaging/mcp/
│   ├── Dockerfile.render                # Build config
│   ├── run-render.sh                    # Entrypoint
│   ├── README.md                        # Quick start
│   ├── test-mcp-connection.py          # Test (Python)
│   └── test-mcp-simple.sh              # Test (Shell)
└── docs/
    ├── deploy-mcp-render.md            # Full guide
    └── DEPLOYMENT-SUMMARY.md           # Tech details
```

## 🐛 Troubleshooting

### Check Service Status
```
Render Dashboard → Service → Status
```

### View Logs
```
Render Dashboard → Service → Logs
```

### Common Issues

**Build fails**
- Check Rust version in Dockerfile
- Check dependencies available

**Health checks fail**
- Verify Python script syntax
- Check port binding (0.0.0.0)

**Can't connect**
- Confirm service is running
- Check correct port (health + 1)
- Test with netcat first

**Out of memory**
- Upgrade to Standard plan
- Reduce concurrent connections

## 💰 Pricing

| Plan | Cost | RAM | CPU | Use Case |
|------|------|-----|-----|----------|
| Starter | $7/mo | 512 MB | 0.5 | Testing, 1-2 users |
| Standard | $25/mo | 2 GB | 1.0 | Production, 5-10 users |

## 🔒 Security Checklist

- [ ] Add authentication (API keys)
- [ ] Add TLS (nginx reverse proxy)
- [ ] Add rate limiting
- [ ] Configure automation roots
- [ ] Set up monitoring
- [ ] Review access logs

## 📚 Documentation Links

- **Full Deployment**: `docs/deploy-mcp-render.md`
- **MCP Protocol**: `docs/mcp.md`
- **Control Protocol**: `docs/control-protocol.md`
- **This Card**: Quick reference

## 🎯 Common Commands

### Check Service Health
```bash
curl https://figcraft-mcp-XXXXX.onrender.com/healthz
```

### Test MCP Initialization
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | nc HOST PORT
```

### Check Service Logs (via Render CLI)
```bash
render logs figcraft-mcp
```

## 🚨 Emergency Commands

### Restart Service
```
Render Dashboard → Service → Manual Deploy → Deploy latest commit
```

### Rollback
```
Render Dashboard → Service → Events → Revert to <previous deploy>
```

### Scale Up
```
Render Dashboard → Service → Settings → Plan → Upgrade
```

## ✅ Pre-Deploy Checklist

- [ ] All files committed
- [ ] GitHub repository is up to date
- [ ] Render account is linked to GitHub
- [ ] You have billing configured (for Starter+ plans)
- [ ] You've reviewed security considerations

## 📞 Support

- **FigCraft**: https://github.com/storytold/figcraft/issues
- **Render**: https://render.com/docs
- **MCP**: https://modelcontextprotocol.io

---

💡 **Tip**: Bookmark this page for quick reference during deployment and troubleshooting.

Last updated: 2026-11-01
