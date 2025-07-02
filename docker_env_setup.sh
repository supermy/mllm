#!/bin/bash
# Docker 容器内一键环境准备脚本
# 适用于 nvcr.io/nvidia/pytorch:25.05-py3 镜像
set -e

echo "==== Docker 容器内 AI 平台环境准备 ===="

# 1. 配置 pip 源
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn

# 2. 安装系统依赖
apt-get update
apt-get install -y --no-install-recommends wget gnupg ca-certificates lsb-release jq

# 3. 安装 OpenResty
wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -
echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list
apt-get update
apt-get install -y openresty

# 4. 安装 Lua HTTP 库
/usr/local/openresty/bin/opm get ledgetech/lua-resty-http

# 5. Python 依赖
pip install --upgrade pip
pip install -r requirements.txt

# 6. uWSGI（如未在 requirements.txt 中）
pip install uwsgi

# 7. CUDA 环境检查
python3 -c "import torch; print('CUDA available:', torch.cuda.is_available())"

# 8. 提示模型目录
MODEL_PATH="../models/Qwen3-0.6B/"
echo "请确保模型目录存在: ${MODEL_PATH}"

# 9. 结束
cat <<EOF

==== 环境准备完成 ====
如需启动服务，请运行:
    ./start_ubuntu.sh
如需配置 HTTPS 证书:
    sudo ./setup_ssl.sh <your-ip>
如需测试:
    python3 test_api.py
    bash test_generate.sh
EOF
