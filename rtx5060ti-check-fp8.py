# Transformer Engine 成功：
#   输出为 FP16（内部使用 FP8 计算）
#   表示软件模拟 FP8 工作正常
# 原生 FP8 失败：
#   预期结果，因为消费级显卡缺少硬件支持
#   错误应为 "addmm_cuda" not implemented for 'Float8_e4m3fn'
# FP16 回退：
#   最可靠的跨平台解决方案
#   在 FP16 中计算，然后转换为 FP8 存储
# 对于 RTX 4060 Ti 级别的显卡，推荐使用 Transformer Engine 的 Linear 层方法或 FP16 回退方案。这两种方法都能在您的环境中可靠工作，而尝试原生 FP8 支持可能会继续失败。

import torch
import transformer_engine.pytorch as te
from transformer_engine.pytorch import fp8_autocast

device = torch.device("cuda")

# 调整维度使其能被32整除
# 原始形状: A(16,32) -> 调整为(32,32), B(32,64) -> 调整为(32,64)
A = torch.randn(32, 32, device=device, dtype=torch.float16)  # 调整为32的倍数
B = torch.randn(32, 64, device=device, dtype=torch.float16)  # 调整为32的倍数

with fp8_autocast(enabled=True):
    # 创建FP8线性层（无偏置）
    linear_layer = te.Linear(32, 64, bias=False, params_dtype=torch.float16)
    
    # 将权重设置为矩阵B（需要转置以匹配Linear层的期望格式）
    with torch.no_grad():
        linear_layer.weight.copy_(B.t())  # 转置B以匹配权重形状
    
    # 执行矩阵乘法A @ B
    C = linear_layer(A)

print(f"成功完成FP8矩阵乘法! 结果形状: {C.shape}, dtype: {C.dtype}")


def pad_to_multiple(tensor, multiple=32):
    """填充张量使其维度是32的倍数"""
    rows, cols = tensor.shape
    pad_rows = (multiple - rows % multiple) % multiple
    pad_cols = (multiple - cols % multiple) % multiple
    
    # 使用零填充
    padded = torch.nn.functional.pad(tensor, (0, pad_cols, 0, pad_rows))
    return padded, (rows, cols, pad_rows, pad_cols)

# 原始数据（非32倍数）
A_original = torch.randn(16, 32, device=device, dtype=torch.float16)
B_original = torch.randn(32, 64, device=device, dtype=torch.float16)

# 填充数据
A_padded, (orig_rows_A, orig_cols_A, pad_rows_A, pad_cols_A) = pad_to_multiple(A_original)
B_padded, (orig_rows_B, orig_cols_B, pad_rows_B, pad_cols_B) = pad_to_multiple(B_original)

with fp8_autocast(enabled=True):
    linear_layer = te.Linear(
        in_features=A_padded.shape[1], 
        out_features=B_padded.shape[0],  # 注意B需要转置
        bias=False,
        params_dtype=torch.float16
    )
    
    with torch.no_grad():
        linear_layer.weight.copy_(B_padded.t())
    
    C_padded = linear_layer(A_padded)

# 移除填充部分
C_actual = C_padded[:orig_rows_A, :orig_cols_B]

print(f"实际结果形状: {C_actual.shape}, dtype: {C_actual.dtype}")