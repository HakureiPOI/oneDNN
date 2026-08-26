# RV64 静态缺陷审计草稿：softmax / reduction / resampling / shuffle

- 审计日期：2026-08-26
- 审计基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 基线提交：`cpu: rv64: add bf16 support for binary, softmax and pooling (#5888)`
- 当前工作树：分支 `audit/riscv-defect-audit`，初始 `HEAD=529c7247f524902377455c62ab283b44918e285c`；基线到 HEAD 的产品树 diff 为空。初始工作树干净。
- 范围：只审查 softmax、reduction、resampling、shuffle 及这些路径直接调用的 RV64 ISA/JIT/post-op/scratchpad 代码；共同 reference、x64 对照、相关 benchdnn/gtests/CI 仅静态阅读。
- 操作限制：本专题轮次未构建、未运行库/测试/benchdnn/CI，也未修改产品源码或测试。本文件最初是阶段性工作记录，后续主审计已将 R-5/SH-5 分别闭环为 `RV64-002`/`RV64-004`；以下状态已在交付前与最终报告同步。
- 证据口径：以下“候选”是静态审计结论，不等于已动态确认；未有运行时 verbose 实现名或 RV64 复现结果。

## 1. 覆盖摘要

| primitive | RV64 注册顺序（从前到后） | RV64 `DECLARE_COMMON_PD_T` | 实际能力边界 | fallback |
|---|---|---|---|---|
| softmax | `CPU_INSTANCE_RV64(rvv_softmax_fwd_t)`，位于 forward x64/AArch64 后、reference 前；backward 没有 RV64 项 | `JIT_IMPL_NAME_HELPER("jit:", isa_, ""), rvv_softmax_fwd_t` | forward training/inference；src=dst 且同布局；f32/V，f16/Zvfh，bf16/Zvfbfwma；plain dense，axis 任意但物理 contiguous plain stride 约束；默认属性 | `ref_softmax_fwd_t`；backward 由 `ref_softmax_bwd_t` 接管 |
| reduction | `CPU_INSTANCE_RV64(jit_uni_reduction_t)`，位于 x64 后、reference 前 | `"jit:uni", jit_uni_reduction_t` | forward；`reduction_sum/mean/max/min`；f32/f16 输入与 f32/f16 输出；x/nc/ncw/nchw/ncdhw 相同 tag；dense；缩减必须是从末维连续的一段维，非空；默认属性 | `ref_reduction_t` |
| resampling | forward 中 `jit_uni_resampling_fwd_t<zvfh>` 后 `jit_uni_resampling_fwd_t<v>`，然后 simple/reference；backward 无 RV64 | `JIT_IMPL_NAME_HELPER("jit:", conf_.isa, ""), jit_uni_resampling_fwd_t` | forward；f32/V（v 实例）、f16/Zvfh（zvfh 实例）；nearest/linear；blocking descriptor 仅允许一个 dim-1 内 block，plain 或同 block 的 blocked C；dense；可选 sum/eltwise/binary 的窄子集 | `simple_resampling_fwd_t`、`ref_resampling_fwd_t`；backward 为 simple/reference |
| shuffle | x64 AVX512/AVX/SSE、AArch64 SVE/ASIMD 后，`CPU_INSTANCE_RV64(jit_uni_shuffle_t)`，reference 最后 | `"jit:rvv", jit_uni_shuffle_t` | forward/backward；axis=1；f32/s32/f16/bf16；plain `nc/nwc/nhwc/ndhwc` 或 C 整除 inner block 的 `nC{w,h,d}...{4,8,16}c`；dense；无属性；最大 offset <= UINT32_MAX | `ref_shuffle_t` |

全局 RV64 编译采用 `-march=rv64gc` 默认；向量指令由 Xbyak_riscv JIT 在运行时发射。`mayiuse(v)`、`mayiuse(zvfh)` 和 `mayiuse(zvfbfwma)` 来自 `Riscv64Cpu` singleton；Zvfbfwma 是 SIGILL trap probe，且 `zvfbfwma` mask 意味着 V。`XBYAK_RISCV_V` 缺省定义为 1，但每个向量生成体仍有编译条件；RV64 primitive 的 PD gate 在创建 kernel 前检查运行时 ISA。`platform::has_data_type_support(bf16)` 依赖 `mayiuse(zvfbfwma)`，f16 依赖 `mayiuse(zvfh)`。

## 2. 共同调用链与 ISA/JIT 基座

### 2.1 注册与选择

`src/cpu/cpu_softmax_list.cpp`、`cpu_reduction_list.cpp`、`cpu_resampling_list.cpp`、`cpu_shuffle_list.cpp` 提供候选数组/映射。`CPU_INSTANCE_RV64(...)` 只在 `DNNL_RV64` 下展开；实现列表按顺序尝试 PD，PD `init()` 返回 `status::unimplemented` 才继续 fallback。softmax/resampling 将 forward training/inference 映射到 forward key，backward key 中无 RV64。reduction/shuffle 列表为单一数组，propagation、dtype、布局由 PD gate 处理。

RV64 JIT 的共同生命周期是 primitive `init()` 中创建派生 `jit_generator_t`，调用 `create_kernel()`，其 `generate()` 受 `XBYAK_RISCV_V` 编译保护，随后 `ready(PROTECT_RWE)`、取得 `jit_ker_`、注册 profiler code，execute 通过函数指针调用。`jit_generator_t::create_kernel()` 捕获 generate 异常并返回 runtime_error，且检查 `getCode()`；reduction/shuffle 的 primitive init 用 `CHECK(kernel_->create_kernel())`。softmax affine kernel 和 resampling kernel 则在构造函数内部直接调用并丢弃 `create_kernel()` 返回值，外层 `safe_ptr_assign` 只检查对象分配，分别形成候选 C-1/C-3。

### 2.2 共同参照

- x64 softmax：`x64/jit_uni_softmax.hpp/.cpp`，PD 选择 ISA/dense layout、支持 scales/post-op，dense/strided kernel 使用尾 mask；reference `ref_softmax.cpp` 覆盖属性、scale、dropout、generic layout。
- x64 reduction：`x64/jit_uni_reduction.cpp` 支持多种 dtype/整数/norm-lp，使用 post-op injector；RV64 是较窄的 sum/mean/max/min f32/f16 子集。
- x64 resampling：`x64/jit_uni_resampling.cpp` 预计算 unsigned indices，按 ncsp/nspc/blocked 生成 kernel，并用 post-op injector；reference `ref_resampling.cpp` 是标量 corner/weight oracle。
- x64 shuffle：`x64/shuffle/jit_uni_shuffle.cpp` 仅 blocked 16/8/4c；共同 `ref_shuffle.cpp` 还处理 plain、不同 axis 的 generic indexing。RV64 shuffle 是独立的 gather/pack 设计，不应仅按 x64 的 blocked 限制判为缺陷。
- 共同 API PD：`common/softmax_pd.hpp`、`reduction_pd.hpp`、`resampling_pd.hpp`、`shuffle_pd.hpp`；共同 `memory_desc_wrapper` 的 `nelems(with_padding)`、`is_dense(with_padding)`、`only_padded_dim()` 和 `similar_to()` 是接受域关键语义。

## 3. Softmax：完整追踪

### 3.1 A0 注册/dispatch

入口：`src/cpu/cpu_softmax_list.cpp:44-58`。forward 顺序是 x64 `jit_uni_softmax_fwd_t`、AArch64 SVE/ASIMD、RV64 `rvv_softmax_fwd_t`、`ref_softmax_fwd_t`；backward 顺序没有 RV64，x64/AArch64 后直接 reference。`get_softmax_impl_list()` 将 forward training/inference 归为 forward，其他归为 backward。

准确 PD 名：`rvv_softmax_fwd_t::pd_t`，`DECLARE_COMMON_PD_T(JIT_IMPL_NAME_HELPER("jit:", isa_, ""), rvv_softmax_fwd_t)`。`isa_` 在 dtype 判定后设为 f16=`zvfh`、bf16=`zvfbfwma`、f32=`v`，使不支持的 xf16 descriptor 记录为对应 ISA 名而不是错误的 `jit:rvv`。

Gate 顺序：先 `set_default_formats()`，默认属性、非零维；读取 axis stride/axis size/outer size；限制 f32/f16/bf16 且 src/dst dtype 相同；设 ISA；拒绝 bf16 logsoftmax；`mayiuse(v)`，xf16 再 `mayiuse(isa_)` 和 `XBYAK_RISCV_V==1`；platform dtype support；`check_layouts()`。

### 3.2 A1 PD/config capability

| 维度 | RV64 | x64/reference 对照 | 处置 |
|---|---|---|---|
| direction/algorithm | forward；softmax accurate、accurate_inf_as_zero、logsoftmax；backward reference | x64 forward/backward JIT；reference 两向 | 有依据的架构差异，已排除为缺陷 |
| dtype | f32→f32、f16→f16、bf16→bf16；无混合 dtype；f16 Zvfh，bf16 Zvfbfwma | x64/reference 可支持更宽的 f32/xf16/int8/scale 域 | 窄能力但 PD 与执行一致；有依据差异 |
| attribute | `attr()->has_default_values()`，拒绝 scales/post-op/dropout/workspace 特性 | x64/reference 支持一部分 scales/post-op/dropout | 正确 fallback，不是过度接受 |
| layout | src/dst 都 plain、dense(true)、`src_d == dst_d`；axis 可任意，但 dense plain stride 使 axis 物理访问连续；无 blocked | x64 支持 dense blocked/strided；reference generic | RV64 明确拒绝，不是误报 |
| dimensions | 拒绝 zero dim；`inner_size=strides[axis]`，`axis_size=axis_size()`，`outer_size=nelems(true)/(inner_size*axis_size(true))` | common API 只接受合法 dimensions；reference 支持 generic | 未发现可达零除；zero dim gate 在计算前 |
| padding | plain dense(true) 允许 padding，但 `src_d == dst_d`；axis 逻辑尺寸使用 `axis_size()`，临时/输出按逻辑 axis | x64 对 `axis_has_padding_` 有显式 tail zeroing | 需要动态验证 padded plain descriptor；静态上 RV64 的 plain `set_default_formats` 通常无 inner block，且 API 公开 padding plain 是否可达尚未闭环，暂列 C-2 低置信候选而非 finding |
| axis/strides | contiguous axis path `base=outer*axis_size(true)*inner_size`；strided axis gathers to scratch only when `inner_size>1`; `inner_size` 实为 blocking stride | reference generic `off_l`；x64 strided kernel | 设计可解释，待边界验证 |
| post-op | 全部默认，仅 standalone | x64/reference 更宽 | 正确 fallback |

`init_scratchpad()`：`work_amount = inner_size>1 ? outer_size*inner_size : outer_size`；f32 在 inner=1 时 nthr=1，否则 min(max_threads, max(work,1))；xf16 无论 inner 是否 1 都按工作量分线程。inner>1 预订 `key_softmax_interim_store = axis_size(true)*dt_size*nthr`；xf16 预订 `key_softmax_reduction = axis_size(true)*nthr`。xf16 reduction 临时区按 worker `ithr*axis_size` 分片，容量满足每 slice 的 logical axis；inner>1 的 packed xf16/f32 scratch 也按同样分片。未发现 scratch key/booking 不一致或线程索引越界。`static_cast<int>` 的 nthr 上界是 `dnnl_get_max_threads()`，通常 int；work 由 dim_t 计算，超大乘积仍需 overflow-adjacent 动态用例，但没有独立可达 proof。

### 3.3 A3 execute

`rvv_softmax_fwd_t::execute()` 只转发 `execute_forward()`。它从 `DNNL_ARG_SRC/DST` 取 raw pointer，算法判断 `softmax_accurate_inf_as_zero`。

- f32：`outer_stride=axis_size(true)*inner_size`。inner=1 时 `parallel_nd(outer_size)` 直接在原 buffer 上计算；inner>1 时每线程 gather `tmp[a]=src[base+a*inner_size]`，在 contiguous tmp 上计算，再 scatter 到 `dst[base+a*inner_size]`。
- xf16：inner=1 直接每线程处理 slice；inner>1 先用 JIT gather 将 axis packing 到 xf16 scratch，计算后 JIT scatter。f16/bf16 均通过 `compute_softmax_xf16_rvv<T,dt>` 分派；tmp reduction 是线程私有 f32 区域。
- 代码没有属性/post-op/scale/dropout 参数，PD 已拒绝这些属性；没有 backward execute。

### 3.4 A4 kernel/语义

f32 scalar max seed `-INFINITY`，逐元素用 `src[i] > max ? src : max`；softmax accurate_inf_as_zero 在 max 为 `-INFINITY` 时显式写 0 并令 inv_sum=1，覆盖 #4890 的 all-`-INF` 规则；普通 softmax all `-INF` 仍会产生 `NaN`，与 reference 公式一致。logsoftmax 不走 all-`-INF` special case，`-INF - -INF` 仍为 NaN，与 reference 的普通 logsoftmax 公式一致。

f32 `jit_rvv_softmax_f32_exp_sub_sum_kernel_t` 对 `src-sub` 使用 Cephes exp 近似，clamp 到 `[-103.972..., 88.776...]`，f32 output store_exp 时写 exp 临时结果，末尾 `vfredosum_vs` 聚合。f32 affine kernel 逐 chunk `vsetvli(reg_len,e32,m1,ta,ma)`，load/sub/mul/store，按 vl 更新指针/len。

xf16：len>=16 用 `jit_rvv_softmax_xf16_reduce_max()`，否则 scalar；检测 raw NaN 并把 NaN lane 从 max 中排除，另通过 `has_nan` 触发 scalar fallback；max `+INF` 也触发 scalar。scalar fallback 使用 f32 accumulation。regular softmax all `-INF` 用 zero scratch；logsoftmax/普通有限值走 vector exp-sub-sum 和 affine narrowing。xf16 gather/scatter 采用 e16 m1；f16/bf16 widen/narrow 分别为 `vfwcvt_f_f_v/vfncvt_f_f_w` 与 `vfwcvtbf16_f_f_v/vfncvtbf16_f_f_w`。

tail/VLEN：各 loop 都以剩余 len 调 `vsetvli`，指针增量使用返回 vl，未发现固定 VLEN 假设；xf16 reduce-max 先将 `v_f16` tail 清零，然后以 `VTA::tu` 加载；exp kernel 的最终 accumulator 使用 `VTA::tu`/`vfredosum`。`vl=0` 因外层 `beqz(len)` 先退出。需要在 VLEN 128/256 及 axis 15/16/17/多个 chunk 验证。

### 3.5 Softmax 差异处置

- S-1：f32 plain-only、无属性、forward-only 相对 x64 的能力缩小。分类：有依据的架构差异/正确 fallback。状态：排除。
- S-2：bf16 logsoftmax 明确拒绝以避免 vector exp 近似在严格 xf16 对比下的 tie rounding；reference 可接管。分类：有依据的架构差异。状态：排除。
- S-3：#4890 all-`-INF` special case 在 f32/xf16 两路径都有；`max_is_pos_inf`/NaN fallback 避免 vector exp 污染。分类：等价/修复已扩散。状态：排除历史遗漏。
- S-4：#5839 scratchpad 改动已同时覆盖 inner=1 和 inner>1、f16/bf16；booking key 与 execute key 相同，按 ithr 分片。分类：等价。状态：排除。
- C-1：`rvv_softmax_fwd_t` 构造函数创建 f32 affine JIT 时没有检查构造函数内部 `create_kernel()` 的 status；对象仍可能持有 null `jit_ker_`，后续 `compute_softmax_f32_rvv()` 在 `affine_kernel_` 非空时调用 `operator()`。这是 JIT 生命周期/A2-A3 候选，而非已确认崩溃：`create_kernel()` 正常情况下由 codegen/ready 返回成功；尚缺能稳定触发生成失败的合法环境与证明。严重性暂定 availability/runtime-error，状态候选。最小动态验证应注入/模拟 JIT codegen failure 或受限 code buffer，并确认 primitive creation 是否返回错误而非 execute 时跳转 null。
- C-2：`check_layouts()` 允许 `is_dense(true)` 的 plain padded descriptors，但 execute 以 logical axis/outer stride 计算且没有显式清零 output padding；x64 明确有 `axis_has_padding_` store-zero 逻辑，reference 在 out-of-place 时处理 padding。当前 plain descriptor 的 padding 可达性、`src_d==dst_d` 后 `is_dense(true)` 对 user-facing plain padding 的具体组合尚未由静态代码闭环，故仅候选/需验证，不升级。最小用例：同一 plain descriptor，axis padded by 1，src/dst out-of-place，f32/f16/bf16，预填 dst padding 为 NaN，检查 logical output 与 padded lane。

## 4. Reduction：完整追踪

### 4.1 A0/A1

入口 `src/cpu/cpu_reduction_list.cpp:38-44`：x64 `jit_uni_reduction_t`、RV64 `jit_uni_reduction_t`、reference。准确 PD 为 `rv64::jit_uni_reduction_t::pd_t`，`DECLARE_COMMON_PD_T("jit:uni", jit_uni_reduction_t)`。

Gate 顺序：`mayiuse(v)`；拒绝 zero dim；读取 src/dst dtype、字节宽度、algorithm；仅允许 sum/mean/max/min；src/dst 仅 f32/f16；任一 f16 需要 `mayiuse(zvfh)`；`set_default_params()` 后默认属性；dense；src/dst tag 必须同一 `x/nc/ncw/nchw/ncdhw`。配置从末维向前找 src/dst 变化维，要求变化维 dst=1、连续尾部 reduction；累计 `reduce_size *= src_dims[d]`，`idle_size=dst.nelems()`；要求至少一个 reduced dim，前缀维相同。无 scratchpad、无 post-op、无 p/eps 使用（仅这些算法的 eps 不相关）。

相对于 x64/reference，RV64 正确拒绝整数、bf16、norm-lp、post-op/非同 tag/非连续尾部 layout；这些会继续 reference。没有过度接受证据。

### 4.2 A2/A3/A4

primitive init 创建 `jit_uni_reduction_kernel_t(conf)` 并 `CHECK(create_kernel())`。execute 用 byte pointer，`src_off=i*reduce_size*src_dt_size`、`dst_off=i*dst_dt_size`，`parallel_nd(idle_size)` 调 kernel。由于 PD 只接受相同 plain/blocked canonical tags并只缩减末尾维，字节线性化与 kernel 连续读取相符；未使用 `src_md.off_l`，但该前置条件由 tags/dense gate 强化。整数宽度：offset/size 为 dim_t/size_t，kernel arg reduce_size 为 dim_t；未见 `int` bound/counter，属于 #5594 风险已缓解。

kernel `load_params()` 将 src/dst/reduce_size 放入 a1/a2/a3。f32 每轮 `vsetvli(reg_n,e32,m8,ta,ma)`，先减 `reg_n` 再 load e32、src += vl*4；f16 sum/mean 每轮 e16 m4 并 `vfwadd_wv` 到 e32 m8，max/min e16 m8 在 f16 域累积；每轮 vl 变化正确，reg_n==0 时不会进入有效指令。主审计后续复核发现：该“每轮 vl 正确”的结论不完整——`emit_horizontal_reduce()` 在最后短 chunk 之后把 vl 重置为 VLMAX 并全量读取 `v_acc`，tail-agnostic lanes 被当作有效累加值；该缺陷已在 R-5 闭环并升级为正式 `RV64-002`。

初值：f32 acc max=-inf/min=+inf/sum=0；f16 max raw `0xfbff`（-65504）、min `0x7bff`（+65504），sum/mean f32 0。mean 在 JIT 中用 `1.0f/static_cast<float>(reduce_size)` 乘；sum/mean f16 先 widening，最终按 dst f32 直存或 f16 narrow。max/min f16→f32 这一 dtype pair 在 PD 中可接受，但 f16 max/min 在 f16 域进行，符合 f16 reduction 的输出 rounding；f32→f16 max/min 在 f32 域后 narrow，符合 default accumulation f32。

### 4.3 Reduction 差异处置

- R-1：RV64 `vfmax_vv/vfmin_vv` 与 `vfredmax_vs/vfredmin_vs` 未采用显式 compare+merge 的 NaN-preserving 结构；#5370 已显示 RVV `vfmin/vfmax` 直接路径会把 NaN 替换为数值。共同 reference `nstl::max/min` 是 `a>b?a:b`/`a<b?a:b`，对 NaN 的结果依赖 operand 顺序，且 oneDNN reduction reference/benchdnn 默认随机数据不提供 NaN 契约。因此这不是凭指令差异直接升级：需要先确认 reduction API 对 NaN 的定义以及 RVV reduction 指令的 NaN 行为是否要求传播；若 contract 要求同 x64/reference，当前 kernel 的 max/min 是高置信候选。触发域：f32/f16、max/min、任一 NaN、单/多 vector chunk、VLEN tail；signed zero 也应纳入。当前状态候选，不创建 finding。

- R-5：reduction tail-agnostic 读取（主审计后续闭环并升级）。`emit_loop`（`jit_uni_reduction_kernel.cpp:198-214`）每轮以 `VTA::ta` 更新 `v_acc`；最后短 chunk 之后 tail lanes 可保留旧值或被写成全 1，软件不能依赖旧 accumulator 被保留。但 `emit_horizontal_reduce`（`:217-239`）将 vl 恢复为 VLMAX 并对整个 `v_acc` 执行 `vfred*`。触发条件 `reduce_size=VLMAX+r`（`0<r<VLMAX`）：VLEN=128 时 f32 e32/m8 VLMAX=32（N=33），f16 native max/min e16/m8 VLMAX=64（N=65），f16 sum/mean widen 目的 e32/m8 同为 32 lanes（N=33）。sum/mean 可被全 1 bit pattern 形成的 qNaN 污染；max/min 则可能在 qNaN 被 minimumNumber/maximumNumber 忽略时丢失早先的唯一极值。有限输入即可触发，独立于 NaN 输入合同。引入提交 `a95f0060c`（#5361），基线未修复。已升级为正式 `RV64-002`（见 `audit/findings/RV64-002-reduction-tail-agnostic-read.md`）。
- R-2：RV64 只支持 f32/f16，x64/reference 支持 bf16/int/norm-lp/post-op。分类：有依据的架构差异/正确 fallback。
- R-3：RV64 无 scratchpad/post-op，配置和执行一致；`CHECK(create_kernel())` 传播 codegen 错误。分类：等价，排除生命周期缺陷。
- R-4：`reduce_size` 乘积使用 dim_t，execute 偏移用 size_t，较大合法 descriptor 的乘积溢出理论上仍是 #5594 邻域；oneDNN descriptor allocation/size 前置条件使真实可达性未闭环。列为未覆盖验证项，不作为候选 finding。

## 5. Resampling：完整追踪

### 5.1 A0/A1 capability

入口 `src/cpu/cpu_resampling_list.cpp:43-57`：forward x64 `jit_uni_resampling_fwd_t` 后依次 RV64 `<zvfh>`、`<v>`，simple、reference；backward 无 RV64，x64 AVX512 backward 后 simple/reference。两个准确 PD 都是模板 `jit_uni_resampling_fwd_t<isa>::pd_t`，名称由 `JIT_IMPL_NAME_HELPER("jit:", conf_.isa, "")`。

模板 `d_type=(isa==zvfh)?f16:f32`。Gate：`mayiuse(isa)`、is_fwd、src/dst 同 d_type、非零维、`set_default_params()`、允许默认值（skip sum/post_ops with dst dtype）、对 post-op src1 `any` 调 `attr_.set_default_formats(dst_md(0))`、`post_ops_ok()`、`init_conf()`。

`init_conf()` 再验证 nearest/linear 和 blocking desc；`channel_block()` 只接受无 inner block（block=1）或恰好一个 inner block 且 `inner_idxs[0]==1`，src/dst block 相等。配置保存 src/dst C/spatial/MB strides，C channel vector 可 unit 或 arbitrary byte stride；linear corners 为 2/4/8。数据布局包括 plain `ncw/nchw/ncdhw`（channel stride>1）和 nspc/blocked（channel unit stride）；无 tag-only 假设，使用 blocking descriptor。

### 5.2 A2/A3/A4

只在 `conf_.fuse_binary` 时预订 `key_binary_post_ops_rhs_ptrs` 一个 pointer；`post_ops_ok()` 限制最多一个 binary。execute 每个 `(MB,Cb,OD,OH,OW)` 创建 args，`channels=min(B,C-cb*B)`，按 conf stride 设置 src/dst；nearest 用 `nearest_idx`，linear 用 `linear_coeffs_t` 生成 1/2/4/8 corners 和 weights；kernel 调用后对最后 blocked C tail 清零。

f32 kernel：按 channel `vsetvli(t0,s10,e32,m1,ta,ma)`，读取各 corner unit/strided vectors，nearest copy 或 weighted FMA；post-op chain 按 sum index 分两段，binary injector 用 indirect rhs pointer/byte offset，最后 unit/strided store；按 vl 和 byte stride 增进 corner/dst/rhs。f16 kernel：e16 m1 load、widen e32 m2 做 linear/FMA 和 eltwise、读取 sum 时 widen dst、narrow e16 store；支持 f16 eltwise，binary 被 PD 拒绝。

插值计算与 reference 的权重方向一致：`resampling_utils::linear_coeffs_t` 的 `wei[0]` 是左/前权重；RV64 依次 `d_w*h_w*w_w` 与 `vfmul/vfmacc`。nearest/linear 的 spatial dimensions 3D/2D/1D 通过 ndims 分支覆盖。没有 backward RV64，故不用把 x64 backward kernel 的差异误记为缺陷。

### 5.3 Resampling 差异处置

- RS-1：RV64 前置条件较 x64 窄，不能处理 s8/u8/bf16、blocked 多 inner block/非 channel-inner block、backward；正确回退 simple/reference。分类：有依据架构差异。
- RS-2：sum 的 `zero_point!=0` 被拒绝，sum dtype 需 undef 或 d_type；binary 仅 f32、rhs f32、最多一个，broadcast 仅 scalar/per-oc/full-dst，f16 无 binary；这些限制与 kernel 消费一致。分类：等价/正确 fallback。
- RS-3：post-op `any` src1 先 default format，再做 `post_ops_ok()`，避免 #3457 的检查顺序问题；`init_conf()` 再将 sum 从 injector 中拆出并以 `sum_idx` 恢复顺序。分类：历史不变量满足。
- RS-4：blocked 最后一 C block 的 kernel 只处理 valid channels，driver 将 `[valid,B)` 置零，避免 tail lane/ post-op 观察 padding。分类：等价，排除 padding/OOB。
- RS-5：f32/f16 kernel 对每个 vector chunk 都以剩余 channels 设置 vl，并以返回 vl 更新所有 corner/dst 指针；未发现固定 VLEN tail 漏洞。最小验证仍需 B=1/3/7/15/16/17/非整除 C 与 VLEN 128/256。
- RS-6：`src_c_stride/dst_c_stride` 以元素转 byte；plain ncsp 的 spatial stride来自 blocking descriptor，nspc/blocked channel unit stride来自 block；driver `p_dst`、`src_base`、corner `src_sp_off` 组合与 reference 的 per-channel offsets 可静态对齐。状态排除，需动态 oracle 才能提高置信。
- RS-7：f32 binary per-oc/full-dst offset 在 driver 以 bytes 传给 injector；per-oc 使用 `cb*B*4`，full 使用 `(p_dst-dst0)*4`；injector `off_is_bytes` 直接相加，broadcast classifier 对 f32 resampling gate 的 scalar/per-oc/full 约束一致。状态排除。
- RS-8：构造函数 `jit_uni_resampling_kernel_t` 内部直接 `create_kernel()`，返回值被丢弃；primitive `init()` 只 `new` kernel 并返回 success，不再检查 kernel codegen 状态。与 C-1 相似但 resampling 更直接：`jit_uni_resampling_fwd_t::init()` 的 `CHECK(safe_ptr_assign(kernel_, new ...))` 只检查分配，不检查构造内部 `create_kernel()`；execute 随后无条件 `(*kernel_)(&args)`。这是候选 C-3，静态可达但需要合法 codegen failure 触发；状态候选。
- RS-9：`conf.dt_size=(int)types::data_type_size`、`num_corners=1<<(ndims-2)` 使用 int，但 API ndims 有小上界、dtype size 2/4；非缺陷。空间/byte stride仍为 dim_t。

## 6. Shuffle：完整追踪

### 6.1 A0/A1

入口 `src/cpu/cpu_shuffle_list.cpp:42-52`：x64 AVX512/AVX/SSE、AArch64 SVE/ASIMD、RV64 `jit_uni_shuffle_t`、reference。准确 PD：`rv64::jit_uni_shuffle_t::pd_t`，`DECLARE_COMMON_PD_T("jit:rvv", jit_uni_shuffle_t)`。

PD 同时选 forward `src/dst` 或 backward `diff_src/diff_dst` wrapper；先 dtype 相等、`mayiuse(v)`、默认属性、dtype∈{f32,s32,f16,bf16}、platform support、axis==1，再 `set_default_formats_common()`，src/dst MD 相等、dense。支持 plain `nc/nwc/nhwc/ndhwc` 或 blocked `nCw4c/nCw8c/nCw16c/nChw.../nCdhw...`，blocked 要求 C%blk==0。配置 mb/C/sp/stride_mb/dt_size/blk/nb_blk；计算最大 byte offset 并 gate `<=UINT32_MAX`。

### 6.2 A2/A3/A4

primitive `init()` 先 `precompute_offsets()`，再分配 kernel 并 `CHECK(create_kernel())`。`precompute_offsets()` 为 forward 使用 group×axis/group 的 transpose，backward 使用逆 transpose，生成 `rev_transposed`，按 `(ic/blk*SP*blk+ic%blk)*dt_size` 写 `uint32_t input_off_[C]`。析构 `free(input_off_)`；失败路径在 malloc 失败时返回 out_of_memory，随后 primitive init 不创建 kernel。

kernel 参数为 src/dst/input_off/sp_stride/sp_loop_size/cb_loop_size；每 spatial run 重置 table cursor 和 cb count，每 cb chunk `vsetvli(vl,cb,e32,m4,ta,ma)` 读 offsets，切换 16-bit 时 `vsetvli(x0,vl,e16,m2,ta,ma)`，`vluxei32_v` gather，按 dtype `vse16/vse32` pack；dst 按 dtype bytes，offset cursor 按 4 bytes，input base 每 run 加 `sp_stride`。execute 按 MB×nb_c×sp tiles 分工，src base 为 `mb*stride_mb+sp0*blk`，dst base 为 `(base+sp*c_curr)*dt_size`，input_off 指向对应 C block。

### 6.3 Shuffle 差异处置

- SH-1：x64 JIT 仅 blocked，而 RV64 支持 plain 和 blocked；这是实现策略差异，不是错误。reference generic axis path提供 oracle。
- SH-2：RV64 仅 axis=1，x64同样 PD gate axis=1；generic reference 更宽不是 RV64遗漏。
- SH-3：f32/s32/f16/bf16 memory move 不需 arithmetic；RV64 的 16-bit path只需V，不会执行 Zvfh convert；`platform::has_data_type_support(f16/bf16)` 目前会要求 Zvfh/Zvfbfwma，因而 RV64 shuffle 在没有半精度转换扩展的 V-only 硬件上拒绝 f16/bf16，即便 shuffle理论上只搬运16位。这是可用性/过度拒绝候选而不是 correctness：PD 明确调用 platform dtype gate，若公开 API 允许 V-only 上的 raw f16/bf16 memory move，则该 gate 可能过窄；但平台整体是否有意把 f16/bf16 memory support 与 conversion ISA绑定尚需契约确认。状态候选 SH-4。
- SH-4：offset table 使用 uint32_t；PD max_off 公式覆盖最后 block/spatial/channel lane，且 `precompute_offsets()` 只写 <=max_off 的 table；kernel 的 `vluxei32` 是 byte offset。`conf.sp`、乘加使用 dim_t，只有最终窄化点已 gate；未发现遗漏。状态排除。
- SH-5：`tasks=MB*nb_c`、`div_up(nthr,tasks)`。后续主审计补充闭环：`memory_desc.cpp:48-63` 允许零维，`shuffle.cpp:53-54` 只约束 `group_size` 与 `dims[axis]`，`primitive_execute()` 无统一 zero-dim 短路，RV64 PD 亦无 zero-dim gate；合法 `MB=0,C>0,SP>0` descriptor 可达 execute 并以 `tasks=0` 调 `div_up`。该候选已升级为正式 `RV64-004`（见 `audit/findings/RV64-004-shuffle-zero-batch.md`）。
- SH-6：tail：blocked gate 要求 C%blk==0，plain blk=C 且 cb=1；因此 kernel cb tail 在当前可达 layout 实际不触发。`vsetvli` 以 cb 剩余数处理，sp tile 以 `sp_blk_size` 处理；无 stale lane 被 store beyond cb。状态排除。
- SH-7：forward/backward offset transpose 方向在 host 计算中相反且 kernel 只搬运；与 reference transpose 公式对应。状态排除。

## 7. #1677/#3457/#4890/#5174/#5370/#5594/#5839 五邻域审计

五类邻域定义：语法克隆、结构克隆、语义同族、时间邻域、调用图邻域。以下每条都搜索过相关 RV64/common/x64/test/CI 源码；命中相似代码不自动升级。

| 历史线索/不变量 | 语法/结构命中 | 语义同族与调用图 | 时间邻域 | 当前处置 |
|---|---|---|---|---|
| #1677：max 初值必须是算法边界 | RV64 reduction 的 max=-inf/f16 lowest；softmax max=-inf；resampling 无 reduction max；shuffle 无 arithmetic | reduction kernel 的 `vfmax/vfredmax`、softmax scalar/JIT max；pooling 同族显式 NaN/max 修复 | reduction 于 #5361 新增，softmax #4890 后又在 #5888 扩 f16/bf16 | 初值静态正确；reduction NaN 语义单列 R-1 候选 |
| #3457：默认 format 先建立；空窗口不得访问 | softmax/reduction/resampling/shuffle 均先 default format 后 dense/tag 检查；resampling post-op src1 any 先 default | resampling execute 无空 window 概念，spatial indices由合法 dims生成；softmax/reduction/resampling reject zero dim，shuffle 接受 zero batch 后缺少 execute guard | #3457 早期 pooling 修复；RV64 四路径为后续 JIT 代码 | format 顺序差异排除；shuffle zero-work 已闭环为 RV64-004 |
| #4890：all -INF 不能产生无效中间 NaN | softmax f32/xf16 均 `all_minus_inf` zero path；普通 logsoftmax 不应使用 inf_as_zero 特例 | x64/reference 都只对 `softmax_accurate_inf_as_zero` 特殊处理；xf16 max +INF/NaN 走 scalar | RV64 #4890 修复已扩展到 #5888 dtype templates | 等价，排除 |
| #5174：验证过的 alpha/beta 必须消费 | 本范围四 primitive 中只有 resampling eltwise post-op；RV64 injector 保留 alpha，`relu` emits `alpha*x`，resampling gate/chain消费顺序清晰 | `jit_uni_postops_injector`/eltwise injector 也被 pooling/binary 等使用；resampling `post_ops_ok` 先去 sum再注入 | #5174 默认 helper 修复；#5370 后 injector 显式 compare/merge | resampling alpha path静态闭合；排除 |
| #5370：RVV min/max 的 NaN 语义 | 直接命中 reduction `vfmax_vv/vfmin_vv`、`vfredmax/min`；softmax xf16 max 已改显式 NaN detect；resampling arithmetic 无 min/max；shuffle无 arithmetic | reduction max/min 是调用图内唯一仍直接使用 RVV float max/min 的目标实现；injector本身已改 NaN-preserving compare/merge | #5370 后的 injector 修复未同步到 #5361 reduction kernel | R-1 高信号候选，需 NaN contract + dynamic；不创建 finding |
| #5594：counter/offset覆盖dim_t且乘加不溢出 | target execute 多用 dim_t；shuffle table最终 uint32有max_off gate；resampling `int dt_size/num_corners`仅小常量；softmax nthr int来自线程API | reduction `reduce_size` dim_t；softmax `outer*inner`/scratch size；resampling `p_dst-dst0` dim_t；shuffle `MB*nb_blk/tasks` dim_t | #5594 明确覆盖 RV64；新代码时间邻域 #5361/#5506/#5850/#5888 | 未发现同样 int bound bug；记录 overflow-adjacent 验证缺口 |
| #5839：临时区容量/线程分片/生命周期一致 | softmax `ithr*axis_size` reduction/interim；resampling binary rhs pointer scratch；reduction无scratch；shuffle input offsets heap | softmax execute/get key与booking key一致；resampling booking只在 fuse_binary且execute只在 fuse_binary读；shuffle heap ownership ctor/dtor | #5839 直接修复 f16 softmax，#5888新增 bf16共享模板 | softmax静态等价；resampling JIT codegen status C-3另列 |

## 8. Capability matrix（验证维度）

| 轴 | softmax | reduction | resampling | shuffle |
|---|---|---|---|---|
| dtype | f32/V；f16/Zvfh；bf16/Zvfbfwma；同 dtype src=dst | f32/f16，src/dst f32/f16；无 bf16/int | f32/V；f16/Zvfh；同 dtype；无 bf16/int | f32/s32/f16/bf16；PD仍依 platform 半精度 gate |
| algorithm | softmax accurate/inf_as_zero/logsoftmax | sum/mean/max/min | nearest/linear | channel shuffle axis=1 |
| layout | plain dense, src==dst MD；axis physical contiguous或gather | dense canonical x/nc/ncw/nchw/ncdhw，同 tag，末尾连续 reduction | plain ncsp/nspc 或单 inner C block blocked；src/dst blocks相同 | plain nc/nwc/nhwc/ndhwc；blocked C4/C8/C16 且 C整除 |
| attributes | only default | only default | sum (zp=0, dtype undef/d_type)、eltwise injector subset、f32 one binary subset | default only |
| padding | plain `is_dense(true)` potentially padded；未清 padding候选 C-2 | common set_dst_format may preserve block padding; target tag subset；无 explicit output pad handling | last blocked C tail host zeroes | blocked C tail rejected by C%blk; plain no padding-specific path |
| special values | f32/xf16 NaN, +INF scalar fallback；all -INF special only inf_as_zero | max/min direct RVV NaN unresolved R-1；sum/mean IEEE accumulation | interpolation propagates NaN by arithmetic; no min/max | bit-preserving memory move |
| VLEN/tail | dynamic vl, axis/vector thresholds 16; no fixed VLEN in loops | dynamic vl e16/e32, m4/m8；短尾更新后错误用 VLMAX 读取 accumulator（RV64-002） | dynamic vl on C chunks, m1/m2; C tail | dynamic vl on cb chunks; current blocked gate removes C tail |
| scratch/thread | softmax per-thread axis buffers; C-1/C-2 checks | none | one rhs pointer slot if binary; C-3 lifecycle | aligned heap input table, no primitive scratch |

## 9. 候选与排除清单

### 9.1 当前候选（不等于最终 finding）

1. **C-1 softmax JIT codegen failure status 被丢弃**。位置：`src/cpu/rv64/rvv_softmax.cpp` 构造函数调用 `new jit_rvv_softmax_affine_kernel_t()`；`jit_rvv_softmax_kernel.cpp` affine constructor 调 `create_kernel()` 但返回值无处保存。影响：构造成功但 `jit_ker_==nullptr` 时 f32 JIT affine 调用可能在 execute 发生无效函数指针。证据层：A2/A3 生命周期静态证据；缺少合法失败触发器，候选。
2. **C-3 resampling JIT codegen failure status 被丢弃**。位置：`src/cpu/rv64/jit_uni_resampling_kernel.cpp:35-42` constructor 中 `create_kernel()` 无检查；primitive `init()` 的 `safe_ptr_assign` 只管分配。影响同上，且所有 RV64 resampling dtype/alg kernel 构造路径。候选。
3. **R-1 reduction max/min NaN 语义差分**。位置：`src/cpu/rv64/jit_uni_reduction_kernel.cpp:182-183,224-236` 直接 RVV max/min；共同历史 #5370 证明同类直接 min/max 需要显式保留 NaN。触发为合法 reduction max/min 输入含 NaN；是否违反公开 reduction contract尚需确认，候选。
4. **C-2 softmax plain padded output lane 未显式清零**。位置：`rvv_softmax_fwd_t::pd_t::check_layouts()`允许 dense(true) plain；execute只处理 logical axis。x64/reference有padding处理。当前 descriptor可达性和oneDNN padded plain contract未闭环，低置信候选。
5. **SH-4 shuffle 对 f16/bf16 raw move 仍要求 conversion ISA**。位置：`rv64/shuffle/jit_uni_shuffle.hpp:79-82` 调 `platform::has_data_type_support(dt)`，而 kernel仅e16 load/store。可能造成 V-only 硬件上合法 raw shuffle fallback/availability损失；需 API/platform contract确认。

SH-5 已由公共 zero-volume 约定、descriptor/PD 可达链和 execute/helper 前置条件闭环并升级为 `RV64-004`，不再列入当前候选。

### 9.2 已排除/不升级

- softmax backward、resampling backward 无 RV64 注册：明确 capability/fallback，不是缺陷。
- RV64 softmax 拒绝 scales/post-op/dropout，reduction 拒绝 post-op/bf16/int，resampling 拒绝非 f32/f16/复杂 post-op，shuffle 拒绝非 axis=1/不支持 layout：均为 PD 明确返回 unimplemented 后 fallback。
- x64 blocked 与 RV64 plain/不同 tile：架构布局策略差异，不能仅凭文本 diff 报错。
- #4890 all `-INF`：f32 与 xf16 都显式 zero，logsoftmax 不适用该特殊算法；排除。
- #5174 alpha：resampling 注入器构造使用 entry 的 alpha/beta，RV64 relu/eltwise 代码消费参数；没有“只检查不消费”证据，排除。
- #5839 scratchpad：f16/bf16共用的 reduction/interim booking按 nthr/axis分片，execute key一致，排除。
- #5594：目标 counter/offset主要为 dim_t/size_t；shuffle UINT32窄化有 max_off gate；没有已闭环的 int overflow finding。
- 所有仅属性能（JIT threshold 16/8192、tile、分线程策略）的差异：排除 correctness finding。

## 10. Benchdnn/gtests/CI 静态覆盖

### 10.1 gtests

- `tests/gtests/test_softmax.cpp`：f32/bf16/f16 forward/backward、多 axis、nc/ncw/nchw/nhwc/blocked、any descriptor；未见 NaN/±INF/±0、all-`-INF`、padding lane、RV64 VLEN/ISA组合专用值。backward case 会在 RV64 命中 reference，不能验证 RV64 forward-only实现。
- `tests/gtests/test_reduction.cpp`：f32/bf16/f16/s8/u8 fixture；simple reduction、mean/norm failure、zero/invalid descriptor；但 RV64 PD 对 bf16/int/norm 直接 fallback，且填充为普通随机值，无 NaN max/min 或 huge dim。
- `tests/gtests/test_resampling.cpp`：f32 plain/blocked 1D/2D/3D nearest/linear，forward+backward reference oracle；未见 f16 RV64 fixture、post-op属性、NaN/INF、VLEN/C tail/stride极值。测试期望 `check_zero_tail`，但当前主要是普通 blocked cases。
- `tests/gtests/test_shuffle.cpp`：f32/bf16/f16/u8/s8，plain/blocked，多 axis/group/forward/backward；RV64仅目标支持的 f32/s32/f16/bf16，u8/s8 fallback reference；无 V-only 半精度 ISA组合、UINT32近边界、大 C/SP、zero-dim执行。

### 10.2 benchdnn

`tests/benchdnn/softmax` 的 filler 主要生成正/负 top values 和 overflow-adjacent普通值；`SOFTMAX_INF_AS_ZERO` 通过内部 alg kind 选择，但未见默认 buffer 直接注入 NaN/±INF/±0。softmax driver 明确 skip sum post-op，且 `setup_cmp` 允许 xf16误差；未通过 `--impl`/verbose 确认 RV64目标实现。

`tests/benchdnn/reduction` ref 支持 max/min/sum/mean/mul/norm；f16 cases关注范围/舍入，但没有 NaN/±0 的定向 max/min；RV64 只可达 f32/f16四算法且默认属性。

`tests/benchdnn/resampling` ref 覆盖 nearest/linear、1D/2D/3D 和 layout；源码显示普通数值 oracle，未见 NaN/INF、post-op chain、C tail、V-only/无Zvfh矩阵。`tests/benchdnn/shuffle` ref 是 generic memory reorder，测试输入通常普通填充值；未见 UINT32 offset boundary 或 ISA缺失组合。

### 10.3 CI

`.github/workflows/ci-riscv.yml` 的 PR test matrix 仅 QEMU `v=true,zvfh=true,zvfbfwma=true,vlen=128/256,vext_spec=v1.0`，OMP，SMOKE；`.github/workflows/weekly-riscv.yml` 仅 VLEN=128，CI 分十片。`.github/automation/riscv/skipped-tests.sh` 在 SMOKE 跳过 pooling forward/backward 等长测，CI 跳过 matmul/ip/graph，不直接列出本四类目标，但 SMOKE/weekly 仍未覆盖无 V、V-only、无Zvfh、无Zvfbfwma、VLEN 512/1024。未运行 CI。

因此“CI通过”不能排除 R-1/C-1/C-3/C-2/SH-4，也不能反证已经静态闭环的 RV64-002/RV64-004；尤其 reduction NaN、JIT failure path、padding lane 和 ISA组合均没有静态测试闭环。

## 11. A0-A4 逐项状态表

| ID | A0 注册 | A1 PD/config | A2 resource | A3 execute | A4 kernel | 分类/状态 |
|---|---|---|---|---|---|---|
| softmax f32 | RV64 forward 位于 ref 前 | V，plain dense，同 dtype，默认 attr | interim only when inner>1；nthr bounded；affine JIT status ignored | contiguous/strided gather+scatter | dynamic VL exp/affine；NaN ordinary f32 follows scalar formula | C-1 candidate；C-2 low candidate |
| softmax f16/bf16 | RV64 forward；ISA-specific name | Zvfh/Zvfbfwma，bf16 logsoftmax rejected | reduction per-thread + optional interim | xf16 gather/scatter and scalar fallback for NaN/+INF | widen/narrow and all-`-INF` | equivalent/history fixed |
| softmax backward | no RV64 item | N/A | N/A | reference | reference | capability exclusion |
| reduction f32/f16 | RV64 after x64 | V/Zvfh，sum/mean/max/min，tail reduction | none | dim_t linear offsets | direct vfmax/vfmin/vfred + widening sum | RV64-002 confirmed；R-1 candidate |
| reduction bf16/int/norm/post-op | RV64 PD rejects | fallback | reference | reference | reference | capability exclusion |
| resampling f32 | RV64 `<v>` after `<zvfh>` | V, f32, nearest/linear, channel-inner layouts | binary rhs slot only; constructor status ignored | MB×Cb×spatial, host corners | dynamic C VL, f32 post-op/sum | C-3 candidate |
| resampling f16 | RV64 `<zvfh>` before `<v>` | Zvfh, f16, eltwise/sum subset | same | f16 gather/linear/narrow | e16/e32 widen/narrow | capability equivalent |
| resampling backward | no RV64 | N/A | N/A | simple/reference | reference/simple | capability exclusion |
| shuffle | RV64 after x64/AArch64 | V, axis1, f32/s32/f16/bf16, plain/C-block | heap uint32 offset table; free in dtor | MB×block×sp tiles；zero-task division | vluxei32 gather + pack | RV64-004 confirmed；SH-4 candidate；offset safety excluded |

## 12. 未来最小动态验证（本轮不执行）

优先级按“先闭环高信号语义，再生命周期/边界，再能力矩阵”排列。每次必须用 `ONEDNN_VERBOSE=all` 确认实际实现名，correctness 使用 `--mode=C --fast-ref=false`，并用 `--impl` 子串二次确认；本草稿不执行命令。

1. **R-1 NaN max/min**：reduction f32/f16，`reduction_max/min`，src dims `{1,1,1,N}`→dst `{1,1,1,1}`，N∈{1,7,16,17,31,32,33}；输入 `[NaN, -3, +0, -0, +INF, -INF]` 的单项/尾块组合；V=128/256，threads=1/2/max；比较 reference 与 RV64，记录 NaN payload/quieting及±0。若 API contract要求传播且 RVV直接 reduction改变结果，升级为最终 finding。
2. **Softmax special values**：f32/f16/bf16 forward，axis lengths 1/15/16/17/31/32/33，plain ncw/nchw/nhwc；普通 accurate、`accurate_inf_as_zero`、logsoftmax；每行 all `-INF`、one finite+`-INF`、`+INF`、NaN、±0。对比 reference，验证 #4890和xf16 scalar fallback，且确认 vector exp只在 axis>=16时命中。
3. **Softmax padding/strides**：构造合法 plain dense padded axis descriptor，src/dst out-of-place，prefill output padding NaN；axis 0/1/last、f32/f16/bf16、inner_size 1和>1。检查 logical output、padding是否保持/清零，若 descriptor不合法需记录不可达证据而关闭 C-2。
4. **JIT failure path**：在不改变产品源码的验证分支/测试替身中让 Xbyak `generate/ready/getCode` 返回失败，或使用可控 code buffer limit；softmax f32与resampling f32/f16创建 primitive，期望 primitive creation 返回 runtime_error/不进入 execute，而不是 null code call。若环境无法注入失败，保留静态候选并说明限制。
5. **Resampling numeric/tail**：f32/f16，nearest/linear，1D/2D/3D；C∈{1,2,3,7,8,15,16,17}，plain ncsp/nspc、blocked C4/C8/C16，spatial output odd/even；padding-free合法尺寸，输入含 NaN/±INF/±0；sum scale、eltwise alpha、f32 binary scalar/per-oc/full-dst（仅 f32）。VLEN=128/256、threads=1/max，和 reference 对照。
6. **Shuffle capability/large offsets/zero work**：V-only(no Zvfh/no Zvfbfwma) 上 f16/bf16 raw shuffle，观察是否应 fallback reference或当前 API明确不支持；V+扩展上 f32/s32/f16/bf16，plain/blocked，axis=1，group=1/C/非平凡 group；C/SP/MB 组合接近 UINT32_MAX但不超过，另一个超过 gate应返回 unimplemented；threads=1/max。另用合法 `MB=0,C>0,SP>0` descriptor 验证 RV64-004：预期成功 no-op 且不访问 buffer，debug/release 均不得进入 `div_up(nthr,0)`。
7. **VLEN/ISA矩阵**：QEMU `vlen=128/256`，必要时 512/1024；V-only、V+Zvfh、V+Zvfbfwma、无 V；每种只创建其合法 dtype实现，确认没有 SIGILL，且无扩展时列表继续 fallback。真实硬件另测 SIGILL probe handler恢复和并发 singleton，但超出本轮静态结论。

## 13. 审计边界与未覆盖

- 没有运行时环境，因此本专题保留的 C-1/C-2/C-3/R-1/SH-4 仍是静态候选；主审计依靠完整静态证据将 R-5/SH-5 分别确认为 RV64-002/RV64-004，并生成最终 finding 文件，不声称动态复现。
- 没有审查 pooling、binary、normalization 等产品实现，只在 #1677/#5174/#5370 调用图邻域中读取共享 injector/历史证据；跨 primitive 可能存在的缺陷不纳入本草稿 finding。
- 没有把开放 PR 当作当前基线证据；基线产品树与 HEAD 相同，但后续历史/开放代码只用于定位邻域。
- 没有执行编译器静态诊断、QEMU、sanitizer、benchdnn、gtests、verbose 或动态 codegen failure 注入。
- 对 R-1 的最终判断依赖 oneDNN reduction NaN API契约和 RVV `vfredmax/min`具体 NaN规定；仅凭 `#5370` 类比保留候选。
- C-2 仍依赖合法 padded descriptor 契约；SH-5 的 zero-volume descriptor、RV64 PD 和 execute 可达性已经静态证明并升级。

## 14. 工作树收尾记录

本文件保留专题审计的证据链，但状态已在交付前与总报告、覆盖台账和正式 finding 对齐：R-5 -> RV64-002，SH-5 -> RV64-004，其余候选保持未升级。整个静态审计未修改产品源码或测试；最终 Git 范围和提交状态以总报告的交付检查为准。
