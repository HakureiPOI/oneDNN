# oneDNN RV64 静态缺陷审计报告

## 结论

本次审计在产品基线 `8f49eae32bdec3674a9a98ea1524a85cd1f302db` 上完成了 RV64 注册实现、共享 JIT/ISA/GEMM/BRGEMM/reorder/resource 路径、指定历史谱系以及 RISC-V CI 配置的静态检查。形成三个可由当前控制流、数据流、公开契约、ABI 和 RVV 规则严格证明的静态确认 finding，以及一个实现/reference/历史策略高度不一致但公共特殊值契约尚未闭环的静态高置信 finding：

1. `RV64-001`（静态高置信）：PReLU JIT 用裸 `vfmax/vfmin` 分解 ordered ReLU，NaN 输入被替换为零；该行为与共同 reference 和 #5370 后的项目策略不一致，但 oneDNN 不保证 NaN 输入结果。
2. `RV64-002`：reduction 以 tail-agnostic policy 更新 accumulator，随后用 VLMAX 横向读取失效 tail lanes。
3. `RV64-003`：BF16 BRGEMM JIT 使用 56 字节栈帧，违反 RV64 LP64 的 16 字节栈对齐要求。
4. `RV64-004`：shuffle 接受零 batch descriptor 后用零任务数进行 `div_up`，在 debug 中断言、release 中除零未定义。

本阶段没有构建或运行任何代码，因此报告不声称动态复现、测试通过、QEMU/硬件验证或 sanitizer 结果。`RV64-002` 至 `RV64-004` 的“静态确认”表示路径可达，且从公开契约/ABI、RVV policy 和当前数据流可以严格推出违约；`RV64-001` 则明确保留公共 NaN 契约的不确定性。仍建议在 RV64 QEMU/硬件上按 finding 中的最小 case 做动态回归。

## 范围与基线

- 工作目录：`/home/hakurei/code/oneDNN`
- 分支：`audit/riscv-defect-audit`
- 审计时 `HEAD`：`529c7247f524902377455c62ab283b44918e285c`
- upstream：`origin/audit/riscv-defect-audit`
- 起始 worktree：`git status --short --branch` 显示干净。
- 产品基线与当前代码：`git diff 8f49eae32..HEAD -- ':(exclude)audit/**'` 为空；HEAD 之后只有本次/已有审计文档，不存在产品源码差异。
- 允许改动：仅 `audit/worklogs/`、`audit/findings/` 和本报告；未修改产品源码、测试实现、Git 历史或远端。
- 主机：x86_64 WSL2，16 logical CPUs；PATH 中没有 `cc`、`c++`、RISC-V GCC、CMake 或 QEMU。没有 RV64 硬件、QEMU、ISA/VLEN 或 sanitizer 动态证据。

## 覆盖结果

完整注册台账见 [`coverage-ledger.md`](worklogs/rv64-static-2026-08-26/coverage-ledger.md)。从当前 `CPU_INSTANCE_RV64`、`DNNL_RV64_ONLY`、实现列表和 RV64 CMake glob 建立的范围包括：

- batch normalization：fwd/bwd `jit_uni_batch_normalization_t<v/zvfh>`；
- binary：`jit_uni_binary_t`；
- convolution：1x1、Winograd、BRGEMM、GEMM、f16 depthwise；
- eltwise：fwd/bwd `jit_uni_eltwise_t<v/zvfh/zvfbfwma>`；
- group normalization、layer normalization；
- inner product：direct/GEMM/BRGEMM RV64 fwd；
- matmul：`rvv_brgemm_matmul_t`、`rvv_matmul_t`；
- pooling：fwd/bwd `jit_uni_pooling_t<v/zvfh/zvfbfwma>`；
- PReLU、reduction、resampling、shuffle、softmax；
- reorder：f32/f16/bf16/s8/u8/s32 regular/compensation maps 的 RV64 JIT，以及 block reorder；
- 共享 ISA/JIT 基座、injectors、GEMM/BRGEMM、scratchpad/thread/resource、CMake/toolchain、runtime capability 和 CI。

当前注册表源文件中有 41 次实际 `CPU_INSTANCE_RV64(...)` 调用，归入 14 个 primitive 家族；原始文本搜索的 44 个命中还包含一处宏定义和两处注释。reorder 另有分散在各 map 的 36 次 `DNNL_RV64_ONLY(CPU_REORDER_INSTANCE(...))` 调用，因此整体台账覆盖 15 个家族。台账按家族汇总注册顺序、PD/执行责任和 fallback，具体模板/方向/ISA 实例由每行源码位置追溯；没有 RV64 专用实现的 backward、LRN、RNN、deconvolution 等通过 shared/simple/reference 覆盖，不能把“无专用类”误写成 API 不支持。

## 方法 A：跨架构静态语义差分

逐条对照注册 -> PD -> config/resource -> execute -> kernel，并用 x64、共同 reference、API 约束和 RVV policy 作为分层 oracle：

- 注册/dispatch：RV64 优化实现通常位于 reference 前；不支持配置通过 `VDISPATCH_*` 返回 `unimplemented`，由 generic/reference 接管。`d41e7b973` 后默认 CMake baseline 为 `-march=rv64gc`，向量由 runtime JIT 发射。
- PD 接受域：检查了 prop kind、zero/runtime dimensions、dtype、layout、`any` defaulting、attributes、post-op、scales/zero-points/dropout。历史 #4197/#5394 的“接受但不消费”模式在 MatMul、BRGEMM、depthwise、pooling、normalization 等当前 gate 中未发现同条件复本。
- 资源/生命周期：检查 scratchpad key/容量/每线程分片、JIT code 注册、GEMM static kernel table、primitive 多次执行状态。#5839 的 softmax heap 缓冲已换成按 worker 分区的 scratchpad；未发现可严格证明的容量越界。
- execute：检查 batch/group/channel/spatial/broadcast、padding/空窗口、first/last K、bias/beta、tail、offset 和 `dim_t` 宽度。#4637 的 im2col width padding guard、#5162 的 BRGEMM bias pre-initialization、#5594 的 counter widening 当前已承接。
- kernel：重点审阅 reduction 初值、NaN/INF、f16/bf16 widen/narrow、post-op alpha、RVV VL/VTYPE/LMUL、tail/mask policy。reduction tail 违反 accumulator 有效性不变量，BF16 BRGEMM 违反 LP64 栈对齐，shuffle 零 batch 违反 `div_up` 正除数前置条件；PReLU 则形成可静态确定的特殊值跨实现差异，但公共 NaN 契约仍需闭环。四者分别形成 finding 文档并按不同置信等级记录。

其他差异被分类为合法架构差异、正确 fallback、不可比或候选，详见 [`dismissed-candidates.md`](worklogs/rv64-static-2026-08-26/dismissed-candidates.md)。

## 方法 B：历史修复扩散

[`history-cards.md`](worklogs/rv64-static-2026-08-26/history-cards.md) 为指导书要求的 14 条谱系逐项建卡，并记录引入/修复提交、触发、症状、根因、不变量、negative/fix pattern、逃逸原因、五类邻域、上下游和当前处置：

- #1677、#3457、#3486、#4197、#4445、#4637、#4890、#5174、#5370、#5394、#5594：历史上已确认的 correctness、安全、dispatch 或 build bug；当前旧模式均找到修复承接或正确 gate。
- #5839：scratchpad/allocator 维护改进；按指导书要求没有改写为历史 correctness bug。
- #5162：BRGEMM bias review 问题在 #5150 review/整合期修正，没有独立已合并坏提交；当前 output preinit/per-tile bias 模式满足不变量。
- #4638：Issue 驱动的 compile-time ISA -> baseline/runtime JIT 迁移；当前旧 intrinsic source filtering 不存在，但无 V/缺扩展/不同真实 VLEN 仍是动态覆盖缺口。

`RV64-001` 是 #5370 修复波次之后由 #5453 新增的独立 PReLU consumer，属于同族负面模式未同步，但只据 NaN 输入尚不能提升为公开契约违约；`RV64-002` 是 #5361 新 reduction JIT 的 tail-validity 缺陷，独立于 reduction NaN 候选；`RV64-003` 是 BF16 BRGEMM JIT 的 RV64 LP64 ABI 栈对齐违约；`RV64-004` 是 #5850 shuffle JIT 在零 batch 合法 descriptor 上的零除数。

## Findings

### RV64-001，PReLU NaN-to-zero

- 状态：静态高置信；严重性 medium；优先级 `P=11`（X=2,H=2,R=2,I=1,T=2,E=1，API 对 NaN 的保留意见计入 E；分数仅用于排序）。
- 可达链：`cpu_prelu_list.cpp:45-56` -> `jit_uni_prelu.hpp:67-104` -> `jit_uni_prelu.cpp:200-214,217-341` -> `emit_prelu_loop:121-127`。
- 触发：合法 RV64 V/f16/bf16 ISA gate、任意支持 broadcast、active src lane 为 NaN。
- 差异：共同 `math_utils.hpp:145-150` 的 `s > 0 ? s : s*alpha` 保留 NaN；RV64 `vfmax/vfmin` minimumNumber/maximumNumber 分解把 NaN 与零合并为零。
- 两路证据：共同 reference 实现与 RVV min/max 规范/实际发射序列；第三路历史 #5370 的 compare+merge 修复波次。oneDNN 公共文档警告 NaN 输入可能产生未预期结果，故不把 reference 差异直接写成 API 保证。
- 影响：f32、f16、bf16；full/scalar/per-oc NHWC/NCHW/blocked；若要求匹配 reference/既有特殊值策略则为静默数值差异，最终契约等级待维护者确认。
- 详情、最小未来动态验证和修复方向见 [`RV64-001-prelu-nan-semantics.md`](findings/RV64-001-prelu-nan-semantics.md)。

### RV64-002，reduction tail-agnostic read

- 状态：静态确认；严重性 high；优先级 `P=12`（X=2,H=1,R=2,I=2,T=2,E=0；#5594 仅提供相邻宽度审计信号，不是同根历史修复）。
- 可达链：`cpu_reduction_list.cpp:38-44` -> `jit_uni_reduction.hpp:41-111` -> `jit_uni_reduction.cpp:26-54` -> kernel `emit_loop:195-215` -> `emit_horizontal_reduce:217-239`。
- 触发：`reduce_size=VLMAX+r`，`0<r<VLMAX`；f32 e32/m8、f16 native e16/m8 或 f16 widening path 均可触发。
- 违约：更新 accumulator 时选 `VTA::ta`，最后短 chunk 的 tail lanes 可保留旧值或被写成全 1；随后将 VL 恢复到 VLMAX 并让 `vfred*` 读取整个 accumulator，错误依赖了这些 lane 保留先前合法贡献。
- 两路证据：RVV tail-agnostic policy；当前 JIT 数据流中无 valid-lane mask/计数且最终 full-width reduction；共同 reference 精确遍历 logical `reduce_size`。
- 影响：f32/f16 sum/mean/max/min，VLMAX 相对的所有 VLEN，静默错误且与有限输入即可触发。
- 详情、形状、未来动态验证和修复方向见 [`RV64-002-reduction-tail-agnostic-read.md`](findings/RV64-002-reduction-tail-agnostic-read.md)。

### RV64-003，BF16 BRGEMM stack alignment

- 状态：静态确认；严重性 medium；优先级 `P=9`（X=2,H=0,R=2,I=1,T=2,E=0；没有同根历史修复，当前运行时症状未证明）。
- 可达链：BF16 MatMul/inner-product/convolution PD -> `brgemm_kernel_create()` -> `jit_brgemm_bf16_kernel_t::generate()`。
- 触发：任意可达 BF16 BRGEMM；生成序列 `addi(sp,sp,-56)` 使 16-byte-aligned entry 变成 8-byte-aligned body。
- 违约：RV64 LP64 ABI 要求栈在函数体内保持 16-byte 对齐；同文件 f32/f16 使用 48-byte、s8 使用 32-byte 对齐帧。
- 影响：共享 BF16 BRGEMM kernel 的 MatMul、inner product、convolution；当前确认的是 ABI 合规缺陷。生成体为 leaf 且现有栈访问只要求 8-byte 对齐，尚未证明当前数值错误、越界或崩溃。
- 详情、规范依据、动态验证和修复方向见 [`RV64-003-bf16-brgemm-stack-alignment.md`](findings/RV64-003-bf16-brgemm-stack-alignment.md)。

### RV64-004，shuffle zero-batch division

- 状态：静态确认；严重性 high；优先级 `P=10`（X=2,H=0,R=2,I=2,T=2,E=0；#3457 是边界邻域而非同根历史修复）。
- 可达链：public memory descriptor -> `shuffle_desc_init()` -> `cpu_shuffle_list.cpp` RV64 candidate -> `jit_uni_shuffle.hpp::pd_t::init()` -> `jit_uni_shuffle.cpp::execute()`。
- 触发：合法 zero-batch descriptor（`MB=0,C>0,SP>0,axis=1`），PD 没有 zero-dim gate，execute 中 `tasks=MB*nb_c=0`，随后 `div_up(nthr,tasks)`。
- 违约：oneDNN 支持 zero-volume memory 且不应访问其缓冲区；`utils::div_up` 要求 divisor > 0，但当前路径在 debug 断言、release 发生除零未定义行为。
- 影响：RV64 shuffle forward/backward 的支持 dtype/layout；失败发生在 kernel 调用前，和 VLEN/数据值无关。
- 详情、API/辅助函数证据、动态验证和修复方向见 [`RV64-004-shuffle-zero-batch.md`](findings/RV64-004-shuffle-zero-batch.md)。

## 未升级候选与排除

当前保留但未升级的候选：

- softmax/resampling/GEMM/1x1 构造函数内部丢弃 `create_kernel()` status：需要合法 codegen/ready/getCode failure 才能闭环，静态未证明可达失败。
- BF16 SIGILL probe 的全局 `sigaction`/`sigjmp_buf`：可能与并发同步 SIGILL 或外部 handler 冲突，但没有动态证据。
- reduction max/min NaN：#5370 同族信号很强，但 reduction 公开 NaN contract 和 operand-order 语义尚未闭环。
- softmax plain padded output：缺少合法 padded descriptor/输出 padding 契约的完整静态证明。
- shuffle V-only 半精度 gate：缺少 platform 对 raw f16/bf16 memory move 的契约证明；shuffle zero-task division 已升级为 RV64-004。
- 1x1 非标准 VLEN implementation id：`get_vlen_implementation_id()` 可能返回 `-1` 并进入 `utils::pick`，但尚未证明声明支持的 VLEN 会触发。

已排除的差异包括历史旧 pooling 初值/空窗口、MatMul dropout 和 column-major weights、im2col width padding、softmax all-`-INF`、ReLU alpha、depthwise attributes、`int`/`dim_t` 已修复模式、正常 fallback、不同 tile/blocked layout、#5839 维护项和 #5162 review-only bug。每项证据和重新开启条件在排除日志中。

## CI 与测试覆盖缺口

- PR CI：`.github/workflows/ci-riscv.yml:137-188` 仅 QEMU VLEN=128/256、OMP、SMOKE，并显式启用 V/Zvfh/Zvfbfwma。
- Weekly：`.github/workflows/weekly-riscv.yml:109-170` 十片、仅 VLEN=128，同样显式启用全部扩展。
- Skips：`.github/automation/riscv/skipped-tests.sh:27-56` 固定跳过 matmul/sum/graph；SMOKE 还跳过 convolution/pooling/GEMM/RNN 等长测；CI 跳过 matmul/IP/graph benchdnn。
- 测试源码有 primitive/reference case，但没有静态证据覆盖目标 implementation、NaN/INF/±0、VLMAX+tail、无 V/缺 Zvfh/Zvfbfwma、VLEN 512/1024、超 `INT_MAX` 或并发 SIGILL/JIT failure。
- 因此“CI 测试存在/通过”不能排除三个静态确认 finding 或 RV64-001 的高置信差异；本报告未执行测试。

## 后续动态验证建议

按低成本到高成本：

1. 对 RV64-002 用 VLEN=128 的 f32 reduction `{1,1,1,33}`、f16 native max/min `{1,1,1,65}` 和 f16 sum/mean `{1,1,1,33}`，重复 VLEN=256 的 `VLMAX+1`；max/min 使用有限非均匀值并把唯一极值放在可能被短尾覆盖的旧 accumulator lane，sum/mean 可补全 1 输入。
2. 在 VLEN=128 先确认 verbose implementation，再运行 RV64-001 的 f32 scalar PReLU qNaN、signed-zero 和无限 weight case；扩展 f16/bf16、broadcast、VLEN=256/512/1024，并结合维护者确认的特殊值契约决定是否升级。
3. 运行 softmax special value、padding、resampling tail、shuffle ISA/offset、JIT failure injection 和 BF16 probe 并发矩阵；均需 `--mode=C --fast-ref=false -v6`，并用 `--impl` 二次确认目标实现。
4. 在真实硬件补无 V、V-only、缺 Zvfh/Zvfbfwma、多 VLEN 及 SIGILL handler 恢复验证；这些超出本静态阶段。

## 数量与未覆盖

- 静态确认 finding：3（RV64-002、RV64-003、RV64-004）。
- 静态高置信 finding：1（RV64-001；实现/reference/历史策略差异确定，公开特殊值契约未闭环）。
- 静态候选类别：6（JIT 构造丢弃 `create_kernel()` status 类、C-ISA-1、R-1、C-2、SH-4、1x1 非标准 VLEN implementation-id 观察项）；同类中的多个调用点不重复计数。
- 已排除/合法差异分组：16（排除日志中的 10 个历史旧模式和 6 个正确架构差异/正常 fallback 分组）；14 条历史 oracle 均已有当前处置，但 #5370 同时支撑 RV64-001/R-1，不能把该数量解释为“测试证明无问题”。
- 未覆盖类别：9（动态 implementation 命中、RV64 QEMU/硬件执行、VLEN 512/1024、无 V/部分扩展、sanitizer、codegen failure 注入、并发 signal 行为、完整超大 descriptor、完整 benchdnn 属性/特殊值矩阵）。

## 产物与收尾

本次新增/修改审计文档：

- `audit/worklogs/rv64-static-2026-08-26/coverage-ledger.md`
- `audit/worklogs/rv64-static-2026-08-26/history-cards.md`
- `audit/worklogs/rv64-static-2026-08-26/dismissed-candidates.md`
- `audit/worklogs/rv64-static-2026-08-26/draft-isa-infra-ci.md`
- `audit/worklogs/rv64-static-2026-08-26/draft-softmax-reduction-resampling-shuffle.md`
- `audit/worklogs/rv64-static-2026-08-26/draft-matmul-gemm-reorder.md`
- `audit/worklogs/rv64-static-2026-08-26/draft-convolution-pooling.md`
- `audit/findings/RV64-001-prelu-nan-semantics.md`
- `audit/findings/RV64-002-reduction-tail-agnostic-read.md`
- `audit/findings/RV64-003-bf16-brgemm-stack-alignment.md`
- `audit/findings/RV64-004-shuffle-zero-batch.md`
- `audit/rv64-static-audit-report.md`

交付前应再次确认 `git status --short --branch` 和完整 staged diff，确保提交范围仅包含上述审计文件，不含产品源码或测试改动。
