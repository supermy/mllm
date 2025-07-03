项目要求；
1.从 modelscope.cn 上搜索下载模型，本地模型可维护；
2.从本地模型列表，加载运行模型；用https://github.com/GeeeekExplorer/nano-vllm运行模型；
3.用 nginx+uWSGI 作为入口平台技术实现；
4.生成完整的部署维护脚本，分为 macos 与 ubuntu 两套；
5.生成测试脚本； 
6.追求极致性能，uWSGI+nginx unix soclet 链接。

接口符合 ；
    api_gate 符合openai api 规范；
    api_gate支持 https,生成一键 ssl 的配置脚本 ,ssl支持内网 IP 地址；
    apt_gate 支持 appkey;
   生成 chatbox web 版本，能与 ap_gate 联调，皮肤分为白天黑夜两种模式。

开发环境：docker

    docker run -dt -e TZ=Asia/Shanghai --name mllm_dev --restart=always --gpus all --network=host --shm-size 4G -v /home/my:/ai   nvcr.io/nvidia/pytorch:25.05-py3 /bin/bash

    docker exec -it mllm_dev bash

    >>nvidia-smi