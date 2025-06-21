import requests
import json

# API 端点 URL
# 如果您在本地运行开发服务器（python app.py），请使用 http://localhost:5000/generate
# 如果您通过 Nginx 访问（生产部署），请使用 http://localhost:80/generate
API_URL = "http://localhost:80/generate"

# 请求数据
payload = {
    "prompts": [
        "请写一个关于人工智能的短故事。",
        "给我一个关于宇宙的奇妙事实。"
    ],
    "sampling_params": {
        "temperature": 0.7,
        "max_tokens": 100
    }
}

# 发送 POST 请求
try:
    response = requests.post(API_URL, json=payload)
    response.raise_for_status()  # 如果请求失败，抛出 HTTPError

    # 打印响应
    print("请求成功！")
    print("状态码:", response.status_code)
    print("响应内容:")
    print(json.dumps(response.json(), indent=4, ensure_ascii=False))

except requests.exceptions.ConnectionError as e:
    print(f"连接错误: 无法连接到服务器。请确保应用程序正在运行并可以通过 {API_URL} 访问。")
    print(f"错误详情: {e}")
except requests.exceptions.HTTPError as e:
    print(f"HTTP 错误: {e.response.status_code} - {e.response.text}")
except requests.exceptions.RequestException as e:
    print(f"请求过程中发生错误: {e}")
except json.JSONDecodeError:
    print("响应内容不是有效的 JSON。")
    print("原始响应内容:", response.text) 