# RV64 静态缺陷审计记录：convolution 家族与 pooling

- 产品基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`；文档 HEAD `529c7247f524902377455c62ab283b44918e285c`。
- 说明：本文档由主审计按台账方法直接静态追踪 convolution/pooling，并补充 normalization/elementwise；后两者的结论已并入 `coverage-ledger.md` 与 `history-cards.md` 的方法 A/B 处置。未构建、未运行动态测试，未修改产品源码。

## 1. 注册与 dispatch（A0）

`src/cpu/cpu_convolution_list.cpp` 按 dtype/format 分组（关键行）：

- f32 fwd：`jit_rvv_1x1_convolution_fwd_t` -> `rvv_wino_convolution_fwd_t` -> `rvv_brgemm_convolution_fwd_t` -> `riscv_gemm_convolution_fwd_t` -> shared `gemm_convolution_fwd_t` -> ref（`:139-144`）。
- bf16/f16 fwd：`rvv_brgemm_convolution_fwd_t` -> `jit_rvv_1x1_convolution_fwd_t` -> ref（`:178-181`）。
- f16 depthwise fwd：`jit_uni_dwconv_fwd_t` -> `rvv_brgemm_convolution_fwd_t` -> `jit_rvv_1x1_convolution_fwd_t` -> ref（`:201-204`）。
- backward data/weights、int8、deconvolution 等分组无 RV64 专用条目，走 shared GEMM/ref（`:245-399`）。

`src/cpu/cpu_pooling_list.cpp:63-65,93-95`：fwd/bwd 均为 `jit_uni_pooling_{fwd,bwd}_t<v/zvfh/zvfbfwma>` 后接 nchw/nhwc shared 与 ref。

## 2. PD 接受域（A1）

- pooling fwd（`jit_uni_pooling.hpp:60-123`）：`mayiuse(isa)` -> prop kind -> 算法（max/avg include/exclude）-> dtype 一致 + platform 支持 -> xf16 accum 必须 f32 -> 拒绝 zero-dim -> 拒绝 dilation -> `set_default_params()` -> dst dense -> attr skip-mask（post_ops 允许）-> `attr_.set_default_formats(dst)` -> init_conf。#3457 顺序不变量（default 先于 dense）满足；#5394 类属性 gate 通过 `post_ops_ok()`（`jit_uni_pool_kernel.cpp:179-188,332-335`）约束 post-op 链。
- pooling bwd（`:176-238`）：同族 gate，全部属性默认；f32 nspc 显式回落 nhwc gather（`:234-238`）。
- BRGEMM conv（`rvv_brgemm_conv.cpp:40-75`）：`isa_` 按 src dtype 命名（zvfbfwma/zvfh/v）-> `mayiuse(v)` -> fwd -> direct -> 无 zero-dim -> attr skip-mask -> post-op 仅"无或 sum 位于位置 0" -> `init_conf`。
- GEMM conv（`rvv_gemm_convolution.hpp:53-76`）：f32-only dtype 检查 -> 无 zero-dim -> attr gate -> `post_ops_ok()`（sum 仅位置 0、binary/prelu 受 broadcast 策略约束，`:86-137`）。
- depthwise（`jit_uni_dwconv.hpp:59-97`）：f16+Zvfh、IC==G、3x3、stride 1/2、无 dilation、NHWC/GOIHW、bias f16/f32、`attr()->has_default_values()`（#5394 修复模式，`:74-75`）。
- Winograd（`rvv_winograd_convolution.hpp:152-170`）：`mayiuse(v)`、fwd、f32-only、默认属性 + `post_ops_ok()`。
- 1x1（`jit_rvv_1x1_convolution.hpp:92-95,158-160`）：默认属性 gate + `post_ops_ok()`（当前 post-op len==0）。

## 3. execute / kernel（A3/A4）

- im2col（GEMM conv）：`rvv_gemm_convolution_utils.cpp:429` `no_w_padding=(lp==0 && r_pad==0)`；`:457-475,535-552` 两个向量化 copy 均要求无左右 padding，否则逐 `iw` 边界检查的标量路径；`:674-687,716-727` 其他 dtype 路径先算 `ow_start/ow_end` 合法区并单独填 padding。#4637 修复模式承接。
- BRGEMM conv bias：`rvv_brgemm_conv.cpp:175-183` `!with_sum` 时预初始化完整 `OW x OC`（有 bias 填 bias、无 bias 填零）；`:217-218` 全部有效 BRGEMM `beta=1.0f`；`:223-228` 仅 `with_sum && with_bias` 补 bias。#5162 不变量满足。
- counter 宽度：`rvv_gemm_convolution.cpp:159,399,441-456`、`rvv_gemm_convolution_utils.cpp:2248-2260` 均为 `dim_t`（#5594 修复承接）。
- pooling 空窗口：`jit_uni_pooling.cpp:195-200,283-288,379-386,486-493` 逐路径显式 `iw_start>=iw_end` 类 guard 并写 `empty_window_value()`；`jit_uni_pool_kernel.cpp:600-609` max 初值为 dtype lowest（#1677/#3457 修复承接）。
- pooling NaN：`jit_uni_pool_kernel.cpp:638-639,1278-1280,1648-1662,1977-1979` max 路径已改为 compare+merge（#5370/`b44a10839` 修复承接）；avg 路径为加法，无 min/max 语义问题。
- fused ReLU：`jit_rvv_gemm_convolution_kernel.cpp:209-213` 与 bnorm kernel 使用 `vmflt/vfmerge` 显式 mask（#5370 修复承接，`784e9ed44`）。

## 4. normalization / elementwise 补充处置（并入本记录）

- batch normalization：`jit_uni_batch_normalization.hpp:81,175` attr gate（fwd 允许 post_ops 子集、bwd 全默认）；kernel `jit_uni_batch_normalization_kernel.cpp` ReLU 使用显式 mask（#5370 承接）；scratchpad `2*C*nthr` 与 execute `ithr` 分片一致（#5839 同族模式）。
- binary：`jit_uni_binary.hpp:81-131` 完整 ISA/dtype/attr gate（f16->Zvfh、bf16->Zvfbfwma、per-tensor scales、post-op 链）；`post_ops_supported()`（`:175-293`）含 per_oc/per_w 的 u32 溢出 guard（#5594 邻域）。min/max 已 NaN-preserving（`6e071923e`）。
- eltwise：`jit_uni_eltwise.cpp:296-312,326,421` mayiuse/默认属性 gate；injector 保存并消费 alpha/beta（#5174 承接，`jit_uni_eltwise_injector.cpp:291-326`）；clamp/ReLU/ELU 均显式 compare+merge（#5370 承接）。
- group normalization：`jit_uni_group_normalization.cpp:544-578` attr/post-op gate + `CHECK(kernel->create_kernel())` 错误传播。
- layer normalization：`rvv_layer_normalization.hpp:86` 默认属性 gate；`3610396dd` 移除了 layernorm var 的 `fmax_s`（NaN 传播修复承接）。
- PReLU：**静态高置信 finding RV64-001**（`jit_uni_prelu.cpp:121-127` 裸 `vfmax/vfmin` 吞 NaN；与 reference/#5370 策略不同，但公共 NaN 契约未闭环）。

## 5. 差异处置汇总

- 等价/合法架构差异：RV64 conv 仅 forward + 特定 dtype/layout 组合；backward、int8、多数 blocked layout 显式 `unimplemented` 后由 shared/ref 接管。Winograd f32-only、depthwise f16-NHWC-3x3 是明确能力边界而非错误接受。
- 已核对历史修复承接：#1677（pooling 初值）、#3457（default 顺序+空窗口）、#4637（im2col width padding）、#5162（BRGEMM bias 预初始化）、#5174（alpha 消费）、#5370（pooling/eltwise/bnorm/binary/conv 的 min/max NaN）、#5394（dwconv 属性 gate）、#5594（`dim_t` counters）。
- finding：静态高置信 RV64-001（PReLU，见 elementwise 节）；静态确认 RV64-003 影响 BF16 BRGEMM conv 消费者（见 `draft-matmul-gemm-reorder.md`）。
- 未升级候选：1x1 conv `get_wei_tag()` 对非标准 VLEN 经 `get_vlen_implementation_id` 可能得到 -1 且未检查（`jit_rvv_1x1_convolution.hpp:173-186`，`utils::pick` 无边界检查）；对声明支持的 128 起幂次 VLEN 硬件不触发，列为低置信观察项。
- 观察项：`jit_rvv_1x1_convolution.hpp:192-196` primitive `init()` 对已构造（构造函数内已 `create_kernel()`）的 kernel 再次 `create_kernel()`，重复生成浪费 code buffer；构造时第一次 status 被丢弃，与 C-JIT-1 同类。

## 6. 未来动态验证（不执行）

1. verbose 确认 conv/pooling 实际命中 RV64 JIT 后，运行含左右不对称 padding、空窗口、dilation、stride>1、tail、group 的矩阵。
2. bf16/f16 BRGEMM/1x1/dwconv 的窄 dtype 组合与 `brgemm:rvv_zvfbfwma` 栈对齐复核（RV64-003）。
3. PReLU NaN/signed-zero/无限 weight case（RV64-001）与 pooling/eltwise NaN/±INF/±0 回归，并按维护者确认的特殊值契约决定是否升级。
