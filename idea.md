项目要求；
1.从 modelscope.cn 上搜索下载模型，本地模型可维护；
2.从本地模型列表，加载运行模型；用https://github.com/GeeeekExplorer/nano-vllm运行模型；
3.用 nginx+uWSGI 作为入口平台技术实现；
4.生成完整的部署维护脚本，分为 macos 与 ubuntu 两套；
5.生成测试脚本； 
6.追求极致性能，uWSGI+nginx unix soclet 链接。

接口符合 openai 规范；
openai web前端；