#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}"

echo "清理旧的 Nginx 进程..."
pkill -f "nginx: master process" || true

# 清除可能干扰 Nginx 的 LD_PRELOAD 和 LD_LIBRARY_PATH
unset LD_PRELOAD || true
unset LD_LIBRARY_PATH || true

echo "启动 Nginx (OpenResty)..."
# 使用 OpenResty 的 nginx 命令，并指定项目目录下的 nginx.conf
# 明确设置 LD_LIBRARY_PATH 以确保 Nginx 链接到 OpenResty 自己的 OpenSSL 库
LD_LIBRARY_PATH="/usr/local/openresty/openssl3/lib/" /usr/local/openresty/nginx/sbin/nginx -c "${PROJECT_ROOT}/nginx.conf" &
sleep 2

if ! pgrep -f "nginx: master process" > /dev/null; then
    echo "Error: Nginx failed to start." >&2
    echo "Please check Nginx logs (e.g., /usr/local/openresty/nginx/logs/error.log) for errors." >&2
    exit 1
fi
echo "Nginx started." 