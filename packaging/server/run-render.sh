#!/bin/sh
# Render entrypoint for figcraft-server (see packaging/server/Dockerfile.render).
# Render injects $PORT (the port to listen on) and $RENDER_EXTERNAL_URL
# (the service's https:// address, used for share links). Files live in /data,
# which must be a persistent disk on Render.
set -eu

LISTEN="0.0.0.0:${PORT:-47900}"

if [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
    # Share links speak WebSocket: https://host -> wss://host/ (trailing slash).
    WSS="$(printf '%s' "$RENDER_EXTERNAL_URL" | sed 's|^https:|wss:|; s|/*$|/|')"
    exec /usr/local/bin/figcraft-server --listen "$LISTEN" --data /data --public-url "$WSS"
else
    exec /usr/local/bin/figcraft-server --listen "$LISTEN" --data /data
fi
