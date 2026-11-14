#!/bin/bash
set -euo pipefail

HOST="${DEPLOY_HOST:-43.142.103.106}"
PORT="${DEPLOY_PORT:-22022}"
KEY="${DEPLOY_KEY:-$HOME/.ssh/jizhang_sync}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE="$(mktemp /tmp/dosc.XXXXXX.tgz)"
trap 'rm -f "$ARCHIVE"' EXIT

tar -C "$ROOT" -czf "$ARCHIVE" index.html styles.css

scp -P "$PORT" -i "$KEY" -o BatchMode=yes "$ARCHIVE" "root@${HOST}:/tmp/dosc.tgz"
ssh -p "$PORT" -i "$KEY" -o BatchMode=yes "root@${HOST}" 'bash -s' << 'REMOTE'
set -euo pipefail
mkdir -p /opt/dosc
tar -xzf /tmp/dosc.tgz -C /opt/dosc
rm -f /tmp/dosc.tgz

cat > /etc/caddy/Caddyfile << 'EOF'
xiongtools.cn, www.xiongtools.cn {
    handle /v1/* {
        reverse_proxy 127.0.0.1:8787
    }
    handle {
        root * /opt/dosc
        file_server
        encode gzip
    }
}

bookkeeping.xiongtools.cn {
    handle /v1/* {
        reverse_proxy 127.0.0.1:8787
    }
    handle {
        respond "ok" 200
    }
}
EOF

caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
echo "deployed: https://xiongtools.cn/"
REMOTE
