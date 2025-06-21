#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}"

echo "尝试强制停止 Nginx..."
pkill -9 -f "nginx: master process" || true # 强制杀死所有 nginx 进程
pkill -9 -f "nginx: worker process" || true # 强制杀死所有 nginx 进程
sleep 1 # 给进程一些时间终止

if pgrep -f "nginx: master process" > /dev/null; then
    echo "Nginx 未能完全停止，可能需要手动终止。" >&2
else
    echo "Nginx 已停止。"
fi 