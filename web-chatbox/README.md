# AI ChatBox - 本地大语言模型聊天界面

一个现代化的 Web 聊天界面，专为本地大语言模型设计，支持与 API Gateway 联调。

## 功能特性

### 🎨 界面设计
- **现代化 UI**: 简洁美观的聊天界面
- **响应式设计**: 完美适配桌面端和移动端
- **主题切换**: 支持白天/黑夜两种主题模式
- **动画效果**: 流畅的过渡动画和交互反馈

### 🤖 AI 对话
- **OpenAI 兼容**: 完全兼容 OpenAI API 格式
- **对话历史**: 自动保存和恢复聊天记录
- **实时响应**: 支持流式响应和打字指示器
- **错误处理**: 完善的错误提示和处理机制

### ⚙️ 配置管理
- **设置面板**: 可视化的配置界面
- **API 配置**: 支持自定义 API Key 和服务器地址
- **模型参数**: 可调节温度、最大 Token 数等参数
- **界面设置**: 自定义显示选项和快捷键

### ⌨️ 快捷键
- `Ctrl/Cmd + L`: 切换主题
- `Ctrl/Cmd + K`: 清空聊天记录
- `Ctrl/Cmd + ,`: 打开设置面板
- `Ctrl/Cmd + I`: 聚焦输入框
- `Enter`: 发送消息
- `Shift + Enter`: 换行

## 快速开始

### 1. 准备 Bootstrap 资源 (本地化)

1.  **下载 Bootstrap:** 从 [Bootstrap 官方网站](https://getbootstrap.com/docs/5.3/getting-started/download/) 下载编译好的 CSS 和 JS 文件。
2.  **创建本地目录:** 在 `web-chatbox/` 目录下创建一个 `lib/bootstrap/` 目录，例如：
    ```bash
    mkdir -p web-chatbox/lib/bootstrap/css
    mkdir -p web-chatbox/lib/bootstrap/js
    ```
3.  **复制文件:** 将下载并解压的 Bootstrap 包中的 `css/` 和 `js/` 目录下的所有文件，分别复制到 `web-chatbox/lib/bootstrap/css/` 和 `web-chatbox/lib/bootstrap/js/`。

### 2. 部署到 Web 服务器

将整个 `web-chatbox` 目录（包括新添加的 `lib/` 文件夹）部署到支持静态文件的 Web 服务器上，例如 Nginx：

```bash
# 假设你的 Nginx 静态文件根目录是 /usr/share/nginx/html/
# 你可以将 web-chatbox 拷贝到 /usr/share/nginx/html/chatbox/
sudo mkdir -p /usr/share/nginx/html/chatbox
sudo cp -r web-chatbox/* /usr/share/nginx/html/chatbox/
```

确保你的 Nginx 配置（`nginx.conf`）中包含类似以下内容，以便正确服务 `web-chatbox` 目录下的静态文件，并绕过全局鉴权：

```nginx
server {
    listen 443 ssl http2;
    server_name your-server-domain;

    # ... SSL 证书配置 ...

    # 为 /web-chatbox/ 静态文件添加独立 location，不进行鉴权
    location /web-chatbox/ {
        alias /usr/share/nginx/html/chatbox/;
        index index.html;
        
        # CORS headers (如果需要)
        add_header Access-Control-Allow-Origin "*";
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization";
        add_header Access-Control-Expose-Headers "Content-Length,Content-Range";
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }

    # 所有其他请求（包括 /v1/chat/completions）都由 api_gateway.lua 处理，并添加 CORS 头部
    location / {
        default_type application/json;
        
        # CORS headers (如果需要)
        add_header Access-Control-Allow-Origin "*";
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization";
        add_header Access-Control-Expose-Headers "Content-Length,Content-Range";
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }

        content_by_lua_file "/ai/mllm/api_gateway.lua";
    }
}
```

### 3. 配置 API Gateway

确保你的 API Gateway 支持以下端点：

- `POST /v1/chat/completions` - 聊天完成接口
- `GET /health` - 健康检查接口

### 4. 配置 API Key

有两种方式配置 API Key：

#### 方式一：通过设置面板
1.  打开聊天界面 (e.g., `https://your-server-domain/chatbox/index.html`)
2.  点击右上角的"设置"按钮
3.  在 API 配置中输入你的 API Key
4.  点击"保存设置"

#### 方式二：通过 URL 参数
```
https://your-server-domain/chatbox/index.html?apiKey=your-api-key
```

## 文件结构

```
web-chatbox/
├── index.html          # 主页面
├── style.css           # 样式文件
├── chatbox.js          # 主要功能逻辑
├── config.js           # 配置文件
├── settings.js         # 设置面板组件
├── README.md           # 说明文档
└── lib/                  # 第三方库（如 Bootstrap）
    └── bootstrap/
        ├── css/
        └── js/
```

## API 配置

### 基本配置
- **API Key**: 用于认证的密钥
- **API URL**: API 服务器地址（可选，默认使用当前域名）

### 模型参数
- **模型名称**: 使用的模型名称（默认：local-model）
- **温度**: 控制响应的随机性（0-2，默认：0.7）
- **最大 Token 数**: 单次响应的最大长度（默认：1000）

### 界面设置
- **自动滚动**: 是否自动滚动到最新消息
- **显示时间戳**: 是否显示消息时间戳

## 与 API Gateway 集成

### 请求格式
ChatBox 发送符合 OpenAI 格式的请求：

```json
{
  "model": "local-model",
  "messages": [
    {"role": "user", "content": "你好"}
  ],
  "temperature": 0.7,
  "max_tokens": 1000,
  "stream": false
}
```

### 响应格式
期望接收符合 OpenAI 格式的响应：

```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "local-model",
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "你好！有什么可以帮助你的吗？"
      },
      "finish_reason": "stop",
      "index": 0
    }
  ]
}
```

## 自定义配置

### 修改默认配置
编辑 `config.js` 文件来修改默认配置：

```javascript
const ChatBoxConfig = {
    api: {
        endpoint: '/v1/chat/completions',
        timeout: 60000
    },
    model: {
        name: 'your-model-name',
        temperature: 0.7,
        maxTokens: 1000
    },
    // ... 其他配置
};
```

### 自定义样式
编辑 `style.css` 文件来自定义界面样式。Bootstrap 变量可以通过 `style.css` 覆盖或直接在 HTML 中使用内联样式。

```css
/* 覆盖 Bootstrap 变量 */
:root {
    --bs-primary: #your-custom-primary-color;
}

/* 自定义组件样式 */
.my-custom-class {
    /* ... */
}
```

## 浏览器兼容性

- Chrome 60+
- Firefox 55+
- Safari 12+
- Edge 79+

## 开发说明

### 本地开发
1. 克隆项目到本地
2. 使用本地服务器运行（避免 CORS 问题）
3. 配置 API Gateway 地址
4. 开始开发和测试

### 调试模式
打开浏览器开发者工具，查看控制台输出来调试问题。

## 故障排除

### 常见问题

1. **API 调用失败**
   - 检查 API Key 是否正确
   - 确认 API Gateway 是否正常运行
   - 查看网络请求是否被阻止

2. **样式显示异常**
   - 确认 CSS 文件是否正确加载
   - 检查浏览器兼容性

3. **设置无法保存**
   - 检查浏览器是否支持 localStorage
   - 确认没有隐私模式限制

### 日志查看
在浏览器控制台中查看详细的错误信息和调试日志。

## 许可证

本项目采用 MIT 许可证。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！ 