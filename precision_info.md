# Transformer Engine 和 TensorRT 精度支持信息

## Transformer Engine

`NVIDIA Transformer Engine` 主要专注于 `FP8` 精度（8 位浮点），包括 `E4M3` 和 `E5M2` 两种格式，以及它们的 `HYBRID` 组合（前向传播使用 `E4M3`，反向传播使用 `E5M2`）。

**FP4 和 FP6 的支持：**

`Transformer Engine` 目前**不直接支持 FP4 和 FP6 精度**。这意味着没有内置的上下文管理器（如 `fp4_autocast` 或 `fp6_autocast`）来直接启用这些精度。如果您需要测试或使用这些精度，通常需要：

*   利用其他专门的量化库。
*   手动实现更底层的量化和反量化逻辑。
*   编写自定义的 CUDA 内核，但这会大大增加复杂性。

**FP8 示例（概念性代码，需要 `Transformer Engine` 和 CUDA 环境运行）：**

```python
import torch
import transformer_engine.pytorch as te
from transformer_engine.common import recipe

# 检查CUDA是否可用
if not torch.cuda.is_available():
    print("CUDA 不可用，Transformer Engine 需要 NVIDIA GPU。")
    # exit()
else:
    device = torch.device("cuda")

    # 定义输入和输出特征维度
    in_features = 512
    out_features = 256
    batch_size = 64 # 确保批次大小和维度是16的倍数，以获得最佳性能

    # 创建随机输入张量
    inp = torch.randn(batch_size, in_features, device=device, dtype=torch.float16)

    print(f"输入张量形状: {inp.shape}, 数据类型: {inp.dtype}")

    # 创建FP8 recipe
    # 可以尝试 Format.E4M3, Format.E5M2 或 Format.HYBRID
    fp8_recipe = recipe.DelayedScaling(fp8_format=recipe.Format.HYBRID, amax_history_len=16, amax_compute_algo="max")

    print("\n--- 进行 FP8 测试 (Transformer Engine) ---")
    try:
        # 使用fp8_autocast上下文管理器
        with te.fp8_autocast(enabled=True, fp8_recipe=fp8_recipe):
            # 创建FP8线性层
            linear_layer_fp8 = te.Linear(in_features, out_features, bias=True, params_dtype=torch.float16)
            
            # 执行前向传播
            out_fp8 = linear_layer_fp8(inp)
        
        # 在fp8_autocast外部执行反向传播
        loss_fp8 = out_fp8.mean()
        loss_fp8.backward()

        print(f"FP8 计算成功! 输出形状: {out_fp8.shape}, 数据类型: {out_fp8.dtype}")
        print("FP8 测试通过。")

    except Exception as e:
        print(f"FP8 测试失败: {e}")
        print("请确保您的 GPU 支持 FP8 (例如 NVIDIA Hopper, Ada 或 Blackwell 架构)，"
              "并且 Transformer Engine 已正确安装并配置。")
```

## TensorRT

`NVIDIA TensorRT` 是一个用于高性能深度学习推理的 SDK。它支持多种精度，以在 NVIDIA GPU 上优化模型性能。

**FP4 支持：**

*   **TensorRT `确实支持 FP4 (FP4E2M1)` 数据类型。**
*   `FP4` 线性操作的硬件加速主要依赖于最新的 `NVIDIA Blackwell GPU`（计算能力 10.0 及更高版本，例如 `NVIDIA RTX PRO 6000 Blackwell`, `NVIDIA B200`）。这些 GPU 原生支持 FP4。在较旧的 GPU 架构（如 `NVIDIA H100` 或 `NVIDIA L40S`）上，FP4 可能在**硬件仿真模式**下受支持，这意味着它可能无法获得与原生硬件加速相同的性能优势。
*   在 TensorRT 中使用 FP4 需要**显式量化/反量化 (`Q/DQ`) 层**。这意味着您需要通过量化感知训练 (`QAT`) 或训练后量化 (`PTQ`) 工作流程来准备模型，其中量化操作被明确地表示在模型图中。
*   `NVIDIA TensorRT Model Optimizer` 是一个工具库，可以帮助您对模型进行 FP4 量化，并将其导出为 ONNX 格式，然后由 TensorRT 进行优化。
*   FP4 权重是紧密打包的，每字节包含两个 FP4 元素。
*   对于激活，推荐使用**动态量化**，其尺度会在推理时根据输入数据动态计算。

**FP6 支持：**

*   目前，在 TensorRT 的官方文档和支持矩阵中，**没有找到直接提到 FP6 (6 位浮点) 数据类型的支持**。TensorRT 主要支持 `FP32`, `FP16`, `BF16`, `FP8` 和 `FP4`。如果您有 FP6 的特定需求，可能需要关注 NVIDIA 未来的发布，或者考虑自定义实现。

**关键注意事项：**

*   `TensorRT` 的优化是针对特定 GPU 架构进行的，因此为 FP4 优化的模型在不支持原生 FP4 的硬件上运行时，性能可能受到限制或需要仿真。
*   实现 FP4 量化通常比简单的 FP8 `autocast` 更复杂，因为它涉及到模型转换和 Q/DQ 层的管理。

*   **FP4 (4 位浮点)**
    *   `TensorRT-LLM` **明确支持 NVFP4 (NVIDIA FP4) 数据类型**。这是 `NVIDIA` 最新 `Blackwell` 架构 GPU (例如 `RTX PRO 6000 Blackwell`, `B200`) 的一个关键特性，这些 GPU 提供原生 `FP4` 硬件加速。
    *   `FP4` 旨在提供更高的计算吞吐量和更低的内存占用，例如与 `FP32` 相比可实现 16 倍的数学吞吐量提升。
    *   在 `TensorRT-LLM` 中，您可以通过其量化工具链（如 `ft_plugin`，以及 `TensorRT Model Optimizer`）将模型量化为 `FP4`。
    *   **重要提示：** 在非 `Blackwell` GPU 上，`FP4` 可能在**硬件仿真模式**下运行，性能可能不如原生加速。

**FP4 推理示例（概念性代码，需要预先量化的模型和 TensorRT-LLM 环境）：**

```python
import torch
from tensorrt_llm.runtime import ModelRunner # 假设 ModelRunner 是用于推理的类

# 这是一个概念性的示例，假设您已经有一个量化为 FP4 的 TensorRT-LLM 引擎文件。
# 实际操作中，您需要使用 TensorRT-LLM 工具链来构建这个引擎。

def run_fp4_inference(model_path: str, input_text: str):
    """
    运行基于 FP4 量化模型的 TensorRT-LLM 推理。
    :param model_path: FP4 量化后的 TensorRT 引擎文件路径。
    :param input_text: 输入的文本。
    """
    if not torch.cuda.is_available():
        print("CUDA 不可用，TensorRT-LLM 需要 NVIDIA GPU。")
        return

    device = torch.device("cuda")

    try:
        # 加载 TensorRT-LLM 引擎
        # 实际加载方式可能因 TensorRT-LLM 版本和具体模型而异。
        # 这里仅为概念性演示。
        runner = ModelRunner.from_engine(model_path, rank=0)
        print(f"成功加载模型: {model_path}")

        # 模拟输入（实际需要将文本转换为模型所需的 token ID）
        # 这里仅作演示，实际需要预处理，例如使用 Hugging Face tokenizer
        input_ids = torch.randint(0, 50000, (1, 10), dtype=torch.int32, device=device) # 假设的 token IDs

        print(f"输入 token IDs 形状: {input_ids.shape}")

        # 运行推理
        # 具体的推理方法取决于 ModelRunner 的实现，可能包括 generate 或 forward
        output_ids = runner.generate(input_ids)

        print(f"输出 token IDs 形状: {output_ids.shape}")
        print("FP4 推理完成！")

    except Exception as e:
        print(f"FP4 推理过程中发生错误: {e}")
        print("请确保您已：")
        print("1. 安装了正确版本的 TensorRT-LLM。")
        print("2. 您的 GPU 支持 FP4 或在仿真模式下运行。")
        print("3. `model_path` 指向一个有效的 FP4 量化模型引擎文件。")
        print("4. 已使用 TensorRT-LLM 工具链正确量化模型并构建了引擎。")


# 如何使用 (伪代码，需要替换为实际的模型路径和输入)
# if __name__ == "__main__":
#     fp4_engine_path = "/path/to/your/fp4_quantized_model.engine" # 替换为您的 FP4 引擎路径
#     test_input = "Hello, world!"
#     run_fp4_inference(fp4_engine_path, test_input) 