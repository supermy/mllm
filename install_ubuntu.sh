#!/bin/bash

set -e

echo "==== 一键安装 AI 平台依赖（Ubuntu，Docker 容器环境） ===="

# 0. 设置 pip 源
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn

# 1. 安装系统依赖 (包括 lsb-release 和 OpenResty)
echo "安装系统依赖..."
apt-get update
apt-get install -y --no-install-recommends wget gnupg ca-certificates lsb-release

# 添加 OpenResty 仓库 GPG 密钥
wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -

# 添加 OpenResty APT 仓库
echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" \
    | tee /etc/apt/sources.list.d/openresty.list

# 更新 APT 缓存并安装 OpenResty
apt-get update
apt-get install -y openresty

# 2. 安装 Python 依赖
pip install --upgrade pip
pip install -r requirements.txt
# pip install uwsgi # 移除 uwsgi 安装

# 3. 提示模型目录
MODEL_PATH="../models/Qwen3-0.6B/"
echo "请确保模型目录存在: ${MODEL_PATH}"

# 4. 启动服务提示
cat <<EOF

依赖安装完成！

接下来，您需要：
1. 配置 Nginx 以使用 Lua 脚本作为 API 网关 (请参考 nginx.conf)
2. 运行 ./start_ubuntu.sh 来启动 LLM 服务和 Nginx。
3. 使用 curl http://localhost:80/health 和 curl -X POST ... http://localhost:80/generate 来测试 API。

EOF 