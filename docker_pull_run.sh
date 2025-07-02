#!/bin/bash
# 拉取官方 NVIDIA PyTorch 镜像并启动 AI 平台容器（适合纯拉取+挂载本地代码/模型场景）
set -e

IMAGE="nvcr.io/nvidia/pytorch:25.05-py3"
CONTAINER_NAME="mllm_dev"
HOST_MODEL_DIR="/home/my"      # 按需修改为你的主机模型目录
CONTAINER_MODEL_DIR="/ai"      # 容器内模型目录

# 拉取镜像
echo "==== 拉取 NVIDIA PyTorch 镜像 $IMAGE ===="
docker pull $IMAGE

echo "==== 启动容器 $CONTAINER_NAME ===="
docker run -dt \
  -e TZ=Asia/Shanghai \
  --name $CONTAINER_NAME \
  --restart=always \
  --gpus all \
  --network=host \
  --shm-size 4G \
  -v $HOST_MODEL_DIR:$CONTAINER_MODEL_DIR \
  $IMAGE /bin/bash

echo "==== 容器已启动 ===="
echo "进入容器: docker exec -it $CONTAINER_NAME bash"
echo "容器内建议执行: cd /ai/mllm && bash docker_env_setup.sh && ./start_ubuntu.sh"
echo "测试: curl -k https://<your-ip>/health"
