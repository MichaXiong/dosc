#!/bin/bash
set -euo pipefail

HOST="${DEPLOY_HOST:-43.142.103.106}"
PORT="${DEPLOY_PORT:-22022}"
KEY="${DEPLOY_KEY:-$HOME/.ssh/jizhang_sync}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE="$(mktemp /tmp/dosc.XXXXXX.tgz)"
COPY_DIR="$(mktemp -d /tmp/dosc-src.XXXXXX)"
trap 'rm -rf "$COPY_DIR" "$ARCHIVE"' EXIT

# 只部署可浏览的文档站点，排除脚本与本机规则
rsync -a --exclude '.git' --exclude '.cursor' --exclude 'deploy.sh' \
  --exclude '_sync_topics.py' --exclude '_restyle_knowledge.py' \
  --exclude '.DS_Store' --exclude '._*' \
  "$ROOT/" "$COPY_DIR/"
COPYFILE_DISABLE=1 tar -C "$COPY_DIR" -czf "$ARCHIVE" .

scp -P "$PORT" -i "$KEY" -o BatchMode=yes "$ARCHIVE" "root@${HOST}:/tmp/dosc.tgz"
ssh -p "$PORT" -i "$KEY" -o BatchMode=yes "root@${HOST}" 'bash -s' << 'REMOTE'
set -euo pipefail
mkdir -p /opt/dosc
rm -rf /opt/dosc/*
tar -xzf /tmp/dosc.tgz -C /opt/dosc
rm -f /tmp/dosc.tgz
find /opt/dosc -name '._*' -delete

cat > /etc/caddy/Caddyfile << 'EOF'
# 未备案域名 80/443 会被腾讯拦截；用 IP:8888 访问文档
:8888 {
    root * /opt/dosc
    encode gzip
    file_server
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
        encode gzip
        file_server
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
echo "deployed: http://43.142.103.106:8888/"
REMOTE
