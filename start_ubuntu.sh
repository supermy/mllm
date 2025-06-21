#!/bin/bash

set -e

echo "==== 启动 AI 平台微服务（Ubuntu 原生环境） ===="

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}"

# 定义 PID 文件路径
LLM_SERVICE_PID_FILE="llm_service.pid"
# APP_GATEWAY_PID_FILE="app_gateway.pid" # 移除 API 网关 PID 文件定义

# --- 1. 启动 LLM 推理服务 (llm_service.py) ---
echo "清理旧的 LLM 服务进程..."
if [ -f "${LLM_SERVICE_PID_FILE}" ]; then
    kill $(cat "${LLM_SERVICE_PID_FILE}") || true
    rm -f "${LLM_SERVICE_PID_FILE}"
fi

echo "显式设置 LD_PRELOAD 和 LD_LIBRARY_PATH for LLM service..."
export LD_PRELOAD=""
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

echo "启动 LLM 推理服务 (llm_service.py) 在 5002 端口..."
nohup python3 llm_service.py > llm_service.log 2>&1 &
echo $! > "${LLM_SERVICE_PID_FILE}"
sleep 5 # 等待 LLM 服务启动和模型加载

if ! ps -p $(cat "${LLM_SERVICE_PID_FILE}") > /dev/null; then
    echo "LLM 服务启动失败，请检查 llm_service.log 文件。" >&2
    exit 1
fi
echo "LLM 服务 (PID: $(cat "${LLM_SERVICE_PID_FILE}")) 已启动，监听端口 5002。"


# --- 2. 启动 Nginx (OpenResty) ---
sh start_nginx.sh # 调用单独的 Nginx 启动脚本


echo "==== 服务已启动 ===="
echo "LLM 服务日志: llm_service.log"
echo "Nginx 日志通常在 /usr/local/openresty/nginx/logs/ 或根据您的 Nginx 配置。"
echo ""
echo "-------------------------------------------------------------------"
echo "AI Platform microservices are now running on Ubuntu!"
echo "LLM Service (PID: $(cat "${LLM_SERVICE_PID_FILE}")) is on port 5002."
echo "Nginx (OpenResty) is running and serving the application on port 80, handling API Gateway logic via Lua."
echo "You can test the API using: curl http://localhost:80/health"
echo "And for generation: curl -X POST -H \"Content-Type: application/json\" -d '{\"prompts\": [\"Hello, how are you?\"], \"sampling_params\": {\"max_tokens\": 50}}' http://localhost:80/generate"
echo "To stop the services, run: ./stop_ubuntu.sh"
echo "-------------------------------------------------------------------
" 