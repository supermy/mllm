# AI 平台微服务

这是一个基于 `nano-vllm`、Flask、uWSGI 和 Nginx 构建的 AI 平台微服务。

## 项目概述

本项目旨在提供一个轻量级、高性能的 LLM (Large Language Model) 推理服务。
- **LLM 服务**: 使用 `nano-vllm` 提供文本生成能力，通过 Flask 暴露 RESTful API。
- **uWSGI**: 作为应用服务器，用于部署 Flask 应用。
- **Nginx (OpenResty)**: 作为反向代理和 API 网关，处理外部请求并将其转发到 uWSGI，同时可以集成 Lua 脚本进行高级路由和逻辑处理。

## 文件说明

- `api_gateway.lua`: Nginx OpenResty 的 Lua 脚本，用于实现 API 网关逻辑，例如请求路由、验证等。
- `app.ini`: uWSGI 配置文件，定义了如何运行 Flask 应用。
- `llm_service.py`: 核心 LLM 推理服务，基于 Flask 构建，提供 `/health` 和 `/generate` API 端点。
- `nginx.conf`: Nginx 配置文件，作为反向代理，将请求转发到后端服务。
- `requirements.txt`: Python 依赖列表。
- `start_ubuntu.sh`: 用于在 Ubuntu 环境下启动所有服务的脚本 (LLM 服务和 Nginx)。
- `stop_ubuntu.sh`: 用于在 Ubuntu 环境下停止所有服务的脚本。
- `start_nginx.sh`: 独立启动 Nginx 服务的脚本。
- `stop_nginx.sh`: 独立停止 Nginx 服务的脚本。
- `test_api.py`: 用于测试 API 端点的 Python 脚本。
- `idea.md`: 初始项目需求和想法。
- `setup_ssl.sh`: 一键生成/配置 SSL 证书，支持内网 IP
- `docker_env_setup.sh`：一键配置容器环境脚本

## 设置与运行

### 1. 模型准备

在运行服务之前，您需要准备 LLM 模型。
本项目默认使用的模型路径是 `/ai/mllm/models/Qwen3-0.6B/`。
请确保将您的模型文件放置在该路径下，或者根据您的实际模型路径修改 `llm_service.py` 和 `app.ini` 中的 `MODEL_PATH` 配置。

### 2. 本地运行 (Ubuntu 原生环境)

确保您的 Ubuntu 系统满足以下要求：
- Python 3.9+
- pip
- Nginx (OpenResty)
- uWSGI
- CUDA (如果使用 GPU)

**安装依赖**:

```bash
# 安装 OpenResty (Nginx with LuaJIT)
# 参考 OpenResty 官方文档进行安装：https://openresty.org/cn/linux-packages.html
# 例如 (Ubuntu):
# sudo apt-get update
# sudo apt-get install -y --no-install-recommends wget gnupg ca-certificates
# wget -O - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
# echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" \
#     | sudo tee /etc/apt/sources.list.d/openresty.list
# sudo apt-get update
# sudo apt-get install openresty

# 安装 uWSGI
pip install uwsgi

# 创建 Python 虚拟环境并安装依赖
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
# 如果需要，手动安装 flash-attn (根据您的 CUDA 版本和需求)
# pip install flash-attn --no-build-isolation
```

**启动服务**:

```bash
sh start_ubuntu.sh
```

**停止服务**:

```bash
sh stop_ubuntu.sh
```

### 3. API 使用

服务启动后，您可以通过 `curl` 或 `test_api.py` 进行测试。

**健康检查**:

```bash
curl http://localhost:80/health
```

**OpenAI 兼容接口（推荐）**:

- 端点：`/v1/chat/completions`
- 请求格式：兼容 OpenAI 官方 API

请求示例：

```bash
curl -X POST -H "Content-Type: application/json" \
    -d '{
        "messages": [
            {"role": "system", "content": "你是一个有帮助的助手。"},
            {"role": "user", "content": "你好！"}
        ],
        "temperature": 0.7,
        "max_tokens": 100
    }' \
    http://localhost:80/v1/chat/completions
```

响应示例：

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1719830000,
  "model": "local-model",
  "usage": {
    "prompt_tokens": -1,
    "completion_tokens": -1,
    "total_tokens": -1
  },
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "你好！有什么可以帮您？"
      },
      "finish_reason": "stop",
      "index": 0
    }
  ]
}
```

**兼容旧版 /generate 接口**:

```bash
curl -X POST -H "Content-Type: application/json" -d '{"prompts": ["Hello, how are you?"], "sampling_params": {"max_tokens": 50}}' http://localhost:80/generate
```

### 4. HTTPS/SSL 支持

平台支持一键生成自签名 SSL 证书，支持本地和内网 IP，自动配置 Nginx HTTPS。

**生成证书并配置 Nginx（支持内网 IP）：**

```bash
sudo ./setup_ssl.sh 192.168.0.168   # 也可用域名或 localhost
```

- 证书路径：/etc/ssl/certs/nginx-selfsigned.crt
- 私钥路径：/etc/ssl/private/nginx-selfsigned.key
- 自动生成 Nginx ssl.conf 并在 nginx.conf 中引用
- HTTP 自动跳转到 HTTPS，支持 HTTP/2

**启动服务（自动检测证书）：**

```bash
./start_ubuntu.sh
```

**测试 HTTPS 接口（自签名证书用 -k 跳过校验）：**

```bash
curl -k https://192.168.0.168/health
curl -k -X POST -H "Content-Type: application/json" -d '{"messages":[{"role":"user","content":"你好"}]}' https://192.168.0.168/v1/chat/completions
```

**Python 测试脚本也已支持 HTTPS，自签名证书自动跳过校验。**

## API 认证

服务使用 AppKey 进行认证和访问控制：

1. 在请求头中添加 AppKey：
```bash
curl -H "Authorization: Bearer YOUR-API-KEY" ...
# 或
curl -H "Authorization: YOUR-API-KEY" ...
```

2. AppKey 配置在 `conf/appkeys.lua`：
```lua
_M.keys = {
    ["sk-test123456"] = { name = "测试应用", qps = 10 },
    -- 添加更多 AppKey
}
```

特点：
- 支持每个 AppKey 独立的 QPS 限制
- 健康检查接口 `/health` 无需认证
- 支持 OpenAI 风格的 Bearer Token
- 可选 Redis 分布式限流支持

## 注意事项

- `llm_service.log` 文件将包含 LLM 服务的日志输出，用于调试。
- Nginx 的日志通常位于 `/usr/local/openresty/nginx/logs/` 或根据您的 Nginx 配置。
- 如果遇到 `Model not loaded` 错误，请检查 `llm_service.log` 中的详细错误信息。这通常与模型路径、CUDA 环境或 `nano-vllm` 的依赖有关。
- 如果遇到 `415 Unsupported Media Type` 错误，请确保您的请求头 `Content-Type` 正确设置为 `application/json`。如果问题持续，请检查 Nginx 和 uWSGI 配置中的头转发。

## 5. 测试脚本

本项目提供了 `test_api.py` 脚本，支持 HTTPS 和 AppKey 认证自动化测试。

**用法：**

1. 编辑 `test_api.py`，将 `API_KEY` 替换为 conf/appkeys.lua 中配置的有效 key。
2. 运行测试：

```bash
python3 test_api.py
```

**脚本功能：**
- 自动跳过自签名证书校验（适合开发环境）
- 自动携带 AppKey 认证头
- 同时测试 OpenAI 兼容接口和旧版 /generate 接口
- 打印详细响应内容

**示例代码片段：**
```python
API_KEY = "sk-test123456"  # 替换为你的 AppKey
HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {API_KEY}"
}
response = requests.post("https://localhost/v1/chat/completions", headers=HEADERS, json=payload, verify=False)
```

**常见问题：**
- 若提示 401/429，请检查 AppKey 是否正确、QPS 是否超限。
- 若提示证书不受信任，可用 `-k` 跳过校验或信任自签名证书。

## 未来增强

根据 `idea.md` 的设想，未来可以考虑以下增强功能：

* **模型下载与管理**: 目前模型需要手动下载并放置在指定路径。未来可以集成 `modelscope.cn` 等平台的模型下载功能，并提供一个完善的模型管理界面，方便用户搜索、下载、更新和删除本地模型。
* **模型维护**: 建立模型版本管理机制，支持多模型同时运行或动态切换模型，并提供模型性能监控和日志分析功能。
* **用户界面 (UI/UX)**: 当前平台仅提供后端 API。未来可以开发一个用户友好的前端界面，方便用户进行模型交互、查看生成结果、管理模型等，提供更完整的 AI 平台体验。
* **更完善的错误处理与日志**: 在生产环境中，需要更详细和结构化的日志记录，以及更健壮的错误处理机制，以便快速诊断和解决问题。
* **安全性**: 实施 API 密钥、用户认证、访问控制等安全措施，保护平台和模型免受未经授权的访问。
* **性能优化**: 进一步优化 `nano-vllm` 的推理性能，例如通过批量推理、量化等技术，以及对 `uWSGI` 和 `Nginx` 配置进行更精细的调优。
* **容器化部署**: 提供 Dockerfile 和 Docker Compose 配置，方便使用 Docker 进行容器化部署，提高部署的便捷性和可移植性。

## 部署与维护脚本

- `setup_ssl.sh`：一键生成/配置 SSL 证书，支持内网 IP
- `start_ubuntu.sh`：自动检测证书并启动服务
- `docker_env_setup.sh`：一键配置容器环境脚本

### 6. 常用 HTTPS + AppKey 测试命令

以下命令假设服务 IP 为 192.168.0.168，AppKey 为 sk-test123456：

```bash
# 1. 健康检查（无需 AppKey）
curl -k https://192.168.0.168/health

# 2. OpenAI 兼容接口（推荐，需 AppKey）
curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-test123456" \
  -d '{
        "messages": [
            {"role": "system", "content": "你是一个有帮助的助手。"},
            {"role": "user", "content": "你好"}
        ],
        "temperature": 0.7,
        "max_tokens": 100
      }' \
  https://192.168.0.168/v1/chat/completions

# 3. 也支持不带 Bearer 前缀
curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: sk-test123456" \
  -d '{
        "messages": [
            {"role": "user", "content": "你好"}
        ],
        "temperature": 0.7,
        "max_tokens": 100
      }' \
  https://192.168.0.168/v1/chat/completions

# 4. 旧版 /generate 接口（如需兼容测试）
curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-test123456" \
  -d '{"prompts": ["你好"], "sampling_params": {"max_tokens": 50}}' \
  https://192.168.0.168/generate
```

请将 `sk-test123456` 替换为你实际的 AppKey。

### 7. Docker 容器环境一键准备

如在官方 NVIDIA PyTorch 容器（nvcr.io/nvidia/pytorch:25.05-py3）内部署，推荐使用：

```bash
bash docker_env_setup.sh
```

脚本功能：
- 配置 pip 源（清华镜像）
- 安装系统依赖、OpenResty、Lua HTTP 库
- 安装 Python 依赖和 uWSGI
- 检查 CUDA 环境
- 提示模型目录
- 结束后自动提示启动、SSL 配置、测试命令

**典型流程：**
1. 进入容器后，cd 到 /ai/mllm 目录
2. 执行 bash docker_env_setup.sh
3. 按提示运行 ./start_ubuntu.sh 启动服务
4. 按需配置 SSL 证书、运行测试脚本

**注意事项：**
- 需提前挂载好模型目录（如 -v /home/my:/ai）
- 如遇依赖问题可多次运行脚本或手动补充
- 推荐结合 docker_pull_run.sh 脚本一键拉取镜像并进入容器
