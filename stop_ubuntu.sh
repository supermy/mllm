#!/bin/bash

echo "==== 停止 AI 平台微服务（Ubuntu 原生环境） ===="

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}"

# 定义 PID 文件路径 (尽管现在主要依靠 pkill，但保留以防万一)
LLM_SERVICE_PID_FILE="llm_service.pid"
# APP_GATEWAY_PID_FILE="app_gateway.pid" # 移除 API 网关 PID 文件定义

# --- 1. 停止 LLM 推理服务 ---
echo "尝试停止 LLM 推理服务..."
pkill -f "python3 llm_service.py" || true

# 清理 PID 文件
if [ -f "${LLM_SERVICE_PID_FILE}" ]; then
    rm -f "${LLM_SERVICE_PID_FILE}"
fi

sleep 1 # 给进程一些时间终止

if pgrep -f "python3 llm_service.py" > /dev/null; then
    echo "LLM 推理服务未能完全停止，可能需要手动终止。" >&2
else
    echo "LLM 推理服务已停止。"
fi

# --- 2. 停止 Nginx ---
sh stop_nginx.sh # 调用单独的 Nginx 停止脚本

echo "==== 所有服务停止尝试已完成 ====" 