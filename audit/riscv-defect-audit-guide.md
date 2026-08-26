# oneDNN RV64 缺陷审计智能体指导书

> 审计基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`（oneDNN 3.14.0）
> 编制日期：2026-08-26
> 配套资料：[项目源码地图](source_maps/01-project-source-map.md)、
> [x64 源码地图](source_maps/02-x64-source-map.md)、
> [RV64 源码地图](source_maps/03-rv64-source-map.md)、
> [RISC-V 开发与缺陷修复历史](riscv-development-history.md)

## 1. 目标与执行契约

本文把两种审计思路整理为一套可交给智能体执行的双轨方法：

1. **跨架构语义差分**：以成熟的 x64 路径为实现参照，审查 RV64 中承担相同语义的注册、
   primitive descriptor（PD）、配置、资源和内核代码。
2. **历史修复扩散审计**：以 RV64 的历史 bugfix 为线索，提炼错误不变量，再检查其上下游、克隆、
   同族实现和后续演进代码是否仍包含相同根因。

本文使用 oneDNN 仓库中的正式目录名 **x64**，它对应本任务所说的 x86 成熟路径。

最终目标不是列出“RV64 与 x64 不同”的代码，而是找出**可达、违反 oneDNN 语义或安全不变量、
且经过独立证据验证**的 RV64 缺陷。

相对原始思路，关键完善如下：

| 原始思路可能留下的空白 | 本指导书的处理 |
|---|---|
| 把 x64 当作唯一正确答案 | 改为分层 oracle；先由 API/数学契约定义正确性，再用 x64 发现缺口 |
| 直接比较目录、文件或指令 | 改为比较“注册 → PD → 配置/资源 → execute → kernel”的语义责任 |
| 看到差异就报告 | 先分类等价、合法架构差异、不可比和可疑差异，再验证可达性 |
| 只搜索历史修复后的代码行 | 把补丁规范化为触发条件、根因、不变量、negative/fix pattern 和逃逸原因 |
| 只查同文件的相似代码 | 扩展到语法、结构、语义、时间和调用图五种邻域 |
| 用单次测试佐证 | 确认实际 implementation，并覆盖 reference、特殊值、属性、VLEN、ISA 和 CI 逃逸面 |
| 优先级、严重性和置信度混用 | 分别维护验证排序、影响严重性和证据置信度 |

执行审计的智能体必须遵守以下约束：

- 开始时记录分支、`HEAD`、构建选项、编译器、运行环境、QEMU/硬件型号、ISA 和 VLEN；报告中的
  行号和结论只对记录的基线负责。
- 先读完四份配套资料，再读实现；不要仅凭文件名猜测 x64/RV64 对应关系。
- 默认只审计和记录，不修改实现、测试、Git 历史或远端状态；只有用户明确要求修复时才改代码。
- 不把 x64、现有测试或历史补丁中的任何一个单独视为绝对真值。
- 每个候选点都必须记录可达路径、前置条件、被破坏的不变量、反证检查和验证状态。
- 找不到 RV64 执行环境时可以产出静态候选，但必须明确标记“未动态验证”，不得伪称已复现。

缺陷范围包括错误结果、崩溃/越界/未定义行为、错误接受不支持配置、错误 fallback、ISA 误分派、
并发/生命周期错误及构建可移植性错误。纯性能差异不属于本指导书的缺陷，除非它同时造成错误结果、
不可用、资源失控或违背公开行为。

## 2. 为什么需要“分层 oracle”

跨实现差分测试能够发现单一实现自测遗漏的问题。Csmith 的编译器差分工作强调：输入必须有明确、
唯一的语义，否则 oracle 本身会被未定义或未指定行为污染；CRADLE 则表明，跨深度学习后端的不一致
检查还可以结合异常传播定位问题。另一方面，ReDeBug 和 FixMiner 展示了从历史补丁的删除模式、
编辑动作和上下文中寻找未同步修复克隆的价值。参见
[Csmith 论文](https://users.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf)、
[CRADLE 论文](https://www.cs.purdue.edu/homes/lintan/publications/cradle-icse19.pdf)、
[ReDeBug 论文](https://users.ece.cmu.edu/~jiyongj/papers/oakland12.pdf) 和
[FixMiner 论文](https://arxiv.org/abs/1810.01791)。

这些结论适用于 oneDNN，但要增加一层架构语义约束。x64 与 RV64 的指令、向量长度、tail 处理、
数据布局和累加次序本来就可能不同，所以采用以下证据优先级：

| 优先级 | oracle | 用法 |
|---:|---|---|
| 1 | oneDNN 公开 API、数学定义和共同代码契约 | 判断什么行为才是正确的；与其他证据冲突时优先 |
| 2 | benchdnn driver 自身参考计算 | 做结果验证；需要关闭可能复用优化 CPU 实现的 fast reference |
| 3 | 成熟 x64 实现 | 发现 RV64 遗漏的检查、阶段或边界处理，不直接判罪 |
| 4 | RISC-V 官方 ISA/RVV 规范及所用 intrinsic/JIT 接口 | 判断指令、VL/VTYPE、NaN、tail/mask 等架构语义 |
| 5 | RV64 历史提交、PR、Issue 和修复 diff | 提供已发生过的根因、逃逸条件和高风险邻域 |

oneDNN 公开规定 post-op 按附加顺序执行，而具体 primitive/实现可支持的组合不同；不一致的属性应在
PD 创建时被拒绝。相关依据见
[post-op 文档](https://uxlfoundation.github.io/oneDNN/dev_guide_attributes_post_ops.html) 和
[primitive attributes API](https://uxlfoundation.github.io/oneDNN/group_dnnl_api_attributes.html)。
RISC-V 侧应以[官方 ratified specifications](https://docs.riscv.org/reference/home/index.html)为准；
例如 RVV 的 tail/mask policy 以及 `vfmin`/`vfmax` 的 NaN 语义不能由 x64 指令习惯反推。

一个候选结论至少要回答四个问题：

1. **可达吗？** 注册顺序、ISA gate 和 PD 条件能否让目标实现真正执行？
2. **违反什么？** 是公开语义、安全边界、资源生命周期，还是仅与 x64 写法不同？
3. **有独立证据吗？** 参考计算、规范、历史修复、相邻成熟实现中至少还有一种证据吗？
4. **能反驳吗？** 架构差异、允许的浮点误差、fallback 或未支持配置能否解释现象？

## 3. 建立审计对象和覆盖台账

### 3.1 审计单元

不要把“一个文件”当作最小审计单元。一次可比较行为应表示为：

```text
(primitive, propagation kind, algorithm, data types, logical layouts,
 attributes/post-ops, dimensions/strides, fpmath mode, ISA/VLEN)
```

只有这些条件在语义上对齐，x64 与 RV64 的结果或检查才可比较。物理 blocked layout、内核 tile、
寄存器分配和指令序列不必相同。

### 3.2 从注册表出发

先从 `src/cpu/cpu_*_list.cpp` 中的 `CPU_INSTANCE_RV64` 条目建立当前真实覆盖，不要只枚举
`src/cpu/rv64/` 文件。推荐的只读命令如下：

```bash
git status --short --branch
git rev-parse HEAD
rg -n 'CPU_INSTANCE_RV64|DNNL_RV64_ONLY' src/cpu cmake .github
rg -n 'DECLARE_COMMON_PD_T|status_t init\(' src/cpu/rv64
rg --files src/cpu/rv64 src/cpu/x64 | sort
```

基线中可见的 RV64 注册族包括 batch normalization、binary、convolution、eltwise、group/layer
normalization、inner product、matmul、pooling、prelu、reduction、resampling、shuffle、softmax 和
reorder。每次审计都要重新生成列表，因为注册顺序和实现范围会变化。

为每个实现维护如下覆盖记录：

| 字段 | 内容 |
|---|---|
| RV64 实现名/注册位置 | 注册宏、优先级、`DECLARE_COMMON_PD_T` 返回的实现名 |
| x64 参照 | 对应实现或“无直接对应”及原因 |
| 共同语义 | primitive、prop kind、算法、dtype、layout、attributes |
| RV64 gate | 编译期条件、运行时 ISA、PD 条件 |
| 审计层 | 注册、PD、配置、资源、内核、测试 |
| 方法 A 状态 | 未审/已审/候选/排除 |
| 方法 B 命中 | 对应历史缺陷卡编号 |
| 动态覆盖 | 未运行/命中目标实现/fallback/环境阻塞 |
| 证据与待办 | 文件、命令、结果和下一步 |

### 3.3 语义对应地图

按职责而不是文件名对齐代码：

| 语义层 | x64 主要入口 | RV64 主要入口 | 核对重点 |
|---|---|---|---|
| ISA/JIT 基座 | `x64/cpu_isa_traits*`、`x64/jit_generator*` | `rv64/cpu_isa_traits*`、`rv64/jit_generator.hpp` | 编译/运行时能力、JIT 创建失败、缓存 |
| injectors | `x64/injectors/` | `rv64/injectors/` | 算法参数、特殊值、寄存器/辅助状态 |
| GEMM/BRGEMM | `x64/gemm/`、`x64/brgemm/` | `rv64/gemm/`、`rv64/brgemm/` | block、tail、K 累加、bias/post-op |
| MatMul/IP | `x64/matmul/brgemm_matmul*` 等 | `rvv_*matmul*`、`rvv_*inner_product*` | transpose、batch/broadcast、strides |
| Convolution | direct、1x1、BRGEMM、depthwise | 1x1、Winograd、GEMM/BRGEMM、depthwise | padding、im2col、group、首次/末次累加 |
| elementwise primitives | `jit_uni_*` | `jit_uni_*`、`jit_rvv_*` | PD 支持集、loop/tail、融合一致性 |
| reorder | `x64/reorder/` | `rv64/reorder/` | dtype conversion、saturation、offset |

若 x64 没有等价实现，改用共同 reference/generic 路径、API 定义和算法公式，不要强行配对。

## 4. 方法 A：跨架构语义差分审计

### 4.1 核心原则

x64 是“成熟实现参照”，不是 ground truth。方法 A 的产物应是**带解释的语义差异**，而不是文本 diff。
先分别还原两边的数据流和接受域，再比较是否完成了相同责任。

### 4.2 五层审计流程

#### A0：注册与 dispatch

从注册表顺序追到 `pd_t::init()`：

- RV64 实现是否在错误 ISA、缺少扩展或不合适 dtype 下可见？
- 更宽泛的 RV64 实现是否抢在更准确的实现之前，并在 PD 中过度接受？
- 本应由 RV64 优化实现承担的 case 是否因 gate/format 顺序错误而永久 fallback？
- “不支持”是否返回 `unimplemented` 让列表继续选择，而不是成功后静默忽略能力？
- 运行时探测是否真正发生在执行任何 RVV/Zvfh/Zvfbfwma 指令之前？

动态测试前必须用 oneDNN verbose 确认真正选中的实现。官方 verbose 文档见
[oneDNN verbose mode](https://uxlfoundation.github.io/oneDNN/dev_guide_verbose.html)。

#### A1：PD 与配置接受域

并排提取两侧 `pd_t::init()`、`set_default_params()`、`init_conf()` 的谓词，形成 capability matrix：

- propagation kind、algorithm kind、zero/runtime dimensions；
- src/weights/bias/dst dtype 与 accumulation dtype；
- `any` format 的默认化时机、plain/blocked layout、strides 和 dense 假设；
- post-op 的种类、顺序、mask、broadcast、alpha/beta；
- scales、zero-points、dropout、sum dtype、fpmath 和 scratchpad mode；
- ISA、VLEN、Zvfh、Zvfbfwma 等条件。

重点找两类不对称：

- **过度接受**：RV64 PD 返回成功，但执行阶段未消费某项属性、layout 或参数；这通常产生静默错误。
- **过度拒绝/误路由**：RV64 明明实现了该语义，却因默认 format 设置太晚、错误 dense 检查或 ISA
  条件导致不可达。它首先是功能/路由问题；只有违反公开支持或造成非法执行时才定为 correctness bug。

#### A2：资源和生命周期

对应检查 primitive 初始化、JIT kernel 创建和 scratchpad：

- booking 的元素类型、数量、对齐和乘法溢出；
- 每线程区域是否至少为 `nthr * per_thread_size`，线程索引是否可能越界；
- 执行路径使用的 scratchpad key 与 booking key 是否一致；
- kernel/resource 的所有权、失败路径和 cache key 是否覆盖所有影响代码生成的参数；
- 多次执行或并发 stream 是否复用可变临时状态；
- JIT `create_kernel()` 的失败是否被传播。

这里不要求 x64 与 RV64 资源布局相同，只比较生命周期不变量。

#### A3：执行包装层

沿 `execute()` 到 kernel call 检查：

- 输入/输出/weights/bias/scratchpad 指针是否按正确 dtype 和 layout 解释；
- batch、group、channel、spatial、broadcast 和线程分区的 offset；
- padding、dilation、stride、空窗口、零维和部分输出块；
- `first/last K`、beta、bias、sum 和 post-op 是否恰好执行一次；
- `int`、`unsigned`、`size_t`、`ptrdiff_t`、`dim_t` 混用和乘加溢出；
- tail 迭代是否会重复、遗漏或越界。

#### A4：JIT/intrinsic 内核语义

把指令序列还原为伪代码后与 x64/参考公式比较：

- reduction 初值和空集合处理；
- NaN、`±INF`、`±0`、denormal、saturation 和舍入；
- bf16/f16 widening、accumulation、narrowing 的时机；
- ReLU/ELU/clip 等非默认 alpha/beta 是否被保存并消费；
- post-op 的顺序是否与属性顺序一致；
- `vl` 是否随剩余元素正确更新，`vl=0` 是否安全；
- LMUL/寄存器组是否重叠，SEW/LMUL 切换后数据解释是否仍有效；
- tail/mask agnostic lane 是否会在之后被读取或整组存回；
- masked-off、padding 或 tail lane 是否可能携带上一轮的陈旧数据。

RVV 的 `vta/vma` 允许 tail/masked-off lane 为 agnostic 或 undisturbed；正确性来自“无效 lane 后续不被
观察”，而不是默认假设它们为零。浮点 min/max 则要核对指令的 `minimumNumber`/`maximumNumber`
语义是否符合目标算法，参见
[RISC-V V specification](https://github.com/riscvarchive/riscv-v-spec/blob/master/v-spec.adoc)。

### 4.3 差异分类

每个差异只能落入以下一种状态：

| 状态 | 含义 | 后续动作 |
|---|---|---|
| 等价 | 写法不同，但接受域和可观察语义等价 | 记录后关闭 |
| 有依据的架构差异 | ISA、layout、VLEN 或性能策略造成，规范/API 允许 | 写明依据后关闭 |
| 可疑遗漏 | x64/共同路径承担了一个必要责任，RV64 没有 | 转入验证 |
| 可疑过度接受 | RV64 声称支持，却没有完整实现 | 优先验证 PD 与结果 |
| 可疑算术/边界差异 | 特殊值、offset、tail、累加或转换可能改变结果/安全 | 构造最小 case |
| 不可比 | 前置条件不等价或无 oracle | 补充契约，不能报 bug |

常见的合法差异包括 ISA-specific blocked format、tile 大小、寄存器分配、mask 与动态 `vl` 的不同实现、
允许误差内的浮点累加次序，以及 RV64 正确返回 `unimplemented` 后由其他实现接管。它们不能仅凭 diff
进入缺陷报告。

### 4.4 方法 A 记录模板

```markdown
#### A-<primitive>-<number>: <差异标题>

- 审计单元：
- x64 路径 / RV64 路径：
- 共同前置条件：
- x64 承担的语义责任：
- RV64 行为：
- 差异分类：
- 契约/规范依据：
- 可达性证据：
- 可能的架构解释：
- 最小验证矩阵：
- 状态：候选 / 排除 / 转 finding
```

## 5. 方法 B：历史修复扩散审计

### 5.1 从“补丁”提升为“缺陷不变量”

不要只搜索修复后的某一行。一个历史修复要规范化为缺陷卡：

| 字段 | 要回答的问题 |
|---|---|
| 引入与修复 | 哪个提交/PR 引入，哪个提交/PR 修复？ |
| 触发条件 | dtype、layout、shape、attribute、ISA、线程和特殊值是什么？ |
| 症状 | wrong result、crash、OOB、SIGILL、fallback 还是 build failure？ |
| 根因 | 错误假设位于 PD、配置、资源、执行还是内核？ |
| 被破坏的不变量 | 用不依赖具体变量名的一句话描述 |
| negative pattern | 修复删除或替换了什么代码/控制流？ |
| fix pattern | 新增了什么 guard、状态传播、类型或算法？ |
| 逃逸原因 | 哪类测试、VLEN、特殊值或路由没有覆盖？ |
| 扩散轴 | dtype、fwd/bwd、layout、primitive、融合/独立、JIT/intrinsic 等 |
| 上下游 | 哪个调用者提供前置条件，哪些消费者受影响？ |

推荐命令：

```bash
git log --all --oneline -- src/cpu/rv64 cmake/toolchains/riscv64.cmake .github/automation/riscv
git show --stat <fix-commit>
git show --find-renames <fix-commit> -- src/cpu/rv64 src/cpu/x64
git blame -L <start>,<end> <file>
git log -S'<removed-or-added-token>' --all -- src/cpu/rv64 src/cpu/x64
git log -G'<structural-regex>' --all -- src/cpu/rv64 src/cpu/x64
rg -n '<negative-pattern>' src/cpu/rv64 src/cpu/x64 src/cpu
```

`git log -S` 适合寻找字符串计数发生变化的提交，`-G` 适合寻找 diff 中匹配结构模式的提交。二者结果
不能替代读完整 diff 和上下文。

### 5.2 五种扩散邻域

每张缺陷卡都必须沿以下方向搜索：

1. **语法克隆**：相同常量、表达式、helper 调用或 guard 的复制。
2. **结构克隆**：变量名不同，但循环、分支、offset 或 PD predicate 形状相同。
3. **语义同族**：f32/f16/bf16、fwd/bwd、NCHW/NHWC、JIT/intrinsic、独立 primitive/融合 post-op。
4. **时间邻域**：引入 PR 的后续重构、同一开发波次和修复前后新加入的 sibling kernels。
5. **调用图邻域**：上游 PD/config 是否保证假设，下游所有消费者是否都收到修复。

搜索到相似代码不等于搜索到缺陷。只有相同触发前置条件存在、同一个不变量仍会被破坏，并且没有
其他 guard/表示方式保证安全，才可升级。

### 5.3 当前基线的优先缺陷卡

详细历史见[开发与缺陷修复历史](riscv-development-history.md)。第一轮至少为以下谱系建立缺陷卡：
表中同时保留了 #5839 这类高信号的生命周期改进，但缺陷卡必须如实区分“已知 correctness bug”与
“提示风险边界的维护改动”，不能把后者改写成历史漏洞。

| 历史线索 | 已知不变量 | 必查扩散面 |
|---|---|---|
| [#1677](https://github.com/uxlfoundation/oneDNN/pull/1677) | max/reduction 初值必须代表算法单位元或正确边界 | pooling、reduction、softmax；f32/f16/bf16；空窗口 |
| [#3457](https://github.com/uxlfoundation/oneDNN/pull/3457) | 默认 format 要先建立；空窗口不得访问数据 | 所有 `set_default_params` 顺序、padding/dilation/stride |
| [#3486](https://github.com/uxlfoundation/oneDNN/pull/3486) | 能力试编译必须使用待验证 ISA flags | RVV/Zvfh/Zvfbfwma 探测、用户 `-march` override |
| [#4197](https://github.com/uxlfoundation/oneDNN/pull/4197) | PD 不得接受执行阶段未实现的 attribute | 所有 RV64 `has_default_values`、post-op/scales/zero-points/dropout |
| [#4445](https://github.com/uxlfoundation/oneDNN/pull/4445) | 声明的 layout 必须与 GEMM 解释一致 | transpose、batch broadcast、非连续 stride、reorder |
| [#4637](https://github.com/uxlfoundation/oneDNN/pull/4637) | padding 不能复用错误 offset 或向量化读取无效区 | im2col、convolution、pooling、左右/上下 padding |
| [#4890](https://github.com/uxlfoundation/oneDNN/pull/4890) | 特殊值路径不能用无效中间结果污染输出 | softmax 全 `-INF`、NaN、f16/f32 一致性 |
| [#5174](https://github.com/uxlfoundation/oneDNN/pull/5174) | 已验证的算法参数必须真正进入执行 | eltwise injector、融合 post-op、非默认 alpha/beta |
| [#5370](https://github.com/uxlfoundation/oneDNN/pull/5370) | RVV min/max 的 NaN 语义要匹配目标算法 | injectors 及其全部消费者、binary/pooling/reorder/prelu/reduction |
| [#5394](https://github.com/uxlfoundation/oneDNN/pull/5394) | 无 injector 的实现必须拒绝 post-op/scales/zero-points | depthwise 及新加入的窄 dtype kernels |
| [#5594](https://github.com/uxlfoundation/oneDNN/pull/5594) | loop counter/offset 必须覆盖 `dim_t` 范围且乘加不溢出 | 所有 `int` counter、大维度、scratchpad/address calculation |
| [#5839](https://github.com/uxlfoundation/oneDNN/pull/5839)（生命周期改进） | 临时缓冲的容量、线程分片和生命周期一致 | softmax、reduction、normalization、per-thread scratchpad |
| [#5162](https://github.com/uxlfoundation/oneDNN/issues/5162) | bias/初始化必须覆盖每个输出，而非仅首次部分调用 | BRGEMM convolution、padding、`first_kpos`、部分 OW |
| [#4638](https://github.com/uxlfoundation/oneDNN/issues/4638) | 运行时不得在能力检查前执行目标不支持的指令 | 无 V、不同 VLEN、缺 Zvfh/Zvfbfwma、baseline translation unit |

### 5.4 修复完整性矩阵

每个历史根因都按下列轴展开；不适用的格子写明原因，不要直接跳过：

```text
dtype       : f32 | f16 | bf16 | s8/u8 | s32
direction   : forward | backward-data | backward-weights
layout      : plain | blocked | transposed | broadcast | non-contiguous
composition : standalone | fused post-op | primitive used as helper
kernel kind : scalar | intrinsic | JIT | GEMM | BRGEMM
boundary    : zero | one | tail | padding | huge | overflow-adjacent
ISA         : no V | V | +Zvfh | +Zvfbfwma | multiple VLEN
```

## 6. 两种方法的汇合与优先级

### 6.1 证据汇合

| x64/共同路径显示语义缺口 | 命中历史根因 | 处置 |
|---|---|---|
| 是 | 是 | 最高优先；优先做最小复现和影响面扩展 |
| 是 | 否 | 检查是否是新类别或合法架构差异 |
| 否 | 是 | 检查 x64 是否以不同方式满足不变量；继续查 RV64 同族 |
| 否 | 否 | 常规覆盖，除非规范或动态测试提供第三种证据 |

例如，审查历史 #5394 时，方法 B 给出“没有 post-op 执行器就必须在 PD 拒绝”的不变量；方法 A 再
比较 x64/RV64 depthwise 的 `has_default_values()`、`post_ops_ok()` 与 kernel 调用，即可发现是完整 gate、
合法能力差异还是仍有相邻实现过度接受。审查 #5370 时，则应先用 RVV 规范确定 `vfmin/vfmax` 的 NaN
语义，再把 x64/reference 的算法语义与所有 RV64 使用点配对；单纯搜索指令只能生成候选。

### 6.2 排序分数

用以下分数安排验证顺序，不把它冒充严重性或置信度：

```text
P = 2X + 2H + R + I + T - 2E
```

各项取 `0..2`：

- `X`：跨架构/共同路径证据强度；
- `H`：与已知历史根因的相似程度；
- `R`：目标路径可达性；
- `I`：潜在影响（静默错误、内存安全、跨 primitive 扩散等）；
- `T`：现有测试缺口强度；
- `E`：已有的合法架构差异解释，0 为无解释、2 为已由规范/契约证实。

`P >= 9` 优先，`6..8` 次优先，`<= 5` 暂存。若 `E=2` 已完全解释现象，通常应直接记入排除日志，
而不是靠其他加分保留。

置信度另行标记：

- **已确认**：有可重复 wrong result/crash/sanitizer 结果，或有可达路径上的形式化安全/API 违约证明；
- **高置信**：至少两个独立 oracle 指向同一不变量违约，但受环境限制尚未动态复现；
- **候选**：存在未解释差异，证据尚不闭环；
- **已排除**：规范允许、前置条件不可达、正确 fallback，或差异在容差内。

## 7. 智能体标准作业流程

### 阶段 0：固定基线和边界

1. 记录 `git status --short --branch`、`git rev-parse HEAD`；不得覆盖用户已有改动。
2. 读四份配套资料，确认基线是否一致；不一致时在报告中注明，而不是偷偷切换提交。
3. 记录可用的 native x64、RV64 hardware、QEMU、编译器和 sanitizer 环境。
4. 新建工作记录，不修改被审计实现。

### 阶段 1：建立全量覆盖账本

1. 从所有 `CPU_INSTANCE_RV64` 注册生成 primitive/实现清单。
2. 为每项寻找 x64 语义参照和共同 reference 路径。
3. 把共享基础设施（ISA/JIT、injector、GEMM/BRGEMM、reorder）作为独立条目；它们可能影响多个 primitive。
4. 标注当前 RISC-V CI 的测试集、skip 列表和 QEMU CPU/VLEN。

### 阶段 2：执行方法 A

对每个条目依次完成 A0 至 A4。先比较 PD 接受域，再读 kernel；若 case 根本不可达，不要花时间比较
内核细节。所有差异分类并写入记录，不能把“看起来不一样”留作结论。

### 阶段 3：执行方法 B

1. 对第 5.3 节每条历史谱系建立缺陷卡。
2. 从修复 diff 提取 negative/fix pattern 和语义不变量。
3. 搜索五类邻域，填修复完整性矩阵。
4. 将命中的覆盖账本条目与方法 A 记录互链。

### 阶段 4：收敛候选

1. 去重：相同根因影响多个文件时建一个主 finding，列出完整影响面。
2. 计算优先级，先验证“双 oracle 命中”的候选。
3. 对每个候选主动寻找合法架构解释和不可达证据。
4. 将排除理由写入日志，避免后续智能体重复调查。

### 阶段 5：动态验证

验证顺序从便宜到昂贵：

1. 静态证明注册与 PD 可达；
2. 最小 benchdnn correctness case；
3. 边界/特殊值/属性矩阵；
4. 不同 VLEN、ISA 和线程数；
5. sanitizer 或真实硬件复现；
6. 缩减为稳定 reproducer。

benchdnn 是 oneDNN 的主要 correctness harness，见
[benchdnn README](https://github.com/uxlfoundation/oneDNN/blob/main/tests/benchdnn/README.md)。通用流程：

```bash
ONEDNN_VERBOSE=all <benchdnn> --mode=C --fast-ref=false -v6 <driver-and-case>
ONEDNN_VERBOSE=all <benchdnn> --mode=C --fast-ref=false -v6 \
    --impl=<verified-rv64-implementation-name> <driver-and-case>
```

注意事项：

- 第一遍不要猜 `--impl` 字符串；从 verbose 输出取得准确实现名，再用过滤器验证。`--impl` 是子串
  过滤，过滤到末尾仍不匹配会得到 `SKIPPED`，详见仓库内
  `tests/benchdnn/doc/knob_impl_filter.md`。
- correctness 审计用 `--fast-ref=false`，避免优化 CPU 实现本身成为 reference；细节见
  `tests/benchdnn/doc/knob_use_fast_ref.md`。
- `--check-ref-impl=true` 只在预期必须命中优化实现时使用；合法 fallback 不能被误报。
- `--attr-same-pd-check=true` 可辅助检查 attribute 引起的 dispatch 变化，但某实现明确不支持属性时，
  fallback 本身可能正确，必须结合 capability matrix 判断。
- 用 `--repeats-per-prb=N` 放大 race、未初始化内存和偶发错误。
- 用 `--buffer-prefix` 提供包含 NaN、`±INF`、`±0`、denormal、极值和真实故障数据的输入。
- 浮点结果按 API fpmath mode 和 benchdnn 容差判断；不得默认要求不同架构 bitwise 相同。

当前 PR CI 主要在 QEMU 下使用 RVV 1.0、Zvfh、Zvfbfwma 和 VLEN 128/256，weekly full 重点覆盖
VLEN 128。审计时先读 `.github/automation/riscv/`、`ci-riscv.yml` 和 `weekly-riscv.yml` 的当前值，
然后优先补齐：

| 轴 | 最小建议值 |
|---|---|
| VLEN | 128、256；条件允许再测 512、1024 |
| ISA | 无 V、V、V+Zvfh、V+Zvfbfwma |
| dtype | 每个实现声明支持的全部 dtype，特别是 f16/bf16 与混合累加 |
| shape | 0、1、恰好一个 vector、vector±1、多块+tail、超大/溢出邻近 |
| layout | `any`、默认、plain/blocked、transpose、broadcast、非连续 strides |
| spatial | 无 padding、左右/上下不对称 padding、空窗口、dilation、stride>1 |
| attributes | 默认/非默认 alpha-beta、sum、binary、scales、zero-points、dropout |
| values | 正常随机、全负、NaN、`±INF`、`±0`、denormal、dtype 极值 |
| threading | 1、2、最大线程；多次执行和并发创建/执行（适用时） |

CI 的 skip 不是“已证明无问题”。必须逐条查看 `.github/automation/riscv/skipped-tests.sh`，判断目标
primitive 是否只因时长跳过，或根本没有 RV64 correctness 覆盖；对历史上从 CI/评审逃逸的形状建立
定向 case。

### 阶段 6：报告与复核

1. 让最小 reproducer 在干净进程中重复运行，保存完整命令和 verbose 实现名。
2. 对照 API、reference、x64、RVV 规范和历史证据，至少两路闭环。
3. 区分根因、触发条件、症状和影响面，不把多个症状重复计数。
4. 最后重新检查工作树；报告审计是否产生未提交文件。

## 8. 产物格式

建议把一次审计的过程产物放在独立目录，例如：

```text
audit/worklogs/rv64-<date>/coverage-ledger.md
audit/worklogs/rv64-<date>/history-cards.md
audit/worklogs/rv64-<date>/dismissed-candidates.md
audit/findings/RV64-NNN-<short-title>.md
```

### 8.1 Finding 模板

```markdown
# RV64-NNN: <标题>

- 状态：候选 / 高置信 / 已确认
- 严重性：critical / high / medium / low
- 审计基线：<commit>
- 环境：<compiler, build flags, hardware/QEMU, ISA, VLEN, threads>
- primitive / implementation：
- 涉及文件和符号：
- 来源：方法 A / 方法 B / 两者

## 摘要
## 可达路径（注册 → PD → execute → kernel）
## 触发条件
## 被破坏的不变量
## 根因
## x64/reference/API/RVV 证据
## 历史相似性和影响扩散面
## 最小复现命令
## 预期结果与实际结果
## 反证和误报排除
## 现有测试为何未捕获
## 修复方向（不在审计阶段直接改代码）
## 尚未解决的问题
```

严重性与置信度分开：稳定的低影响错误可以“已确认 + low”，潜在内存安全问题也可能只是
“高置信 + high”。没有执行证据时必须写明环境阻塞和静态证明边界。

### 8.2 排除记录模板

```markdown
- 候选：
- 差异来源：
- 排除结论：合法架构差异 / 不可达 / 正确 fallback / 容差内 / 重复根因
- 证据：
- 适用基线：
- 重新开启条件：
```

## 9. 误报防线

出现以下情况时不得直接报告缺陷：

- 只有 x64/RV64 文本差异，没有共同前置条件和可观察语义差异；
- x64 使用 blocked format，而 RV64 正确限制为 plain format 或返回 `unimplemented`；
- 不同累加次序仅造成 API/benchdnn 容差内差异；
- benchdnn 实际命中 reference 或其他实现，而不是待审 RV64 实现；
- 失败输入依赖 API 禁止的 descriptor、越界用户 buffer 或未定义调用；
- QEMU/编译器不支持所声明 ISA，故障来自环境与构建参数不一致；
- 历史 negative pattern 仍出现，但上游 guard 已证明错误前置条件不可达；
- 开放 PR 中有可能的修复，但当前基线尚未包含。开放代码只能作为线索，不能改变当前基线事实；
- 纯性能下降、不同 tile 或多一次/少一次合法转换，没有 correctness/availability 后果。

反过来，“现有测试通过”也不能排除缺陷，尤其是目标实现未命中、fast reference 共用了同类优化路径、
case 被 RISC-V skip、VLEN 单一或随机数据没有特殊值时。

## 10. 完成标准

一次完整审计只有同时满足以下条件才能结束：

- 所有当前注册的 RV64 primitive/实现都有覆盖账本记录，或写明排除范围和理由；
- ISA/JIT、injector、GEMM/BRGEMM、reorder 等共享层已按影响面单列；
- 第 5.3 节的每条高风险历史谱系都已建立缺陷卡并搜索五类邻域；
- 方法 A 的每个差异和方法 B 的每个命中都有最终处置，不留无说明的“可疑”；
- 检查了 RISC-V CI、weekly、QEMU 参数和 skipped tests 的当前状态；
- 每个 finding 都含可达性、明确不变量、至少两路证据以及 reproducer；不能复现时有具体环境阻塞；
- 没有仅凭“x64 不同”或“历史上修过相似代码”认定的缺陷；
- 报告列出已确认、高置信、候选、已排除和未覆盖项，不隐藏负结果；
- 最终记录工作树状态，且没有越权修改实现、提交或 push。

## 11. 可直接交给智能体的任务指令

```text
目标：审计当前 oneDNN 基线中的 RISC-V/RV64 correctness、安全、dispatch、ISA、资源与构建缺陷。

开始前：
1. 记录 branch、HEAD、worktree、编译器、构建参数、执行环境、ISA 和 VLEN。
2. 完整阅读 audit/riscv-defect-audit-guide.md 及其引用的四份本地配套文档。
3. 保护用户已有改动。默认只读审计，不修改实现、测试、Git 历史或远端。

执行：
1. 从 CPU_INSTANCE_RV64 注册建立覆盖账本，并为每个条目确定 x64/共同 reference 语义参照。
2. 对每个可达实现依次审查注册、PD、配置、资源、execute、kernel，输出有解释的语义差异。
3. 为指导书第 5.3 节的历史修复建立缺陷卡，从触发条件、根因和不变量搜索语法、结构、语义、
   时间和调用图邻域。
4. 汇合两种方法的候选，按 P 分数排序；主动寻找架构差异、fallback、容差和不可达等反证。
5. 用 ONEDNN_VERBOSE 确认目标实现，用 benchdnn --mode=C --fast-ref=false 验证；覆盖属性、特殊值、
   padding/tail/大维度、多线程、ISA 和多个 VLEN。审阅所有 RISC-V skip。
6. 每个确认 finding 必须给出可达链、不变量、根因、两个独立 oracle、最小复现、预期/实际和影响面。
7. 对排除项保留证据；不能运行 RV64 时把结论标为静态候选或高置信，并说明缺失的验证。

结束条件：满足指导书第 10 节。最终汇报 confirmed/high-confidence/candidate/dismissed/uncovered 数量、
最高优先发现、验证环境限制和 worktree 状态。未经用户授权不得修复、commit 或 push。
```

## 12. 方法论边界

这套方法擅长发现跨后端不一致、修复漏同步和历史根因复发，但不能保证穷尽所有新型缺陷。以下方向
仍需补充其他手段：fuzzing/属性生成、sanitizer、静态分析、并发模型检查、形式化整数溢出证明和真实
硬件差异测试。若双轨审计长期不再产生新候选，应优先扩充输入生成和 runtime instrumentation，而不是
不断放宽“相似代码即缺陷”的判定标准。
