| 参数名称                 | 形状           | 数据类型 |
| -------------------------- | ---------------- | ---------- |
| **down_proj**            |                |          |
| down_proj.input_scale    | []             | F32      |
| down_proj.weight         | [7,168, 1,024] | U8       |
| down_proj.weight_scale   | [7,168, 128]   | F8_E4M3  |
| down_proj.weight_scale_2 | []             | F32      |
| **gate_proj**            |                |          |
| gate_proj.input_scale    | []             | F32      |
| gate_proj.weight         | [2,048, 3,584] | U8       |
| gate_proj.weight_scale   | [2,048, 448]   | F8_E4M3  |
| gate_proj.weight_scale_2 | []             | F32      |
| **up_proj**              |                |          |
| up_proj.input_scale      | []             | F32      |
| up_proj.weight           | [2,048, 3,584] | U8       |
| up_proj.weight_scale     | [2,048, 448]   | F8_E4M3  |
| up_proj.weight_scale_2   | []             | F32      |

### model.layers.15.mlp.gate 参数


| 参数名称                     | 形状         | 数据类型 |
| ------------------------------ | -------------- | ---------- |
| gate.e_score_correction_bias | [256]        | F32      |
| gate.weight                  | [256, 7,168] | BF16     |

### model.layers.15.self_attn 参数


| 参数名称                            | 形状            | 数据类型 |
| ------------------------------------- | ----------------- | ---------- |
| self_attn.k_proj.k_scale            | []              | F32      |
| self_attn.kv_a_layernorm.weight     | [512]           | BF16     |
| self_attn.kv_a_proj_with_mqa.weight | [576, 7,168]    | BF16     |
| self_attn.kv_b_proj.weight          | [32,768, 512]   | BF16     |
| self_attn.o_proj.weight             | [7,168, 16,384] | BF16     |
| self_attn.q_a_layernorm.weight      | [1,536]         | BF16     |
| self_attn.q_a_proj.weight           | [1,536, 7,168]  | BF16     |
| self_attn.q_b_proj.weight           | [24,576, 1,536] | BF16     |
| self_attn.v_proj.v_scale            | []              | F32      |

### 结构说明

1. **MLP 专家层** ：
   * 包含 93 个专家模块（experts.0 到 experts.92）
   * 每个专家模块包含 3 个主要组件：
     * down_proj（降维投影）
     * gate_proj（门控投影）
     * up_proj（升维投影）
   * 使用混合精度：
     * 权重存储为 U8（8 位无符号整数）
     * 权重缩放因子使用 F8_E4M3（8 位浮点）
     * 输入缩放因子使用 F32（32 位浮点）
2. **门控机制** ：
   * 包含偏置项 (e_score_correction_bias)
   * 权重使用 BF16（16 位脑浮点）
3. **自注意力机制** ：
   * 包含多个投影层：
     * k_proj（键投影）
     * v_proj（值投影）
     * q_proj（查询投影）
     * o_proj（输出投影）
   * 使用层归一化 (layernorm)
   * 大多数参数使用 BF16 精度
4. **量化策略** ：
   * 使用动态量化：U8 权重配合浮点缩放因子
   * 缩放因子使用不同精度（F8_E4M3 和 F32）
   * 输入/输出使用全精度（F32）处理

> **注意** ：表格中的逗号分隔数字（如 7,168）表示千位分隔符，实际张量形状应为连续维度（如 [7168, 1024]）。
>
