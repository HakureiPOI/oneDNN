# RV64 静态缺陷审计记录：MatMul / GEMM / BRGEMM / inner product / reorder

- 产品基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`；文档 HEAD `529c7247f524902377455c62ab283b44918e285c`。
- 说明：本文档由主审计按台账方法直接静态追踪 MatMul/GEMM/BRGEMM/inner-product/reorder。未构建、未运行动态测试，未修改产品源码。

## 1. 注册与 dispatch（A0）

- MatMul：`src/cpu/matmul/cpu_matmul_list.cpp:98-105` 顺序为 `rvv_brgemm_matmul_t`、`rvv_matmul_t`、shared `gemm_f32_matmul_t`、`gemm_bf16_matmul_t<f32/bf16>`、`gemm_x8s8s32x_matmul_t`、`ref_matmul_t`、`ref_matmul_int8_t`（另有 x64/zen/sparse 条目）。RV64 两个候选位于 shared GEMM/ref 之前；PD 失败时正常回落。
- Inner product：`src/cpu/cpu_inner_product_list.cpp` 按 dtype 分组：
  - f32：`rvv_brgemm_inner_product_fwd_t`、`rvv_gemm_inner_product_fwd_t`、shared `gemm_inner_product_fwd_t<f32>`、ref（`:62-65`）；
  - bf16：`rvv_brgemm_inner_product_fwd_t` 后 ref（`:74-75`）；
  - f16：`rvv_brgemm_inner_product_fwd_t` 后 ref（`:81-82`）；
  - int8：`rvv_inner_product_fwd_t`、`gemm_x8s8s32x_inner_product_fwd_t`、ref（`:128-130`）。
  - backward data/weights 无 RV64 专用条目，走 shared GEMM/ref（`:92-123`）。
- Reorder：`src/cpu/reorder/cpu_reorder_regular_f32_f32.cpp:42-43,62-63,100-101,155-156,210-211`、`f32_s8/u8/s32/s8/u8`、`f32_f16/f32_bf16/bf16/f16`、compensation `f32_s8/s8_s8` 等 map 中 `DNNL_RV64_ONLY(CPU_REORDER_INSTANCE(rv64::jit_uni_reorder_t))`；f32 系列同时注册 `jit_blk_reorder_t`。每条按 dtype/格式分组，先优化后 simple/reference。
- GEMM API：`src/cpu/gemm/gemm.cpp` 按 dtype 路由到 `rv64/gemm/rvv_gemm_{f32,f16,s8s8s32}`；RV64 PD/驱动失败时共享 ref 路径接管。

## 2. MatMul PD（A1）

`src/cpu/rv64/rvv_matmul.hpp:47-163`（direct RVV MatMul）：

- ISA：`mayiuse(v)`（`:51`）；f16/bf16 dst 或 HP path 分别要求 `zvfh`/`zvfbfwma`（`:90-98`）。
- 维度：拒绝 zero-dim 与 runtime dims/strides（`:58-63`）。
- dtype 分路：f32 path、int8 path（`(s8|u8)x(s8|u8)->(s32|f32|s8|u8|f16|bf16)`，acc s32）、HP path（f16/bf16 同 dtype，acc f32）（`:78-103`）。
- 属性：f32 path 允许 post-op（经 `jit_uni_postops_kernel_t::post_ops_supported` + `binary_per_last_dim_ok` 精确 gate，`:106-138`）；int8/HP path 拒绝非默认属性/HP 拒绝 bias（`:99-109`）。#4197 的 dropout 静默接受模式已由 skip-mask 消除。
- 布局：`set_default_formats()` 与 `attr_.set_default_formats(dst)` 先于 layout/post-op 检查（`:111-118`，#3457 顺序不变量满足）；`check_layouts()` 要求 src/dst row-major、weights row/column-major（`:198-204`，#4445 修复后 `weights_col_major_` 被保存并传入 `make_gemm_axes()`）。
- batch/broadcast：weights batch 维逐维 1 或匹配（`:143-154`）；`weights_are_broadcast_` 记录广播形态。
- scratchpad：`init_scratchpad()` 在 PD 内 booking；HP path 需要 packing/临时区，int8 需要 compensation。

`src/cpu/rv64/rvv_brgemm_matmul.cpp:179-275`（BRGEMM MatMul）：

- `isa_` 按 src dtype 设为 `zvfh/zvfbfwma/v`（verbose 名称）；dtype gate 要求 same-in-dt 且 f32/bf16(Zvfbfwma)/f16(Zvfh)。
- int8 path 拒绝 post-op/scales/zero-points（`:241-246`）；非 int8 拒绝非默认 attr（f32 允许 post-op 子集，`:250`）。
- packing、BRGEMM tile、post-op injector、scratchpad 由 `init()`/`init_scratchpad()` 建立；bias/beta/sum 语义见第 4 节。

## 3. GEMM/BRGEMM kernel 与共享层（A2/A4）

- f32 GEMM：`rv64/gemm/rvv_gemm_f32.cpp` 驱动 + `jit_rvv_gemm_kernel.cpp`（`n_cols` 1..6、transA/transB、bias 四组合 static table，`std::call_once` 初始化，`:352-390`）。`block_ker` 按 `m_unroll/n_unroll` 分 tile，tail 走窄 kernel（`rvv_gemm_f32.cpp:120-155`）。`brg.bdb/bdb_tail` 由 `get_platform_vlen()` 推导（`brgemm.cpp:83-90`）。
- f16/bf16 GEMM：`jit_rvv_gemm_f16_kernel.cpp`（`is_bf16_` 分支使用 `vfwmaccbf16/vfwcvtbf16`）；s8：`jit_rvv_gemm_s8_kernel.cpp`（饱和边界 `vfmax/vfmin` 后 `vfcvt`，属整数转换 clamp，非 NaN 语义缺陷）。
- BRGEMM：`rv64/brgemm/brgemm.cpp:99-124` 按 dtype 选择 f32/bf16/f16/s8 kernel 类并传播 `create_kernel()` status；`brgemm_kernel_execute` 为统一入口。
- **正式 finding RV64-003**：`jit_brgemm_kernel.cpp:876-882,1163-1169` BF16 kernel `addi(sp,sp,-56)`/`+56`（保存 s0-s5 六个 callee-saved 寄存器），违反 RV64 LP64 16-byte 栈对齐；同文件 f32/f16 用 48 字节、s8 用 32 字节对齐帧（`:99/396/493/776/1273`）。所有 BF16 BRGEMM 消费者（MatMul/inner product/convolution）共享该生成代码。详见 `audit/findings/RV64-003-bf16-brgemm-stack-alignment.md`。
- 生命周期候选（未升级）：`jit_rvv_gemm_kernel.cpp:32-40` 等构造函数丢弃 `create_kernel()` 返回值，static table 仅保存指针；正常 codegen 不触发，需注入失败才能闭环（与 softmax/resampling 的 C-JIT-1 同类，不重复计数）。
- f32 GEMM workspace：`malloc(nthr*ws_size_per_thr)` 失败时降级 `do_copy=false`（`rvv_gemm_f32.cpp:285-290`），无强制越界。

## 4. bias / beta / sum / post-op（A3）

- BRGEMM convolution：`rvv_brgemm_conv.cpp:175-183` 在 `!with_sum` 时预初始化完整 `OW x OC` 输出（有 bias 填 bias、无 bias 填零），`:217-218` 所有有效 BRGEMM 用 `beta=1.0f`，`:223-228` 仅 `with_sum && with_bias` 时补 bias——#5162 的"每个输出恰好一次 bias"不变量满足。
- BRGEMM wrapper：`brgemm.cpp:155-175` 仅 `kb==0` 时对每个 M tile 传 bias；inner product 调用点 `rvv_brgemm_inner_product.cpp:180-181,210` 按 tile/KB 传 bias。
- direct MatMul：`rvv_matmul.cpp:138-147` `make_gemm_axes()` 按 `weights_col_major_` 设置 `transa/lda`（#4445 修复模式），`:191-193` 将状态传入 f32/int8/HP GEMM；post-op 由统一 `jit_uni_postops_kernel` 逐行执行（first/last K 语义由 GEMM beta 控制）。
- 偏移/宽度：`rvv_matmul.cpp:41-95,164-205` 保存 init 时 partition 并在 execute 传回；`rvv_brgemm_conv_utils.cpp:2248-2260` weights reduction 使用 `dim_t`（#5594 修复承接）。

## 5. inner product（A1/A3）

- `rvv_inner_product.hpp:47-50`：`mayiuse(v)` gate；`rvv_gemm_inner_product.hpp:67` 与 `rvv_brgemm_inner_product.cpp:59-62` 要求默认属性（f32 GEMM IP 无 post-op，未支持即拒绝，符合 #4197/#5394 不变量）。
- `rvv_inner_product.cpp:163-182`：scratchpad 按 max threads booking，execute 按 `ithr` 分片（#5839 同族生命周期模式）。
- dot kernel `jit_rvv_inner_product_kernel.cpp`：s8/s8 widen 后 `vfredusum`/标量累加；f16 dot 同族。未发现可静态证明的 tail 观察缺陷（该 kernel 每轮 `vsetvli` 与累加同步，无 reduction 式全量重读）。

## 6. reorder（A1/A3/A4）

- PD/utility：`rv64/reorder/jit_uni_reorder_utils.cpp:312-313` 拒绝非默认 scales/zero-points/post-op（s8 compensation 等特殊组合另在各自 map 中处理）；`:377-391` 解析 src/dst scales mask 与 zero-points。
- `#5675`（block-64 plain/blocked 路由）：`8533027cc` 将 block-64 路由到 general kernel，当前 `cpu_reorder_regular_f32_f32.cpp` 的注册顺序已体现（`jit_blk_reorder_t` 与 `jit_uni_reorder_t` 并列按格式分组）。
- scales 预计算：`jit_uni_reorder.cpp:195-204` booking `D_mask_ * nthr_` 的 `key_reorder_precomputed_dst_scales`；`:632-638` execute 按 `ithr * D_mask_` 分片、`dim_t i` 循环（#5594 修复承接）。
- 饱和：`jit_uni_reorder_kernel.cpp:269-328,488-495` 在整数转换前 clamp 到 `[-2147483648, 2147483520]` 等 reference 相同边界后 `vfcvt`——`vfmin/vfmax` 在此为整数范围饱和，非 #5370 浮点 NaN 语义，排除。
- `reorder/jit_uni_reorder.cpp:177-192` compensation workspace booking 使用 `rnd_up(G*N,16)*sizeof(int32_t)` 后又经 `book<int32_t>` 重复乘 4（execute 按 int32 stride 使用）：跨架构共享模式（x64/aarch64 同形），至少 4x 过量分配但非越界；记录为共享资源观察项，不计 RV64 finding。

## 7. 差异处置汇总

- 等价/合法架构差异：RV64 MatMul/IP/reorder 支持域窄于 x64（无 bf16 accum 配置、无部分 blocked、无 sparse/zen）；PD 显式 `unimplemented` 后回落 shared/ref。
- 已修复历史模式核对：#4197（属性 skip-mask）、#4445（column-major `transa/lda`）、#5162（BRGEMM bias 预初始化）、#5594（`dim_t` counters）、#5675（block-64 路由）在当前代码均有承接。
- 正式 finding：RV64-003（BF16 BRGEMM 栈对齐）。
- 未升级候选：JIT 构造丢弃 `create_kernel()` status（需注入 codegen/ready/getCode 失败）；reorder compensation 过量 booking（共享、非越界）；`get_platform_vlen()` 在 `platform.cpp` 无 RV64 分支返回 0，仅被 `rvv_gemm_convolution_utils.cpp:1231-1233` 以 `max(0,4)` 消费，属 heuristic/性能观察项。

## 8. 未来动态验证（不执行）

1. BF16 BRGEMM（RV64-003）：verbose 确认 `brgemm:rvv_zvfbfwma` 后运行最小 BF16 MatMul/IP/conv case，反汇编 JIT dump 核对 prologue/epilogue 帧；必要时使用仅供验证的嵌套 ABI 调用或显式 16-byte 对齐访问使违约可观察，不把当前 leaf kernel 的普通数值运行当作必然崩溃。
2. GEMM tail/broadcast：M/N/K 含 1、非整除 unroll、broadcast weights、column-major weights、非连续 stride 拒绝验证。
3. Reorder：scales/zero-points/compensation 组合、block-64、大 `D_mask_`、多线程 per-thread 分片一致性。
