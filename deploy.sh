#!/bin/bash
set -euo pipefail

HOST="${DEPLOY_HOST:-43.142.103.106}"
PORT="${DEPLOY_PORT:-22022}"
KEY="${DEPLOY_KEY:-$HOME/.ssh/jizhang_sync}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE="$(mktemp /tmp/dosc.XXXXXX.tgz)"
COPY_DIR="$(mktemp -d /tmp/dosc-src.XXXXXX)"
trap 'rm -rf "$COPY_DIR" "$ARCHIVE"' EXIT

cp "$ROOT/index.html" "$ROOT/styles.css" "$COPY_DIR/"
COPYFILE_DISABLE=1 tar -C "$COPY_DIR" -czf "$ARCHIVE" index.html styles.css

scp -P "$PORT" -i "$KEY" -o BatchMode=yes "$ARCHIVE" "root@${HOST}:/tmp/dosc.tgz"
ssh -p "$PORT" -i "$KEY" -o BatchMode=yes "root@${HOST}" 'bash -s' << 'REMOTE'
set -euo pipefail
mkdir -p /opt/dosc
tar -xzf /tmp/dosc.tgz -C /opt/dosc
rm -f /tmp/dosc.tgz /opt/dosc/._*

cat > /etc/caddy/Caddyfile << 'EOF'
# 未备案域名 80/443 会被腾讯拦截；用 IP:8888 给手机/电脑浏览器访问
:8888 {
    root * /opt/dosc
    file_server
    encode gzip
    header {
        Cache-Control "no-cache"
    }
}

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
ss -tlnp | grep ':8888' || true
echo "deployed: http://43.142.103.106:8888/"
REMOTE
