# RV64 历史修复扩散缺陷卡

- 基线：产品代码 `8f49eae32bdec3674a9a98ea1524a85cd1f302db`；文档 HEAD `529c7247f524902377455c62ab283b44918e285c`。
- 方法：每条谱系均使用本地 `git log/show/blame/log -S/-G` 与 `rg`，沿语法 clone、结构 clone、dtype/layout/方向/融合语义同族、时间邻域、PD-config-helper-kernel-consumer 调用图邻域搜索。相似代码只生成候选，不直接判定缺陷。
- 本阶段不构建、不执行动态测试；所有当前代码结论均为静态处置。

## HC-1677：max/reduction 初值

- 引入：`890ebdf5b` 新增 RVV NCHW pooling，使用 `__FLT_MIN__`/零作为 max 初值。
- 修复：`d4457d95b`；症状是全负 max pooling 输出接近零；修复为最低有限值/正确 reduction seed。
- 触发：f32 max pooling，全负窗口，尤其值小于 `-FLT_MIN`。
- 根因/不变量：max seed 必须是算法边界或单位元，最小正数/零不能代表负输入集合。
- negative/fix：`__FLT_MIN__ -> -__FLT_MAX__`，zero reduction seed -> min boundary；修复未单独增加回归测试。
- 逃逸：常规随机输入和非负数据未覆盖全负窗口；早期 CI 重点不在 RV64。
- 五邻域：当前 `jit_uni_pooling.cpp:54-78`、`jit_uni_pool_kernel.cpp:600-609` 使用 dtype lowest；`jit_uni_reduction_kernel.cpp:145-157` 使用 -inf/+inf；softmax 使用 -inf；旧 NCHW 文件已被 `96e81ccc8` 重构替代。没有相同前置条件的当前 clone。
- 上下游：pooling list -> `jit_uni_pooling.hpp/.cpp` -> pool kernel；reference fallback 保留。
- 当前处置：历史已确认；当前旧模式已排除，不创建 finding。

## HC-3457：默认 format 顺序与空窗口

- 引入/演进：早期 pooling `890ebdf5b`，平均 pooling `84e4a9668`，问题在默认 layout predicate 和 padding/stride 空窗口路径。
- 修复：`f4244c675`；`set_default_params()` 先于 `is_dense()`；显式保护 `iw_start >= iw_end`，空窗口写算法值并返回。
- 触发/症状：`any` format 先做 dense 检查导致错误 fallback；空窗口的 `min-max` 转 unsigned 下溢导致错误长度、越界/段错误。
- 不变量：布局必须先解析；空半开区间不能被当成可读窗口。
- 五邻域：当前 pooling PD `jit_uni_pooling.hpp:82-88` 先 default 再 dense；NCSP/NHWC/blocked 路径分别处理空窗口；softmax/resampling 也遵守 default-first；未发现旧顺序或未保护 window 的可达复本。
- 逃逸：特殊 padding/stride 形状不在早期常规 case；SMOKE 仍跳过 pooling。
- 上下游：pool list -> PD config -> execute -> kernel；失败正确 fallback reference。
- 当前处置：历史已确认内存安全/路由 bug；当前已排除。

## HC-3486：能力试编译 flags

- 引入：`18d004359` 动态选择 `-march`，try-compile 依赖 ambient `CMAKE_REQUIRED_FLAGS`。
- 修复：`e9d697577`，显式设置并恢复 `-march=rv64gcv`；后续 `64ce535` 的 Zvfh 检测沿用保存/恢复模式。
- 触发：编译器支持 RVV 但默认 flags 不含 V，或用户 override 与检测环境不一致。
- 不变量：试编译必须使用待验证的确切 ISA flags，并恢复调用者上下文。
- 五邻域：当前 `d41e7b973` 删除 intrinsic-only source filtering，`cmake/platform.cmake:122-137` 默认 rv64gc；运行时 `mayiuse` 取代旧编译能力选择。当前不存在旧 try-compile 结构。
- 逃逸：早期构建矩阵没有覆盖编译器默认 ISA/用户 override。
- 上下游：CMake -> RV64 object -> registration -> PD gate -> JIT；显式 `DNNL_ARCH_OPT_FLAGS` 是公开 override，不自动判缺陷。
- 当前处置：历史构建 bug；当前旧路径已排除，仍需动态验证 override 语义。

## HC-4197：MatMul dropout/属性过度接受

- 引入：`c407a618` RVV row/column MatMul 初版未 gate dropout；`ed3c77be9` 添加 dropout 检查，`f2286a070` 统一 skip-mask 检查。
- 触发：RV64 f32 MatMul 带非默认 dropout，PD 成功但 execute 只做 GEMM/bias/post-op。
- 症状：静默错误结果；根因是接受域大于 kernel 消费域。
- 不变量：PD 不能接受执行阶段没有消费的属性；不支持必须 `unimplemented` 让列表继续。
- negative/fix：缺少 `dropout_.has_default_values()`/精确 skip mask -> 增加 gate 并允许合法 fallback。
- 五邻域：当前 `rvv_matmul.hpp:104-137`、`rvv_brgemm_matmul.cpp:241-251`、`rvv_brgemm_inner_product.cpp:59-62`、conv/depthwise/pooling 相关 PD 都有属性 gate；有 injector 的实现使用 `post_ops_ok()`，无 injector 的实现要求 default values。未发现相同接受/消费缺口。
- 逃逸：默认属性测试无法改变接受域。
- 上下游：matmul list -> PD -> kernel/post-op；reference/GEMM fallback 正常。
- 当前处置：历史已确认；当前排除。

## HC-4445：column-major weights

- 引入：`b73fc3172`（#4363 集成 GEMM）固定 `transa=N, lda=N`，但 PD 接受 column-major weights。
- 修复：`914ba0473` 添加 `weights_col_major_`；column-major 使用 `transa=T, lda=K`。
- 触发：合法 column-major weights，尤其 K != N；症状为错误矩阵结果。
- 不变量：descriptor layout、逻辑矩阵形状、leading dimension 和 transpose 必须一致。
- 五邻域：当前 `rvv_matmul.hpp:165-203,249` 记录 layout 状态；`rvv_matmul.cpp:138-147,191-193` 统一 `make_gemm_axes()` 并传入 f32/int8/half 路径；非连续 layout 被拒绝，batch broadcast 单独处理。未发现遗留固定 transpose clone。
- 逃逸：早期矩阵常为 row-major 或对称尺寸，且无专门回归测试。
- 当前处置：历史已确认；当前排除。

## HC-4637：im2col width padding

- 引入：`b6282ee21` 按 f32/宽度直接 vector copy，没有验证左右 padding。
- 修复：`2808deea3` 增加 `no_w_padding=(lp==0 && r_pad==0)`，padding 时回退标量，并修正基址。
- 触发：GEMM convolution f32 im2col，width padding，足够宽触发 vector path；症状错误结果/OOB read。
- 不变量：向量 load 必须完全处于有效连续输入区；padding/边界走受控路径。
- 五邻域：当前 `rvv_gemm_convolution_utils.cpp:429,457-475,535-552` 两个原始 vector path 均有 guard；其他 vector path 先划分 `ow_start/ow_end`，padding 另行填充；未发现同条件缺 guard。
- 逃逸：大宽度和 padding 组合稀少；修复曾重新启用 CI case。
- 当前处置：历史已确认；当前排除。

## HC-4890：softmax 全 `-INF`

- 引入：`25cd4a750` f32、`97eb3d879` f16、`3c8c37bab` f16 JIT exp。
- 修复：`d4edf8b78`；`all_minus_inf` 时写零，`sum_exp==0` 时 `inv_sum=1`，避免 `-INF - -INF` NaN。
- 触发：`softmax_accurate_inf_as_zero` 的整行 `-INF`。
- 不变量：特殊值分支必须早于无效中间结果；该算法要求全 `-INF` 输出零。
- 五邻域：当前 f32/xf16/bf16 共享实现，`rvv_softmax.cpp:76-94,180-194,261-266` 传递算法开关；NaN/+INF 另走 scalar fallback；普通 logsoftmax 不误用该特殊分支。未发现同条件遗漏。
- 逃逸：普通随机值没有整行 `-INF`。
- 当前处置：历史已确认；当前排除。

## HC-5174：ReLU alpha 传播

- 引入：`c407a618` 默认 post-op helper 只做 `max(x,0)`。
- 修复：`d84af4cf1` 保存/消费 alpha；alpha 非零时 compare+multiply+merge；#5194 增加非默认 alpha 回归线索。
- 触发：融合 ReLU alpha 非零且结果含负值；症状退化为 hard ReLU。
- 不变量：PD 验证过的算法参数必须到达 kernel/injector。
- 五邻域：当前 `jit_uni_eltwise_injector.cpp:291-307`、postops kernel、pooling empty-window 和 conv post paths 均保存/消费 alpha；不同 dtype 先 widen 到 f32；未发现只检查不消费的 RV64 clone。
- 逃逸：默认 alpha=0 的测试不会暴露传播缺口。
- 当前处置：历史已确认；当前排除。

## HC-5370：RVV min/max NaN 语义

- 修复波次：`9836c11bd` eltwise clamp，`6e071923e` binary min/max，`784e9ed44` fused ReLU，`8a4ffff11` softmax clamp，`c4aa87e7e` ELU mask，`b44a10839` pooling max，`aa23ab557` ELU positive lanes。
- 触发：裸 `vfmin/vfmax` 被用作保留 NaN 的算法；症状 NaN 被边界/零替换，或错误 mask/正 lane exp 产生差异。
- 不变量：每个算法明确 NaN 传播/忽略/替换规则；裸 RVV min/max 不能隐式承担不同的 API 语义。
- negative/fix：裸 min/max -> compare+merge；错误的第二次 merge、mask reuse、正 lane exp -> 显式 mask/zero exp。
- 五邻域：当前主要浮点 injector/融合 consumer 已有显式 compare+merge；`clip_v2` 明确是 maxNum/minNum 合同，整数转换前 clamp 不是同一浮点语义。新 `jit_uni_prelu.cpp:122-123` 是 #5453 后新加入的独立 consumer，仍使用裸 vfmax/vfmin，记录为静态高置信 `RV64-001`；reduction 的裸 max/min 因 reduction API NaN 契约尚未闭环，保留候选 R-1。
- 当前处置：历史谱系和 PReLU 跨实现差异确认；oneDNN 公共文档不保证 NaN 输入结果，因此 RV64-001 不提升为已确认 API 违约，并避免与共享 injector 重复计数。

## HC-5394：depthwise 属性过度接受

- 引入：`6f0f23710` f16 NHWC 3x3 stride 1/2 depthwise，没有 injector 仍接受属性。
- 修复：`5d8f882f6` 在 `jit_uni_dwconv.hpp:70-75` 要求 `attr()->has_default_values()`。
- 触发：f16 depthwise 带 post-op/scales/zero-points；症状静默忽略属性。
- 不变量：无 injector/消费路径的实现必须在 PD 拒绝属性。
- 五邻域：当前 depthwise gate、BRGEMM/1x1/MatMul/inner-product/pooling 等均有 default/`post_ops_ok()`；`test_iface_attr.cpp` 仍有 RV64 depthwise fusion skip，属于覆盖缺口，不是当前实现证据。未发现同条件 sibling。
- 当前处置：历史已确认；当前排除。

## HC-5594：`int` counter 与 `dim_t`

- 引入：`1147a0739` RV64 GEMM convolution/im2col 扩展；shared/x64/PPC/GPU 亦有同模式。
- 修复：`584b59a27` 将 reorder scale loop、conv od/oS/spatial、weights reduction oc 等改为 dim_t；相关提交 `04c3a1813`,`2ab3925c4`,`e2709027b`,`5e8ed482c`。
- 触发：合法 logical/scratch size 超过 INT_MAX；有符号 counter 混用产生 overflow/错误退出/死循环/OOB。
- 不变量：counter、bound、地址乘加必须覆盖 `dim_t`，不得隐式缩窄。
- 五邻域：当前与 runtime dim_t bound 比较的目标 loop 已改为 dim_t；仍见 `int` 的 `po.len()/ndims/block config` 是小范围常量/配置，不满足同一前置条件。未升级当前 finding；超大 descriptor 仍为动态覆盖缺口。
- 当前处置：历史已确认；当前旧命中排除，保留 overflow-adjacent 验证建议。

## HC-5839：f16 softmax 临时缓冲生命周期

- 性质：维护/性能改进，不是历史 correctness bug。
- 引入：`97eb3d879`/`3c8c37bab` 每 slice `new float[len]`/`delete[]`。
- 改进：`443bee1e3` 预订 primitive scratchpad，按 worker 分片，删除反复 heap 分配。
- 不变量：scratchpad booking 容量为 worker 数×axis size；每个 worker 只用自己 slice；key/生命周期一致。
- 五邻域：当前 softmax f16/bf16 `rvv_softmax.hpp:134-157` booking 与 `rvv_softmax.cpp:210-249` execute key 一致；reduction 无 scratch；resampling binary slot 只在 gate 时读；没有 correctness 证据。
- 当前处置：如实记录为维护边界；当前排除为历史漏洞，未创建 finding。

## HC-5162：BRGEMM convolution bias review

- 对象区分：本地 `7709b0c71` 是无关 GPU BNORM PR；指导书所指为 #5150 review 中的 Issue #5162。
- 引入/修复事实：`35a1d8bb7` 的 BRGEMM bias fusion 在评审/整合期修正，没有独立已合并坏版本，不能虚构坏提交。
- 触发：padding 下第一次有效 BRGEMM 只覆盖部分 OW，若 bias 绑定第一次调用，剩余输出位置缺 bias。
- 不变量：每个输出元素恰好获得一次 bias；beta 只描述 C 累加，不决定 bias 覆盖。
- 当前模式：`rvv_brgemm_conv.cpp:175-183` 预初始化完整 OW×OC，`217-228` 分离 sum/bias；shared wrapper `brgemm.cpp:155-175` 按 kb==0 对每个 M tile 传 bias。
- 五邻域：conv/inner-product BRGEMM 的 bias 生命周期实现不同但各自满足 tile/row 不变量；无独立当前 clone。
- 逃逸：评审发现，普通 ctest 未覆盖该 padding/partial OW 形状；SMOKE 跳过部分 convolution。
- 当前处置：评审期已修正，当前排除；保留专项动态回归建议。

## HC-4638：运行时 ISA 隔离

- 对象：Issue，非带编号本地 commit。
- 历史链：`18d004359` 动态 `-march` -> `e9d697577` flags 修复 -> `64ce535` Zvfh -> `8a647d922`/#4685 RV64GC build flag -> `d41e7b973`/#5379 runtime ISA dispatch。
- 触发：无 V、旧 RVV、缺 Zvfh/Zvfbfwma 硬件，或全库由 RVV `-march` 编译；症状 SIGILL，即使调用点有 `mayiuse`。
- 不变量：baseline translation unit 不得包含目标 CPU 不支持指令；ISA-specific 代码生成、注册、调用均受能力约束。
- 五邻域：当前默认 CMake `-march=rv64gc`，RVV 由 Xbyak_riscv JIT；CPU list 统一 `CPU_INSTANCE_RV64`；PD 在 kernel creation 前 `mayiuse`。无旧 intrinsic source filtering clone。显式用户 `DNNL_ARCH_OPT_FLAGS` 是契约 override。
- 当前处置：历史系统性风险已由 runtime-JIT 迁移大幅修复；无动态环境，不能证明所有 compiler/real hardware 组合安全，列入未覆盖而非当前 finding。

## 汇总

- 14 条要求谱系全部建卡并搜索五类邻域。
- 历史确认 bug：#1677、#3457、#3486、#4197、#4445、#4637、#4890、#5174、#5370、#5394、#5594；当前旧模式均排除或另有当前 clone。
- 非漏洞维护项：#5839；评审期已修正、无独立坏提交：#5162；Issue 架构迁移：#4638。
- 当前 finding 文档：静态高置信 `RV64-001`（PReLU 特殊值差异）；静态确认 `RV64-002`（reduction tail）、`RV64-003`（BF16 BRGEMM stack alignment）、`RV64-004`（shuffle zero-batch division）。未把 reduction NaN、JIT failure、softmax padding、shuffle ISA 候选未经闭环升级。
