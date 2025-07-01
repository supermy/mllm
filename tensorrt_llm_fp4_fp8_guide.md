# TensorRT-LLM FP4 和 FP8 量化与推理指南

本指南旨在帮助您理解如何在 NVIDIA TensorRT-LLM 中进行 FP4 和 FP8 精度量化，并运行推理。这通常涉及模型转换、量化、引擎构建和推理执行等步骤。

**重要提示：** TensorRT-LLM 的最佳实践和特性会随着版本更新而演进。请始终参考 [NVIDIA/TensorRT-LLM 官方 GitHub 仓库](https://github.com/NVIDIA/TensorRT-LLM) 和 [官方文档](https://nvidia.github.io/TensorRT-LLM/) 获取最新和最准确的信息。

## 1. 环境准备

要开始使用 TensorRT-LLM，您需要一个支持 CUDA 的 NVIDIA GPU 和相应的软件环境。

*   **Docker 和 NVIDIA Container Toolkit：**
    推荐使用 NVIDIA 提供的 Docker 容器，因为它预配置了所有必要的依赖项（CUDA、cuDNN、TensorRT-LLM 等）。

    ```bash
    # 拉取 TensorRT-LLM Docker 镜像（请根据您的需求选择最新版本）
    # 例如，使用 0.21.0rc0 版本
    docker pull nvcr.io/nvidia/tensorrt-llm/release:0.21.0rc0

    # 运行容器并进入交互式 shell
    # --rm: 容器退出时自动删除
    # --gpus all: 允许容器访问所有可用的 GPU
    # --ipc=host: 某些高性能操作可能需要共享内存
    # -it: 交互式伪终端
    docker run --rm --gpus all --ipc=host -it nvcr.io/nvidia/tensorrt-llm/release:0.21.0rc0 /bin/bash
    ```
    进入容器后，您将在 `TensorRT-LLM` 的环境中。

## 2. 模型准备

通常，您会从 Hugging Face 或其他来源获取一个 FP32 或 FP16 的预训练模型。在将其用于 TensorRT-LLM 之前，可能需要进行格式转换和量化。

TensorRT-LLM 提供了一系列用于模型转换和量化的脚本，通常位于其 `examples` 目录中。

## 3. FP8 量化流程

`FP8` (8 位浮点) 是 `TensorRT-LLM` 支持的关键精度之一，特别是在 `NVIDIA Hopper` (H100) 和 `Ada Lovelace` (L40S) 架构的 GPU 上有很好的性能。

**核心概念：**
*   `FP8` 量化通常涉及权重和激活都使用 8 位。
*   `TensorRT-LLM` 通过其量化工具链，如 `quantize.py` 脚本，支持 `FP8` 量化。

**步骤示例：**

假设您已在容器内，并位于 `TensorRT-LLM` 仓库的根目录。

1.  **量化模型：**
    使用 `quantize.py` 脚本对预训练模型进行 FP8 量化。这个脚本通常位于 `TensorRT-LLM/examples/quantization` 目录下。
    
    ```bash
    # 假设您的原始模型在 /path/to/your/model_dir (例如 Hugging Face 模型的本地路径)
    # 并且您希望将 FP8 量化后的模型输出到 /path/to/your/quantized_fp8_model

    python3 examples/quantization/quantize.py \
        --model_dir /path/to/your/model_dir \
        --dtype float16 \
        --qformat fp8 \
        --kv_cache_dtype fp8 \
        --output_dir /path/to/your/quantized_fp8_model \
        --calib_size 32 # 校准数据集大小，用于 AQT (Activation Quantization)
    ```
    *   `--model_dir`: 原始模型的路径。
    *   `--dtype`: 量化前模型的数据类型（通常是 `float16` 或 `bfloat16`）。
    *   `--qformat fp8`: 指定量化格式为 FP8。
    *   `--kv_cache_dtype fp8`: 指定 KV Cache 的数据类型为 FP8，以节省内存。
    *   `--output_dir`: 量化后模型的输出路径。
    *   `--calib_size`: 校准数据集的大小，用于激活量化，通常需要一个小的代表性数据集。

2.  **构建 TensorRT 引擎：**
    量化完成后，您需要使用 `trtllm-build` 工具构建 TensorRT 推理引擎。这个引擎是优化后的二进制文件，可以直接用于推理。

    ```bash
    # 假设您在容器内
    trtllm-build \
        --checkpoint_dir /path/to/your/quantized_fp8_model \
        --output_dir /path/to/your/fp8_engine \
        --gemm_plugin float16 \
        --strongly_typed \
        --workers 1 # 根据您的 GPU 数量和模型大小调整 workers 数量
    ```
    *   `--checkpoint_dir`: 指向您量化后模型的路径。
    *   `--output_dir`: 构建的 TensorRT 引擎的输出路径。
    *   `--gemm_plugin float16`: 通常用于通用矩阵乘法 (GEMM) 插件，这里设置为 `float16` 兼容 FP8。
    *   `--strongly_typed`: 启用严格类型检查，有助于确保精度。
    *   `--workers`: 并行构建引擎的 worker 数量。对于较大的模型，增加 worker 数量可以加速构建。

3.  **运行推理：**
    引擎构建完成后，您可以使用 `TensorRT-LLM` 的 `run.py` 脚本（或自定义推理代码）进行推理。

    ```bash
    # 假设您的 tokenizer 也在 /path/to/your/model_dir
    python3 examples/run.py \
        --tokenizer_dir /path/to/your/model_dir \
        --engine_dir /path/to/your/fp8_engine \
        --max_output_len 50 \
        --input_text "Hello, world!"
    ```
    *   `--tokenizer_dir`: 模型的 tokenizer 路径，用于将文本转换为 token IDs。
    *   `--engine_dir`: 指向您构建的 TensorRT 引擎的路径。
    *   `--max_output_len`: 生成的最大输出 token 长度。
    *   `--input_text`: 用于推理的输入文本。

## 4. FP4 量化流程

`FP4` (4 位浮点，特指 `NVFP4` 或 `FP4E2M1`) 是为 `NVIDIA Blackwell` 架构 GPU 优化的，提供更高的吞吐量。在非 `Blackwell` GPU 上，`FP4` 可能在硬件仿真模式下运行。

**核心概念：**
*   `NVFP4` 是 NVIDIA 专有的 FP4 格式。
*   量化方法通常涉及 `Weight-Only` 或 `AWQ` (Activation-aware Weight Quantization) 等。
*   与 FP8 类似，需要通过 `quantize.py` 和 `trtllm-build` 来处理。

**步骤示例：**

1.  **量化模型 (例如 INT4 AWQ)：**
    `TensorRT-LLM` 通常通过 `AWQ` (Activation-aware Weight Quantization) 支持 FP4。虽然名称是 `INT4 AWQ`，但它可以在 `Blackwell` 上映射到 FP4 硬件指令。

    ```bash
    # 使用 int4_awq 格式进行量化，这在 Blackwell 上可以利用 FP4 硬件
    python3 examples/quantization/quantize.py \
        --model_dir /path/to/your/model_dir \
        --dtype float16 \
        --qformat int4_awq \
        --output_dir /path/to/your/quantized_fp4_model \
        --calib_size 32
    ```
    *   `--qformat int4_awq`: 指定量化格式为 INT4 AWQ。这在 `Blackwell` 架构上可以高效利用 FP4。

2.  **构建 TensorRT 引擎：**
    构建引擎的命令与 FP8 类似，但请确保 `checkpoint_dir` 指向您 FP4 量化后的模型。

    ```bash
    trtllm-build \
        --checkpoint_dir /path/to/your/quantized_fp4_model \
        --output_dir /path/to/your/fp4_engine \
        --gemm_plugin float16 \
        --strongly_typed \
        --workers 1
    ```

3.  **运行推理：**
    推理命令与 FP8 类似。

    ```bash
    python3 examples/run.py \
        --tokenizer_dir /path/to/your/model_dir \
        --engine_dir /path/to/your/fp4_engine \
        --max_output_len 50 \
        --input_text "Hello, world!"
    ```

## 5. 重要注意事项

*   **硬件兼容性：** `FP8` 在 `Hopper` 和 `Ada Lovelace` 上有很好的支持，而 `FP4` 的原生硬件加速则主要体现在 `Blackwell` GPU 上。在不支持的硬件上，它们可能会回退到软件仿真，导致性能下降。
*   **模型支持：** 并非所有模型都能够直接量化到 `FP4` 或 `FP8` 而不损失精度。您可能需要进行额外的精度检查和校准。
*   **量化策略：** `TensorRT-LLM` 支持多种量化策略 (例如 `Weight-Only`, `SmoothQuant`, `AWQ`, `FP8`)。选择哪种策略取决于您的模型、硬件以及对精度和性能的需求。
*   **文档阅读：** 强烈建议您仔细阅读 `TensorRT-LLM` 官方文档中关于量化（`quantization`）和示例（`examples`）的部分，以获取最详细和最新的信息。

希望这份指南能帮助您在项目中提取和使用 `TensorRT-LLM` 的 `FP4` 和 `FP8` 相关代码。 