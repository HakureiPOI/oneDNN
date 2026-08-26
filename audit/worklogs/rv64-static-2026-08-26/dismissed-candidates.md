# RV64 静态审计排除与暂不升级记录

- 基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 当前文档 HEAD：`529c7247f524902377455c62ab283b44918e285c`
- 本阶段只做静态审计；未运行任何动态验证。

## 已排除的历史旧模式

- 候选：#1677 max pooling 初值。
  - 差异来源：旧 `rvv_nchw_pooling.cpp` 使用 `__FLT_MIN__`/零。
  - 排除结论：历史 bug 已由 `d4457d95b` 修复，旧文件又由 `96e81ccc8` 重构为 `jit_uni_pooling`。
  - 证据：当前 `jit_uni_pooling.cpp:54-78` 和 `jit_uni_pool_kernel.cpp:600-609` 使用 dtype lowest/合法空窗口值；未发现同触发 clone。
  - 重新开启条件：发现新 max path 使用最小正数/零 seed，或动态全负窗口错误。

- 候选：#3457 默认 format 顺序/空窗口。
  - 差异来源：历史先 `is_dense()` 后 default，以及空半开区间下溢。
  - 排除结论：当前 pooling PD `set_default_params()` 先于 dense；NCSP/NHWC/blocked kernel 逐路径保护空窗口并写算法值。
  - 证据：`jit_uni_pooling.hpp:82-88`、`jit_uni_pooling.cpp:195-200,283-288,379-386,486-493`。
  - 重新开启条件：新 primitive 在 default-format 或任一空间维度用 `end-start` 前缺少 `start>=end` guard。

- 候选：#3486 try-compile flags。
  - 差异来源：历史 CMake capability check 使用 ambient flags。
  - 排除结论：`d41e7b973` 删除 intrinsic-only compile-time selection；当前默认 baseline 为 `-march=rv64gc`，JIT 运行时探测。
  - 证据：`cmake/platform.cmake:122-137`、`src/cpu/rv64/cpu_isa_traits.hpp:104-115`。
  - 重新开启条件：恢复基于编译器 flags 的 RVV 源码过滤或发现 baseline translation unit 强制发射 V。

- 候选：#4197 dropout/属性过度接受。
  - 差异来源：旧 MatMul PD 接受 dropout 但 execute 不消费。
  - 排除结论：当前 MatMul/BRGEMM/IP/conv/depthwise 以 default-values 或精确 post-op gate 拒绝未实现属性，失败后正常 fallback。
  - 证据：`rvv_matmul.hpp:104-137`、`rvv_brgemm_matmul.cpp:241-251`、`jit_uni_dwconv.hpp:70-75`。
  - 重新开启条件：某 RV64 PD 对非默认 attr 返回 success，而 execute/kernel 无对应参数路径。

- 候选：#4445 column-major weights。
  - 差异来源：旧 MatMul 固定 `transa=N, lda=N`。
  - 排除结论：当前 layout 状态被保存并通过统一 GEMM axes 转换，非连续 layout 明确拒绝。
  - 证据：`rvv_matmul.hpp:165-203,249`、`rvv_matmul.cpp:138-147,191-193`。
  - 重新开启条件：新 dtype/BRGEMM consumer绕过 `make_gemm_axes()` 或固定 transpose/leading dimension。

- 候选：#4637 width-padding im2col。
  - 差异来源：旧 f32 vector copy 未检查左右 padding。
  - 排除结论：当前两个原始 vector path 都要求 `no_w_padding`；其他 path 先计算合法有效区并单独填充 padding。
  - 证据：`rvv_gemm_convolution_utils.cpp:429,457-475,535-552,674-687,716-727`。
  - 重新开启条件：任何 vector load 的连续区可能跨越 `lp`/`r_pad`，或回归 `min-max` 下溢。

- 候选：#4890 all `-INF` softmax。
  - 差异来源：`-INF - -INF` 产生 NaN。
  - 排除结论：f32/xf16/bf16 当前 `accurate_inf_as_zero` 都有 `all_minus_inf` zero path；普通 logsoftmax 不误用该特例。
  - 证据：`rvv_softmax.cpp:76-94,140-167,180-194,261-266`。
  - 重新开启条件：新 dtype 路径绕过算法开关，或全 `-INF` 仍进入 exp-sub-sum。

- 候选：#5174 ReLU alpha。
  - 差异来源：旧 helper 只实现 hard ReLU。
  - 排除结论：共享 eltwise/post-op injector、pooling/conv consumers 保存并消费 alpha；默认 alpha=0 的 fast path 仅是合法优化。
  - 证据：`jit_uni_eltwise_injector.cpp:291-307`、相关 post-op gate。
  - 重新开启条件：新融合 kernel只验证 alpha 但未传入/执行非零 alpha。

- 候选：#5394 f16 depthwise attrs。
  - 差异来源：无 injector 的 f16 depthwise 接受 post-op/scales/zp。
  - 排除结论：当前 `jit_uni_dwconv.hpp:70-75` 要求 `attr()->has_default_values()`。
  - 证据：列表在 `cpu_convolution_list.cpp:201-204` 中失败后保留 fallback；测试 skip 是覆盖缺口，不是当前接受域证据。
  - 重新开启条件：任何窄 dtype、无 injector RV64 kernel 缺少完整 attr gate。

- 候选：#5594 int counter/dim_t。
  - 差异来源：旧 conv/reorder loops 使用 int 与 dim_t bound。
  - 排除结论：历史目标 loops 已改为 dim_t；当前剩余 `int` 多为 `ndims`、`po.len()`、静态 blocking 配置，不具备同一可达范围。
  - 证据：`584b59a27` diff；当前 `rvv_gemm_convolution.cpp` 和 reorder scale loop；未发现同条件当前 clone。
  - 重新开启条件：证明某剩余 int counter 的 bound 来自用户可达 dim_t/大 scratch size。

## 正确架构差异/正常 fallback

- 候选：RV64 softmax/reduction/resampling/shuffle 比 x64 支持更窄。
  - 排除结论：RV64 PD 明确返回 `unimplemented`，后续 simple/reference 接管；能力缩小本身不是 correctness bug。
  - 证据：各列表顺序和 `VDISPATCH_*` gate；软最大 backward 等没有 RV64 注册是明确覆盖边界。

- 候选：RV64 与 x64 使用不同 blocked/tile/VLEN/寄存器布局。
  - 排除结论：属于合法架构实现差异；只有 observable semantics、安全边界或 API contract 被破坏才升级。
  - 证据：指导书 A0-A4 规则；当前多数 JIT 采用动态 VL，并对 layout 做明确 gate。

- 候选：`jit_uni_eltwise_injector.cpp:533-538` 和 reorder/integer clamp 的裸 `vfmin/vfmax`。
  - 排除结论：`clip_v2` 明确要求 maxNum/minNum 语义；整数转换前 clamp 是饱和边界，不是保留 NaN 的浮点算法。
  - 证据：注释、目标 dtype 及后续 `vfcvt` 消费不同；不满足 #5370 相同前置条件。

- 候选：#5839 softmax heap 临时缓冲。
  - 排除结论：这是性能/维护改进，不是已有 correctness bug；当前 scratchpad key、容量和 worker 分片闭环。
  - 证据：`rvv_softmax.hpp:134-157` 与 `rvv_softmax.cpp:210-249`；指导书明确要求如实区分。

- 候选：#5162 BRGEMM bias。
  - 排除结论：问题在 #5150 review/整合期修正，没有独立合并坏提交；当前 output preinit 和 per-tile bias 分工满足不变量。
  - 证据：`rvv_brgemm_conv.cpp:175-183,217-228`、shared wrapper `brgemm.cpp:155-175`。

- 候选：#4638 无 V/旧 V SIGILL。
  - 排除结论：旧全局 RVV compile path 已迁移为 baseline + runtime JIT；当前没有静态证据证明 baseline 必然发射 V。
  - 证据：`d41e7b973` diff、当前 CMake/ISA gate；无 V/真实硬件仍属未覆盖动态矩阵。

## 当前候选但未升级

- 候选：softmax/resampling/GEMM JIT 构造函数丢弃 `create_kernel()` status。
  - 差异来源：`jit_rvv_softmax_kernel.cpp:84-87,138-147,194-197,425-428,564-567`、`jit_uni_resampling_kernel.cpp:34-42`、GEMM static table constructor。
  - 暂不升级：需要合法、可达的 Xbyak generate/ready/getCode failure；普通成功 codegen 不触发。静态代码证明错误传播不完整，但不能仅凭假设的资源失败声称已崩溃。
  - 重新开启条件：受控 codegen failure 或 sanitizer 证明 primitive creation success 后 execute 跳转 null。

- 候选：BF16 SIGILL probe 的 process-wide handler/jmp buffer。
  - 差异来源：`cpu_isa_traits.cpp:40-67` 全局 `sigjmp_buf` 与临时 `sigaction(SIGILL)`。
  - 暂不升级：只在 singleton 初始化时执行，未有动态并发触发证据；确实需要与已有 SIGILL handler/其他线程同步验证。
  - 重新开启条件：并发初始化/外部 SIGILL handler 场景导致错误跳转、handler 丢失或进程终止。

- 候选：reduction max/min NaN。
  - 差异来源：`jit_uni_reduction_kernel.cpp:182-183,224-236` 直接 `vfmax/vfmin/vfredmax/min`，历史 #5370 要求按算法明确 NaN 合同。
  - 暂不升级：oneDNN reduction 的公开 NaN contract 与 reference operand-order 语义尚未在本地资料中闭环；不能把 #5370 同族命中直接当 finding。
  - 重新开启条件：API/reference 明确要求 NaN propagation，且 RVV reduction 结果与其不同的最小合法 case。

- 候选：softmax plain padded output lane。
  - 差异来源：`is_dense(true)` plain descriptor 与 x64 显式 padding lane 处理不同。
  - 暂不升级：plain padded descriptor 的 user-facing 合法性及 `src_d==dst_d` 可达组合未被静态完全证明；可能是正确拒绝/不观察 padding。
  - 重新开启条件：证明合法 out-of-place padded descriptor 可到达，并且 API 要求 output padding 清零/保持而 RV64 未满足。

- 候选：shuffle f16/bf16 在 V-only 上的过度拒绝。
  - 差异来源：`shuffle/jit_uni_shuffle.hpp:79-82` 统一使用 `platform::has_data_type_support(dt)`，而 kernel 仅搬运 e16。
  - 暂不升级：尚未证明公共平台契约允许无 Zvfh/Zvfbfwma 的 raw 16-bit shuffle；影响主要是 availability/fallback。
  - 重新开启条件：API/platform 明确规定 raw memory move 不需要转换扩展，且应在 V-only 上可达。

- 候选：1x1 convolution 非标准 VLEN implementation id。
  - 差异来源：`jit_rvv_1x1_convolution.hpp:173-186` 的 `get_vlen_implementation_id()` 可能返回 `-1`，随后作为索引进入 `utils::pick`，调用点没有显式边界检查。
  - 暂不升级：当前声明支持的 128 起幂次 VLEN 映射到有效 id；尚未证明合法、受支持的运行时 VLEN 会得到 `-1`。
  - 重新开启条件：真实硬件/运行时可报告被 oneDNN 接受但不在映射表中的 VLEN，或静态证明 `-1` 可沿当前 PD gate 到达索引。

- 候选：shuffle zero-task division（已升级）。
  - 差异来源：`shuffle/jit_uni_shuffle.cpp:191-195` 计算 `div_up((dim_t)nthr,tasks)`，`tasks=MB*nb_c`。
  - 处置：`memory_desc.cpp:48-63` 允许零维，`shuffle.cpp:53-54` 不约束 MB，RV64 PD 无 zero-dim gate；合法 `MB=0,C>0,SP>0` 可达并导致 `div_up(nthr,0)`。oneDNN 公共文档支持 zero-volume memory 且要求不访问其 buffer。正式 finding 为 `RV64-004`。

## 正式 finding

- `RV64-001`（静态高置信）：PReLU JIT 裸 min/max 分解将 NaN 输入变为零；跨 reference/RVV 指令结果和历史 #5370 策略的差异确定，但 oneDNN 公共文档不保证 NaN 输入结果，不能写成已确认 API 违约。
- `RV64-002`（静态确认）：reduction 在 tail-agnostic 更新后以 VLMAX 横向读取 accumulator；RVV 允许 tail 保留旧值或被写成全 1，当前代码错误依赖旧贡献保留。已具备 RVV policy、数据流和可达形状证据。
- `RV64-003`：BF16 BRGEMM JIT 56-byte frame 违反 RV64 LP64 16-byte stack alignment；已具备可达 BF16 factory、同文件 sibling frame 和 ABI 规范证据。
- `RV64-004`：shuffle 合法 zero-batch descriptor 在 `div_up` 中使用零 divisor；已具备 public zero-volume contract、descriptor、PD 和 execute/helper 前置条件证据。
