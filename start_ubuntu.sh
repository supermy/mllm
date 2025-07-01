#!/bin/bash

set -e

echo "==== 启动 AI 平台微服务（Ubuntu 原生环境） ===="

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}"

# 检查 SSL 证书
if [ ! -f "/etc/ssl/certs/nginx-selfsigned.crt" ] || [ ! -f "/etc/ssl/private/nginx-selfsigned.key" ]; then
    echo "SSL 证书未找到，正在配置..."
    sudo ./setup_ssl.sh
fi

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
echo "Nginx (OpenResty) is running and serving:"
echo "- HTTP on port 80 (redirects to HTTPS)"
echo "- HTTPS on port 443"
echo ""
echo "You can test the API using:"
echo "curl -k https://localhost/health"
echo "curl -k -X POST -H \"Content-Type: application/json\" -d '{\"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}' https://localhost/v1/chat/completions"
echo ""
echo "Note: -k flag is used to skip SSL certificate verification for self-signed certificates"
echo "To stop the services, run: ./stop_ubuntu.sh"
echo "-------------------------------------------------------------------"