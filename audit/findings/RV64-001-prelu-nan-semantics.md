# RV64-001: PReLU JIT exceptional-value semantic divergence

- 状态：静态高置信（实现/reference/历史策略不一致；公开 NaN 契约仍未闭环）
- 严重性：medium（若要求与共同 reference 和既有 RV64 NaN-preserving 策略一致，则会产生静默数值差异）
- 审计基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 当前文档 HEAD：`529c7247f524902377455c62ab283b44918e285c`
- 环境：仅静态审计；x86_64 WSL2；未构建、未运行 benchdnn/ctest/QEMU/硬件/sanitizer；无 RV64 执行环境。
- primitive / implementation：PReLU forward / `jit_uni_prelu_fwd_t`（registered by `CPU_INSTANCE_RV64`）
- 涉及文件和符号：
  - `src/cpu/cpu_prelu_list.cpp:45-56`，`jit_uni_prelu_fwd_t` 的 RV64 注册顺序；
  - `src/cpu/rv64/jit_uni_prelu.hpp:61-104`，PD 接受域和 V/Zvfh/Zvfbfwma gate；
  - `src/cpu/rv64/jit_uni_prelu.cpp:61-158`，`emit_prelu_loop`；
  - `src/common/math_utils.hpp:145-150`，共同 reference `relu_fwd`；
  - `src/cpu/ref_prelu.cpp:99-109`，reference execute 调用 `relu_fwd`。
- 来源：方法 A（RV64 与共同 reference 的语义差分）+ 方法 B（#5370 min/max NaN 修复谱系和 #5453 新实现的时间邻域）。

## 摘要

RV64 PReLU JIT 将 `dst = max(0, src) + weight * min(0, src)` 发射为裸 RVV `vfmax.vf` 与 `vfmin.vf`。当 `src` 是 NaN 时，oneDNN 共同 reference 的 `s > 0 ? s : s * alpha` 返回 NaN；RVV 浮点 min/max 的 minimumNumber/maximumNumber 语义会在单侧 NaN 时选择数值操作数，两个中间量都变成零，最终输出为零（或窄化后的零）。可达指令序列与 reference 的结果差异可以静态确定，也与 #5370 后其他 RV64 路径采用的 NaN-preserving 模式不一致。

但是，oneDNN 公共 API 文档提醒调用者清理输入数据，并明确 NaN 值可能导致未预期结果。因此本 finding 不能把 NaN propagation 表述为无条件的公开 API 保证；当前证据等级是“静态高置信的实现一致性候选”，而不是已经闭环的公开契约违约。

## 可达路径（注册 -> PD -> execute -> kernel）

1. `src/cpu/cpu_prelu_list.cpp:45-56` 在 forward 列表中先尝试 `CPU_INSTANCE_RV64(jit_uni_prelu_fwd_t)`，之后才是 `ref_prelu_fwd_t`；因此该 PD 成功时 RV64 实现抢占 reference。
2. `src/cpu/rv64/jit_uni_prelu.hpp:67-104` 的 `pd_t::init()` 接受 forward、f32/f16/bf16 src/weights、默认属性和 full/scalar/per-oc plain/blocked broadcast，并要求 V；f16 要 Zvfh，bf16 要 Zvfbfwma。合法问题因此可到达该实现。
3. `src/cpu/rv64/jit_uni_prelu.cpp:200-214` 根据 broadcast 建立 JIT kernel；该 `init()` 没有检查或传播 `create_kernel()` 的返回值，属于另一个待审生命周期点，但不是本 finding 的必要条件。
4. `execute()` (`jit_uni_prelu.cpp:217-341`) 对 full、scalar、per-oc NHWC/NCHW/blocked 调用同一 `emit_prelu_loop` 生成的 kernel。
5. `emit_prelu_loop` (`jit_uni_prelu.cpp:121-127`) 对每一批 active lane 执行：
   - `vfmax_vf(vmax, vsrc, 0)`；
   - `vfmin_vf(vmin, vsrc, 0)`；
   - `vfmadd_vf/vv(vmin, weight, vmax)`。

## 触发条件

- RV64 CPU 具有 V；f16 另外具有 Zvfh，bf16 另外具有 Zvfbfwma；
- forward PReLU descriptor 落入该 PD 的支持域；
- 任意 active src 元素为 quiet/signaling NaN（窄 dtype 先按其格式载入并 widen）；
- 不需要特殊 shape：scalar、full、per-oc plain 和 per-oc blocked 均使用同一三指令公式。

最小逻辑输入可以是一个 f32 scalar-broadcast 问题，`src=[qNaN]`、`weights=[0.5]`、`dst=f32`。对 f16/bf16，使用相应格式的 NaN 并选择其已通过 PD ISA gate 的路径。

## 被破坏的不变量

共同 PReLU reference 对每个元素实现 `s > 0 ? s : s * alpha`。若 RV64 optimized implementation 应与该 helper 及既有 RV64 NaN-preserving 策略保持特殊值语义一致，那么 NaN lane 不能被 maxNum/minNum 分解替换为零。PD 声明的 dtype 和 broadcast 只改变读取/写回方式，不解释该跨实现差异；公开 API 是否承诺 NaN propagation 则仍是本 finding 的未决边界。

## 根因

`jit_uni_prelu.cpp:122-127` 使用一个只在有限输入上等价的 max/min 分解。RVV `vfmax`/`vfmin` 不是保留左操作数 NaN 的 ordered C++ comparison；它们遵循 RVV 浮点 minimumNumber/maximumNumber 行为，单侧 NaN 时选择非 NaN 操作数。因此：

```text
s = NaN
max(0, s) -> 0
min(s, 0) -> 0
0 + alpha * 0 -> 0
```

而共同 reference (`src/common/math_utils.hpp:148-150`) 是：

```text
s > 0 ? s : s * alpha
```

NaN 比较为 false，`NaN * alpha` 仍为 NaN。

同一代数变换还有两个应纳入后续验证的边界：在默认舍入模式下，`src=-0`、有限正 `alpha` 时 reference 可保留 `-0`，而 max/min 加法分解可得到 `+0`；有限正 `src` 与无限 `alpha` 时，reference 直接选择 `src`，分解却可能计算 `0*Inf+src` 并产生 NaN。这些观察进一步证明该变换并非对所有 IEEE-754 值等价，但它们同样需要结合 oneDNN 对特殊值的契约确定最终等级。

## 方法 A 证据

- **注册/可达性**：`cpu_prelu_list.cpp:50` 把 RV64 JIT 放在 `ref_prelu_fwd_t` 之前；`pd_t::init()` 在 `jit_uni_prelu.hpp:80-103` 对合法 dtype/layout 返回 success，故不是不可达代码。
- **PD/execute 责任**：PD 对 dtype、broadcast 和 src/dst layout 做 gate；execute 的所有 forward broadcast 分支最终调用同一个 kernel。PD 不检查数据值，因此不能仅从“PD 接受”推出 API 保证 NaN propagation。
- **伪代码差分**：reference 是 ordered `s > 0` 分支；RV64 是两个 RVV min/max-number 运算加 FMA。两者在 finite 输入上通常等价，在 NaN 上严格不同。
- **类型路径**：f32 直接使用 e32；f16 在 `:99-103` widen 到 e32，bf16 在 `:53-59`/`:135-138` 使用 Zvfbfmin widen/narrow。widen 不会把 NaN 变成有限值，因此 NaN 差异贯穿窄 dtype。

## 方法 B 证据与历史相似性

- `#5370` 修复波次的本地提交 `9836c11bd`、`6e071923e`、`784e9ed44`、`8a4ffff11`、`b44a10839` 将同一类裸 `vfmin/vfmax` 逐步改为 compare+merge，原因是 RVV min/max 的 NaN 行为不能隐式代替算法语义。
- `#5370` 的时间邻域先于 `#5453`：PReLU 新实现由 `d5ae44880` 在 2026-07-03 引入，当前 `emit_prelu_loop` 仍在 `jit_uni_prelu.cpp:122-123` 保留裸 min/max。该时间邻域说明这是修复波次后加入的同族新 consumer，而不是已被 #5370 处理的旧文件。
- 语法邻域：同一当前 RV64 树中，`jit_uni_eltwise_injector.cpp:291-307` 和 `jit_uni_pool_kernel.cpp` 的 ReLU/max 路径已经显式 compare+merge；PReLU 是未同步的语义 clone。
- 调用图邻域：PReLU standalone kernel 是独立 consumer，不经过已修复的 eltwise injector，因此 injector 修复不能保护它。

## API/reference/RVV 依据

- oneDNN 共同数学 helper `src/common/math_utils.hpp:145-150` 将非整数 `relu_fwd` 的 false 分支实现为 `s * alpha`；`src/cpu/ref_prelu.cpp:102-109` 将它用于 reference forward。这是实现/reference oracle，不应自动提升为所有特殊值的公共 API 保证。
- oneDNN C/C++ API 文档的输入检查说明提醒调用者清理输入，并指出 NaN 浮点值可能产生未预期结果：<https://uxlfoundation.github.io/oneDNN/dev_guide_c_and_cpp_apis.html>。因此报告保留契约边界，不把 NaN-to-zero 单独定性为已确认 API correctness defect。
- RVV V 规范的 floating-point MIN/MAX 指令定义采用 IEEE minimumNumber/maximumNumber 风格的单侧 NaN 处理；该语义与保留 NaN 的 ordered `s > 0` 分支不同。审计使用的规范入口：<https://docs.riscv.org/reference/isa/unpriv/vector.html>（“Vector Floating-Point MIN/MAX Instructions”）。
- 本地历史修复是第二个独立 oracle：`9836c11bd` 的提交说明和 diff 将裸 clamp min/max 替换为 compare+merge，并明确以 NaN-preserving 作为目标；`6e071923e` 对 binary min/max 做相同语义修复。

## 影响扩散面

- 直接影响 `jit_uni_prelu_fwd_t` 所有可达 broadcast 分支：full、scalar、per-oc NHWC、per-oc NCHW 和单 inner-block blocked。
- dtype 影响 f32；f16（Zvfh）；bf16（Zvfbfwma）。weights 可为 f32/f16/bf16，scalar host conversion 不改变 NaN src 的结果。
- 任何调用 standalone PReLU 的上游图/primitive 都可能观察 RV64 与 reference 不同的 NaN-to-zero 结果；backward 仍为 reference，不受此 finding 直接影响。
- 该问题与 #5370 的共享 injector 问题不同，不能只修 injector；需要修复 standalone PReLU kernel 的公式或显式 NaN mask。

## 最小复现命令（未来动态验证；本阶段未执行）

需要在具备 RV64 V 的构建中先用 verbose 确认实现，再定向运行：

```text
ONEDNN_VERBOSE=all <benchdnn>/benchdnn --mode=C --fast-ref=false -v6 \
  --impl=jit:rvv <prelu-driver> --sdt=f32 --ddt=f32 --wdt=f32 \
  --dir=FWD --attr="post-ops=none" <one-element-shape>
```

输入缓冲必须包含 qNaN（例如使用 benchdnn buffer-prefix 或等价的专用 harness）；预期先从 verbose 确认 `jit:rvv`，然后比较 `dst` 是否仍为 NaN。需要重复 f16/bf16、scalar/full/per-oc 和 VLEN 128/256/512/1024。由于本阶段禁止动态执行，以上命令是建议而非结果。

## 预期结果与实际结果

- reference/既有 RV64 NaN-preserving 策略下的预期：NaN 输入对应输出为 NaN，符号/quieting 细节按 dtype conversion 规则处理；这不是当前文档声称的无条件公共 API 保证。
- 静态推导的 RV64 实际结果：`vfmax(NaN, 0)=0`、`vfmin(NaN, 0)=0`，FMA 输出为 `0`，随后存储为零。
- 没有动态复现数据；“实际结果”是从可达指令序列和 RVV 规范推导的静态结果，需在目标 RV64 上验证。

## 反证和误报排除

- 这不是单纯 x64/RV64 文本差异：共同 reference 的数学分支与 RVV 指令的可观察 NaN 结果不同，且历史修复显示项目曾主动保持同类 NaN 语义。
- 不是合法的允许累加误差：触发是 NaN 到零的类别变化，不是有限浮点舍入或累加顺序差异。
- 不是错误 fallback：RV64 PD 在合法 dtype/layout 上位于 reference 前并可返回 success；该 finding 的触发条件不依赖被拒绝的属性。
- 不是 #5370 重复计数：#5370 处理共享 injector/现有 fused consumers；PReLU 是 #5453 后新加入的独立 kernel，当前仍存在负面模式。
- oneDNN 没有在 descriptor/PD 阶段拒绝 NaN 数据，但官方文档也不保证 NaN 输入的结果；因此“可达”与“公开契约违约”必须分开，当前按静态高置信而非静态确认处置。

## 现有静态测试为何未捕获

- `tests/benchdnn/prelu/ref_prelu.cpp` 提供 reference，但本阶段未执行，且普通数据生成通常不保证 NaN；需要 buffer-prefix/专用值矩阵。
- RISC-V CI 的 PReLU tests 位于 `.github/automation/riscv/test.sh:119,162,177`，但 CI 默认 QEMU 显式启用 V/Zvfh/Zvfbfwma，静态配置没有证据覆盖 NaN 输入、所有 broadcast 分支或 implementation filter。
- 现有测试即使通过，也可能命中 reference；指导书要求先用 verbose 确认目标实现。当前 SMOKE/CI 没有对 NaN 语义提供静态保证。

## 修复方向（不在审计阶段直接改代码）

若维护者确认 optimized PReLU 必须与共同 reference/既有 NaN-preserving 策略一致，则将负分支改为 ordered compare+merge：先计算 `alpha * src`，用 `src > 0` mask 在 `src` 与乘积之间选择；NaN mask 为 false 时保留乘积 NaN。若保留 max/min 分解，需要分别处理 NaN、`±0` 和 `0*Inf`。同步覆盖 f32/f16/bf16 和所有 broadcast kernel，并加入 NaN、`±0`、无限 weight 与非默认 alpha 的 regression case。

## 尚未解决的问题

- 未在 RV64 QEMU/硬件执行，无法提供稳定运行输出或准确 verbose implementation string。
- 需要由 oneDNN 维护者或更明确的测试/规范材料确认 PReLU optimized implementation 对 NaN、无限值和 signed zero 是否必须逐位/分类匹配共同 reference；这是从高置信候选升级为静态确认的关键条件。
- 需要在目标 RVV 实现上确认 signaling NaN 的 quieting/exception 行为；该细节不改变当前静态可证明的跨实现分类差异。
- 需要动态检查 blocked source/destination padding 的写回约定；它是独立的候选边界问题，不并入本 finding。
