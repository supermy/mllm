#!/bin/bash

# 测试 LLM /generate 接口，自动对齐 prompt 和生成内容
# IP 已设为 192.168.0.168
IP="192.168.0.168"
API_KEY="sk-test123456"

# 测试数据
read -r -d '' DATA <<EOF
{
  "prompts": [
    "你好，介绍一下你自己。",
    "列出 1 到 10 的所有质数。"
  ],
  "sampling_params": {
    "temperature": 0.7,
    "max_tokens": 64
  }
}
EOF

echo "== POST /generate =="
curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "$DATA" \
  https://$IP/generate | jq

# 依赖 jq 美化输出，如无 jq 可去掉 | jq
