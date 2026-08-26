# RV64 静态覆盖台账

- 审计日期：2026-08-26
- 产品代码基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 当前文档 HEAD：`529c7247f524902377455c62ab283b44918e285c`
- 分支：`audit/riscv-defect-audit`
- 基线差异：`git diff 8f49eae32..HEAD -- ':(exclude)audit/**'` 为空；当前产品代码与文档声明基线一致。
- 审计模式：仅静态；没有构建、benchdnn、ctest、QEMU、sanitizer、硬件或性能执行。
- 主机：x86_64 WSL2，16 logical CPUs；`PATH` 中未发现 `cc`、`c++`、`riscv64-linux-gnu-gcc`、`qemu-riscv64` 或 `cmake`。没有 RV64 硬件/QEMU/可用 RVV ISA/VLEN 运行证据。

## 清单口径

实现名以注册表宏参数和 `DECLARE_COMMON_PD_T` 为准；同一模板按注册位置、propagation kind 和 ISA 实例分别计入。注册候选返回 `unimplemented` 时由后续实现继续接管，不把正常 fallback 计为缺陷。实现链采用：注册表 -> PD `init()` -> primitive `init()`/配置 -> `execute()` -> kernel/injector。

## Primitive 注册覆盖

| Primitive / 注册位置 | RV64 实现及顺序 | PD/ISA/执行路径与共同参照 | 静态状态 |
|---|---|---|---|
| Batch normalization, `src/cpu/cpu_batch_normalization_list.cpp:50-76` | fwd `jit_uni_batch_normalization_fwd_t<v>`, `<zvfh>`；bwd `jit_uni_batch_normalization_bwd_t<v>`, `<zvfh>` (`:79-99`) | `jit_uni_batch_normalization.hpp/.cpp` -> `jit_uni_batch_normalization_kernel.cpp`；x64 `jit_uni_batch_normalization*`；ncsp/nspc/ref fallback。fwd/bwd、f32/f16、V/Zvfh；PD 默认属性和 layout gate。 | 已审；方法 A 等价/架构差异；历史 #5370 当前 NaN mask 修复覆盖。动态未运行。 |
| Binary, `cpu_binary_list.cpp:45` | `jit_uni_binary_t` | `jit_uni_binary.hpp/.cpp` -> RVV binary kernel/injectors；x64 `jit_uni_binary`、ref。f32/f16/bf16/s32/s8/u8 混合，V/Zvfh/Zvfbfwma；broadcast、per-tensor scales、sum/eltwise/binary post-op。 | 已审；属性 gate 与 NaN-preserving min/max 已有；BF16 最近扩展需动态验证。 |
| Convolution fwd fp, `cpu_convolution_list.cpp:139-144` | `jit_rvv_1x1_convolution_fwd_t`, `rvv_wino_convolution_fwd_t`, `rvv_brgemm_convolution_fwd_t`, `riscv_gemm_convolution_fwd_t`, 后接 shared GEMM/ref | 1x1、Winograd、BRGEMM、GEMM；各自 PD/config/execute/kernel；x64 direct/BRGEMM/ref。padding、groups、post-op、bias、dtype 按 PD。 | 已审；#4637/#5162/#5394 当前 guard/初始化模式已核对；SMOKE 跳过部分 conv。 |
| Convolution fwd bf/f16/depthwise, `cpu_convolution_list.cpp:178-215` | bf16/f16 BRGEMM/1x1；F16 depthwise `jit_uni_dwconv_fwd_t`；列表顺序按 dtype/layout 分组 | `rvv_brgemm_conv*`, `jit_rvv_1x1_convolution*`, `jit_uni_dwconv*`; x64/reference fallback。V/Zvfh/Zvfbfwma 由 PD。 | 已审；#5394 属性过度接受已修复；需动态覆盖窄 dtype 与 padding/tail。 |
| Eltwise, `cpu_eltwise_list.cpp:67-86` | fwd/bwd `jit_uni_eltwise_{fwd,bwd}_t<v/zvfh/zvfbfwma>` | `jit_uni_eltwise.hpp/.cpp` -> `injectors/jit_uni_eltwise_injector`；x64 `jit_uni_eltwise`、ref。PD 只接受 injector 支持的算法和默认属性，ISA/dtype gate。 | 已审；#5174 参数传播、#5370 clamp/ReLU/ELU NaN 处理已核对。 |
| Group normalization, `cpu_group_normalization_list.cpp:44-50` | `jit_uni_group_normalization_fwd_t` | `jit_uni_group_normalization.hpp/.cpp` -> stat/norm kernels；x64 JIT、ncsp/ref。fwd、V、支持的 f32/f16、binary/post-op gate、per-thread scratchpad。 | 已审；资源失败路径有 `CHECK`；动态未运行。 |
| Inner product fwd, `cpu_inner_product_list.cpp:62-87` | `rvv_brgemm_inner_product_fwd_t`, `rvv_gemm_inner_product_fwd_t`；窄 dtype分组 `rvv_brgemm_inner_product_fwd_t`; direct `rvv_inner_product_fwd_t` (`:128`) | RVV BRGEMM/GEMM/direct -> kernel；x64 GEMM/BRGEMM/ref。fwd、f32/bf16/f16/int8 分组，bias/attr/layout 各 PD gate；bwd 共享 GEMM/ref。 | 已审；#5162 bias 语义与 #5594 宽度已核对；动态未运行。 |
| Layer normalization, `cpu_layer_normalization_list.cpp:49-57` | `rvv_layer_normalization_fwd_t` | `rvv_layer_normalization.cpp` -> `jit_rvv_layernorm_kernel`；x64/simple/ref。fwd、f32/f16、scale/shift、fused post-op gate、NaN fix。 | 已审；历史 NaN 修复和 V gate 已核对。 |
| MatMul, `src/cpu/matmul/cpu_matmul_list.cpp:98-105` | `rvv_brgemm_matmul_t`, `rvv_matmul_t` | `rvv_brgemm_matmul.cpp` -> `rv64/brgemm`; `rvv_matmul.cpp` -> RVV GEMM/direct；x64 BRGEMM/GEMM/ref。batch/broadcast, row/column weights, transpose, f32/f16/bf16/int8, bias/post-op/scales/zp gate。 | 已审；#4197 dropout、#4445 column-major 已修复并搜索扩散。 |
| Pooling fwd/bwd, `cpu_pooling_list.cpp:63-102` | `jit_uni_pooling_{fwd,bwd}_t<v/zvfh/zvfbfwma>` | `jit_uni_pooling.hpp/.cpp` -> `jit_uni_pool_kernel`；x64 JIT/ref。max/avg、NCHW/NHWC、padding/empty window、f32/f16/bf16，V/Zvfh/Zvfbfwma。 | 已审；#1677/#3457/#5370 当前承接 guard 已核对；SMOKE 跳过 fwd/bwd。 |
| PReLU, `cpu_prelu_list.cpp:45-56` | fwd `jit_uni_prelu_fwd_t`; bwd ref | `jit_uni_prelu.hpp/.cpp` -> `emit_prelu_loop`；x64/aarch64/ref。f32/f16/bf16、full/scalar/per-oc plain/blocked broadcast，V/Zvfh/Zvfbfwma。 | **静态高置信 finding RV64-001**：JIT `vfmax/vfmin` 分解在 NaN 上与 reference/#5370 策略不同；公共 NaN 契约未闭环。 |
| Reduction, `cpu_reduction_list.cpp:40-41` | `jit_uni_reduction_t` | `jit_uni_reduction.hpp/.cpp` -> `jit_uni_reduction_kernel`；x64/ref。f32/f16、sum/mean/max/min，V/Zvfh，axis/layout 和 output initialization。 | **静态确认 RV64-002**：tail-agnostic accumulator 更新后以 VLMAX reduction，错误依赖 tail 保留；另有 max/min NaN 契约候选 R-1。 |
| Resampling, `cpu_resampling_list.cpp:46-55` | `jit_uni_resampling_fwd_t<zvfh>`, `<v>` | `jit_uni_resampling.hpp/.cpp` -> `jit_uni_resampling_kernel`；x64/simple/ref。nearest/linear、f32/f16、V/Zvfh、post-op injector gate、strides/tail。 | 已审；PD 先 default format 再 post-op 检查；动态未运行。 |
| Shuffle, `cpu_shuffle_list.cpp:48-49` | `jit_uni_shuffle_t` | `rv64/shuffle/jit_uni_shuffle`；x64/ref。fwd、支持的 f32/f16/bf16、V/ISA gate、blocked group layout。 | **静态确认 RV64-004**：合法 zero-batch descriptor 令 `tasks=0` 并进入 `div_up(nthr, tasks)`；动态未运行。 |
| Softmax, `cpu_softmax_list.cpp:49-50` | `rvv_softmax_fwd_t` | `rvv_softmax.cpp` -> f32/JIT and xf16 kernels；x64/ref。softmax/logsoftmax、axis/strides、f32/f16/bf16、`accurate_inf_as_zero`、NaN/INF、V/Zvfh/Zvfbfwma。 | 已审；#4890 全 `-INF` 当前显式处理，#5839 scratchpad 已核对；SMOKE 仅有 test_softmax。 |
| Reorder, shared maps | `DNNL_RV64_ONLY(CPU_REORDER_INSTANCE(rv64::jit_uni_reorder_t))` in f32/f16/bf16/s8/u8/s32 and compensation maps; `jit_blk_reorder_t` in plain f32 and integer maps | shared `src/cpu/reorder/cpu_reorder_*` -> `rv64/reorder/jit_uni_reorder`/`jit_blk_reorder` -> RVV reorder kernel；x64 reorder/ref/simple。dtype conversion, scales/zp/compensation/post-op gate、block-64 route。 | 已审；#5594 counter、#5675 block-64 routing、scale/zp gates 已核对；动态未运行。 |

## 共享基础设施覆盖

| 区域 | 入口与使用者 | 静态结论 |
|---|---|---|
| ISA/runtime | `rv64/cpu_isa_traits.hpp:51-135`, `.cpp:31-82`; `platform.cpp:128-180` | V、Zvfh、Zvfbfwma、VLEN 单例；PD `mayiuse` gates。默认 CMake baseline `rv64gc`。SIGILL probe 的全局 handler/jmp buffer 在并发或已有 SIGILL handler 情况下仍需动态确认，列入 C-ISA-1 候选。 |
| JIT base | `rv64/jit_generator.hpp:64-125` | 统一 `generate -> ready -> register_jit_code`，256 KiB 上限，失败状态通常向 PD/primitive 返回；但多处构造函数忽略 `create_kernel()` 返回值，需审计各消费者。 |
| Injectors | `rv64/injectors/{jit_uni_binary, jit_uni_eltwise, jit_uni_postops}_injector.*` | post-op capability 与执行链已核对；#5174/#5370 修复模式已搜索；`clip_v2` 的 maxNum 合同是合法例外。 |
| GEMM/BRGEMM | `rv64/gemm/*`, `rv64/brgemm/*`, `rvv_*matmul/conv/ip*` | f32/f16/bf16/s8 kernels、packing、bias/beta、tail 与 layout 解释已覆盖；**静态确认 RV64-003**：BF16 BRGEMM 使用 56-byte frame，违反 LP64 16-byte stack alignment；当前 leaf body 的运行时故障未证明。 |
| Scratchpad/thread/lifetime | softmax, normalization, convolution, reorder, BRGEMM | #5839 per-thread scratchpad、reorder scale precompute、BRGEMM workspace 生命周期已静态核对；未发现可严格证明的越界。 |
| Build/runtime assembly | `CMakeLists.txt:71-74`, `cmake/platform.cmake:122-137,315-316,426-427`, `src/CMakeLists.txt:41-43`, `rv64/CMakeLists.txt` | RV64 object 递归纳入，默认 `-march=rv64gc`，JIT 生成向量指令；历史 #3486/#4638 旧 compile-time intrinsic 路径已移除。显式用户 override 仍按契约生效。 |
| CI/weekly | `.github/workflows/ci-riscv.yml:67-188`, `weekly-riscv.yml:41-170` | PR SMOKE QEMU VLEN 128/256；weekly CI 仅 VLEN 128；均显式 V/Zvfh/Zvfbfwma。 |
| Skips | `.github/automation/riscv/skipped-tests.sh:27-56` | SMOKE 跳过 conv/pooling fwd/bwd、GEMM；CI 跳过 matmul/IP benchdnn；不能作为缺陷排除证据。 |

## 当前注册计数

- `CPU_INSTANCE_RV64`：注册表源文件中 41 次实际调用，覆盖 14 个 primitive 家族；原始文本搜索共 44 个命中，其中另含一处宏定义和两处注释。convolution、bnorm、eltwise、pooling、inner-product、matmul 等包含多方向/ISA 实例。
- `DNNL_RV64_ONLY`：reorder map 中 36 次直接 `CPU_REORDER_INSTANCE` 注册调用；计入 reorder 后，台账整体覆盖 15 个 primitive 家族。另有 `DNNL_RV64` 架构与平台 gate。
- RV64 文件：`src/cpu/rv64/` 当前由 CMake glob 递归编译，目录清单见 `rg --files`；没有注册候选的文件按共享 kernel/helper 影响面覆盖。

## 方法状态与未覆盖

上表按 14 个 `CPU_INSTANCE_RV64` 家族和一个 reorder 家族汇总静态入口与责任边界；每个模板/方向/ISA 注册实例可由表内源码位置继续追溯，但本表不把 41 个宏调用展开成 41 行。方法 A 的差异与方法 B 的 14 条历史谱系均在 `history-cards.md` 中有处置。最终状态为静态确认 3 项、静态高置信 1 项、候选类别 6 项；没有动态 implementation 名、QEMU 结果或真实 VLEN 证据。未来需在 QEMU/硬件中按 verbose 首次确认实际实现，再覆盖 VLEN 128/256/512/1024、无 V/单扩展、特殊值、padding/tail、非默认属性、大维度和线程矩阵。
