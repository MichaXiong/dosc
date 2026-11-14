#!/bin/bash
# 文档站在 GitHub Pages：https://michaxiong.github.io/dosc/
# 这个脚本只把云服务器上的旧地址改成跳转，不再上传页面和图片。
set -euo pipefail

HOST="${DEPLOY_HOST:-43.142.103.106}"
PORT="${DEPLOY_PORT:-22022}"
KEY="${DEPLOY_KEY:-$HOME/.ssh/jizhang_sync}"

ssh -p "$PORT" -i "$KEY" -o BatchMode=yes "root@${HOST}" 'bash -s' << 'REMOTE'
set -euo pipefail
rm -rf /opt/dosc

cat > /etc/caddy/Caddyfile << 'EOF'
# 文档站已迁到 GitHub Pages，这里只跳转，不传图片
:8888 {
    redir https://michaxiong.github.io/dosc{uri} permanent
}

xiongtools.cn, www.xiongtools.cn {
    handle /v1/* {
        reverse_proxy 127.0.0.1:8787
    }
    handle {
        redir https://michaxiong.github.io/dosc{uri} permanent
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
echo "redirect: https://michaxiong.github.io/dosc/"
REMOTE
