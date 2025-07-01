import requests
import json

# 1. OpenAI 兼容接口测试
OPENAI_API_URL = "http://localhost:80/v1/chat/completions"
openai_payload = {
    "messages": [
        {"role": "system", "content": "你是一个有帮助的助手。"},
        {"role": "user", "content": "你好！请写一个关于人工智能的短故事。"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
}

print("\n==== 测试 OpenAI 兼容接口 /v1/chat/completions ====")
try:
    response = requests.post(OPENAI_API_URL, json=openai_payload)
    response.raise_for_status()
    print("请求成功！")
    print("状态码:", response.status_code)
    print("响应内容:")
    print(json.dumps(response.json(), indent=4, ensure_ascii=False))
except Exception as e:
    print(f"OpenAI 兼容接口测试失败: {e}")

# 2. 兼容旧版 /generate 接口测试
API_URL = "http://localhost:80/generate"
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

print("\n==== 测试旧版 /generate 接口 ====")
try:
    response = requests.post(API_URL, json=payload)
    response.raise_for_status()
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