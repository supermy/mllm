import torch
from nanovllm import LLM, SamplingParams
from flask import Flask, request, jsonify
import os

app = Flask(__name__)

llm = None

def load_model():
    global llm
    if llm is None:
        try:
            # --- 显式 CUDA 检查和日志 ---
            print("DEBUG: 正在检查 CUDA 可用性...")
            if not torch.cuda.is_available():
                print("ERROR: CUDA 不可用！请检查您的 GPU、驱动和 CUDA 设置。")
                raise RuntimeError("CUDA 不可用。")
            print(f"DEBUG: CUDA 可用。找到 {torch.cuda.device_count()} 个 GPU。")
            if torch.cuda.device_count() > 0:
                print(f"DEBUG: 当前 CUDA 设备: {torch.cuda.current_device()}")
                print(f"DEBUG: CUDA 设备名称: {torch.cuda.get_device_name(torch.cuda.current_device())}")
            # --- 结束 CUDA 检查 ---

            print(f"DEBUG: 尝试从 /ai/models/Qwen3-0.6B/ 加载模型...")
            llm = LLM("/ai/models/Qwen3-0.6B/", enforce_eager=True, tensor_parallel_size=1)
            print(f"DEBUG: 模型从 /ai/models/Qwen3-0.6B/ 加载成功。")
        except Exception as e:
            import traceback
            print(f"ERROR: 模型加载失败: {e}")
            print("ERROR: 完整错误回溯如下:")
            traceback.print_exc() # 打印完整回溯
            llm = None # 确保 llm 为 None 如果加载失败
    else:
        print("DEBUG: 模型已加载。")

@app.route('/generate', methods=['POST'])
def generate_text():
    load_model() # 在每个请求中尝试加载模型
    if llm is None:
        return jsonify({"error": "Model not loaded. Please ensure MODEL_PATH is correct and model can be loaded."}), 500

    print(f"DEBUG: Received Content-Type: {request.headers.get('Content-Type')}")
    data = request.json
    prompts = data.get("prompts", [])
    if not prompts:
        return jsonify({"error": "No prompts provided."}), 400

    sampling_params_data = data.get("sampling_params", {})
    sampling_params = SamplingParams(
        temperature=sampling_params_data.get("temperature", 0.6),
        max_tokens=sampling_params_data.get("max_tokens", 256)
    )

    try:
        outputs = llm.generate(prompts, sampling_params)
        results = [output["text"] for output in outputs]
        return jsonify({"results": results})
    except Exception as e:
        return jsonify({"error": f"Error during generation: {e}"}), 500

@app.route('/health', methods=['GET'])
def health_check():
    load_model() # 在每个请求中尝试加载模型
    if llm is not None:
        return jsonify({"status": "Model loaded and ready."}), 200
    else:
        return jsonify({"status": "Model not loaded. Check logs for errors."}), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002) # LLM 服务将在 5002 端口运行 