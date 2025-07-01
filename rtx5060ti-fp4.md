# 拉取官方 PyTorch 容器
docker pull nvcr.io/nvidia/pytorch:24.05-py3

# 运行容器
docker run -it --gpus all --rm nvcr.io/nvidia/pytorch:24.05-py3

# 在容器内安装  安装失败
pip install --no-cache-dir "git+https://github.com/NVIDIA/TransformerEngine.git@stable"

