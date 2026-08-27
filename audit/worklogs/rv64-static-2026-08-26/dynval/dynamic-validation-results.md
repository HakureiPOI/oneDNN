# RV64 动态验证记录(Spacemit K1 / X60)

- 日期:2026-08-27
- 审计基线:`8f49eae32bdec3674a9a98ea1524a85cd1f302db`(与静态审计同基线;源码经 `git archive` 从本仓库传输至板卡,无改动)
- 硬件:Spacemit K1,X60 8 核 @1.6GHz,VLEN=256,`/proc/cpuinfo` ISA 含 V + Zvfh、不含 Zvfbfwma;Zvfbfwma 经运行时指令探测确认不可执行(见下)
- 构建:Release/Debug 各一份,`ONEDNN_ENABLE_PRIMITIVE="PRELU;REDUCTION;SHUFFLE"`,`ONEDNN_BUILD_GRAPH=OFF`(完整配置、构建命令与全部探针编译命令见 `evidence/env/build-config.txt`)
- 探针:本目录 `reduction_tail_probe.cpp`、`prelu_nan_probe.cpp`、`shuffle_zero_batch_probe.cpp`、`shuffle_c_probe.c`、`vta_probe.c`、`divzero_probe.c`、`zvfbfwma_probe.c`、`build_probes.sh`
- 原始证据:`evidence/`(17 个本地可校验证据文件 + 2 份清单,共 19 个文件);本地可校验清单 `evidence/SHA256SUMS`(`sha256sum -c` 直接通过),板上未回传工件(库/benchdnn/探针二进制)的哈希在 `evidence/REMOTE-ARTIFACT-SHA256.txt`
- 板上运行目录:`/root/onednn-verify/`
- 所有命令均在父 shell 以 `timeout` 启动并记录退出码;探针自身不安装 signal handler

## 状态总览

| Finding | 动态验证状态 | 依据 |
|---|---|---|
| RV64-001 PReLU NaN | **部分动态确认**:本次测试矩阵中的 16 个 f32/f16 组合全部复现 qNaN→0 | `evidence/logs/prelu.log`,verbose 确认 `jit:rvv` |
| RV64-002 reduction tail | **未复现,结果不具反证性**:本次 e32/m8 `vfadd.vv` 微基准保留 tail,相关 reduction 路径未观察到错误 | `evidence/logs/reduction.log`(66/66 PASS)、`vta-probe.log` + `disasm/vta_probe-full.asm` |
| RV64-003 BF16 BRGEMM 栈对齐 | **动态验证受阻**:本次精简构建未包含 MatMul/BRGEMM consumer,且 Zvfbfwma 指令运行时探测不可执行,目标路径不可达 | `evidence/logs/zvfbfwma-probe.log`、`env/environment.txt` |
| RV64-004 shuffle 零 batch | **Debug 动态确认**(assert abort);**Release 该特定二进制未观察到可见故障** | `shuffle-dbg.log`、`shuffle-rel.log`、`shuffle-rel-extra.log`、`benchdnn-dbg-abort.log`、`disasm/shuffle-execute-{release,debug}.asm` |

## RV64-001 PReLU NaN

- 实现确认:verbose `prelu ... jit:rvv`(`evidence/logs/verbose-impl.log`)。
- 探针(权重 rank 与 src ndims 一致,`src/common/prelu.cpp:98`;1D 下 per_oc 与 scalar 同形去重):本次测试矩阵为 f32/f16 × {x,nc,nchw} × {full,scalar,per_oc} 去重后 8 个 shape/broadcast 组合 × 2 dtype = **16 个组合,16 个全部命中 `jit:rvv` 且 qNaN → 0**(f32 输出 bits=0x00000000,f16 输出 bits=0x0000)。
- 覆盖边界:矩阵仅含 plain layout(x/ab/abcd tag);NHWC、blocked layout、bf16(探测不可执行,见 RV64-003)等可达路径**未测**。oracle 依据是共同 reference 源码 `s > 0 ? s : s*alpha` 的静态语义(NaN 输入输出 NaN),非板上运行 reference 实现的验证。
- 结论:**部分动态确认**——已确认本次覆盖的 f32/f16 plain-layout case 均出现 qNaN→0;特殊值契约的最终裁定留给维护者。

## RV64-002 reduction tail(VLEN=256)

- 实现确认:verbose `reduction ... jit:uni`。
- 扫描矩阵(oracle:先按 f16 量化输入再求和、精确比较):f32/f16 × {max,min,sum,mean} × n∈{65,66,70,96,129,130,160,200}(64 个矩阵 case)+ 2 个控制组(extremum 在最终活跃 lane)= **66/66 PASS**。
- 根因隔离(`vta_probe.c`,反汇编 `evidence/disasm/vta_probe-full.asm` 含 `vsetvli zero,e32,m8,ta,ma` → vl=1 的 `vfadd.vv` 序列):**63 个 tail lane 0 个改变、无全 1 写入**。该结果只证明本次 e32/m8 `vfadd.vv` 微基准保留了 tail;66 个 reduction case 的通过则表明本次覆盖的实际 kernel 路径同样未观察到有害覆盖。
- 结论:缺陷在 X60 上**未复现,该结果不具反证性**。准确表述:RVV 指令本身合法,但软件错误地依赖 tail-agnostic lanes 保留旧值,破坏了 reduction 的有效 accumulator 不变量;在允许写全 1 的实现上仍会产生错误结果。静态审计定性不变,且不把单个微基准泛化为 X60 所有 `ta` 指令的固定行为。
- 形状修正:审计报告按 VLEN=128 给的 33/65,在 VLEN=256 上对应 f32 65 / f16-native 129,均已实测。

## RV64-003 BF16 BRGEMM 栈对齐

状态:**动态验证受阻**(两个独立原因,均已实证):

1. **指令层面**:`/proc/cpuinfo` ISA 字符串不含 Zvfbfwma 只是初步信号;oneDNN 实际用运行时 SIGILL 探测(`cpu_isa_traits.cpp` 的 `probe_zvfbfwma_impl`,执行 `vfwmaccbf16.vf` 0xee655157)。本验证用**相同指令编码、相同 SIGILL-guard 模式**的 `zvfbfwma_probe.c` 实测:**SIGILL trapped,指令不可执行**(`evidence/logs/zvfbfwma-probe.log`,反汇编 `disasm/zvfbfwma_probe-full.asm`)。因此该板上 BF16 BRGEMM PD gate(`mayiuse(zvfbfwma)`)不可能通过。
2. **构建层面**:本次构建 `ONEDNN_ENABLE_PRIMITIVE="PRELU;REDUCTION;SHUFFLE"` 未包含 MatMul/inner-product/convolution 等 BRGEMM consumer,即使扩展可用也无法从该构建进入目标路径。

结论:**本次精简构建和现有环境未提供目标路径,验证未执行**。这不构成"X60 一定不支持 Zvfbfwma"的一般性断言(尽管运行时指令探测与 ISA 字符串一致指向该结论),更不构成对 finding 本身的任何证伪。完整验证需在支持 Zvfbfwma 的环境:`OMP_NUM_THREADS=1` + verbose 确认 `brgemm:rvv_zvfbfwma` + JIT dump,在实际生成代码中确认 `addi sp,sp,-56`/`+56`。

## RV64-004 shuffle 零 batch

- PD 确认接受 zero-batch descriptor(`MB=0,C=4,W=1,axis=1,group=2`,fwd/bwd 均 `impl: jit:rvv`)。
- **Debug:assert abort 全量复现**——C++ 探针 fwd/bwd × OMP 线程 1/4/8(6 组)+ C API 探针(1 组)= **7/7 在 `utils.hpp:367` 触发 `assert(b > 0)`(SIGABRT,exit=134)**;benchdnn `--mode=C --shuffle 0x4x1` 同样 abort(`benchdnn-dbg-abort.log`)。Debug 库反汇编(`disasm/shuffle-execute-debug.asm`)显示 `execute()` 三次调用未内联的 `utils::div_up`(断言位于该函数内)。
- **Release:该特定二进制未观察到可见故障**——C++ 探针 6/6 exit=0(zero-work 干净完成);benchdnn f32/f16/s32 × fwd/bwd 共 6 组全部 PASSED,3D `--tag=ncw/nwc` 亦 PASSED(`shuffle-rel.log`、`shuffle-rel-extra.log`)。
- Release 机制证据链:
  - `divzero_probe.c`:RISC-V `div` 指令除零不 trap、返回 -1(裸指令实测);微基准中第一个 C 除法编译为 `div`。
  - **实际库反汇编**(`disasm/shuffle-execute-release.asm`):release `libdnnl.so.3.14` 的 `jit_uni_shuffle_t::execute()` 内联了同一结构——`0x6095ec: bge s2,a0`(tasks≥nthr 检查)与 `0x6095f8: div a0,a0,s2`(内层 `div_up(nthr,tasks)`)、`0x60942e/0x60943a: div s8,s0,s8` / `div s0,s0,s8`(外层),零除数路径在 MB=0 时实际经过这些 `div` 指令。
  - 结论:Release 的实际成功行为与该除零机制一致(RISC-V `div` 除零返回 -1 → `div_up` 得 0 → `nstl::max(1,...)` 钳为 1 → `parallel_nd(0,...)` 早退)。**源代码仍为 C++ 除零 UB**;"未观察到故障"仅描述该特定二进制(该硬件+GCC 13 组合)。
- `0x4x64` 是 3D `{N,C,W}` 描述,verbose 显示其默认 tag 为 `abc`。当 `W=64` 时该 plain `ncw` 布局不匹配 RV64 PD 支持的 blocked/nspc tag,故在 `jit_uni_shuffle.hpp:102` 以 "unsupported format tag" 拒绝并落到 reference。相对地,`0x4x1` 的 `abc/ncw` 因 `W=1` 可与 `nwc` 形成 stride 等价而命中 JIT;这不能解释为 RV64 JIT 普遍支持 plain `ncw`,也不是 4D `nchw/nhwc` 测试。
- 探针修订记录:初版 "object is not initialized" 系探针自身 bug(`static_cast<primitive_desc&&>` 移走 PD 句柄 + 无条件构造 backward PD);已修正(fwd/bwd 互斥分支)并全部重跑。C 探针使用 `dnnl_primitive_desc_query(pd, dnnl_query_impl_info_str, ...)`,公共头文件可用,可复现。

## 探针与证据修订记录(回应两轮复审)

第一轮:prelu 探针权重 rank 修复 + 1D per_oc 去重 + memcpy 位读取;reduction 探针 f16 oracle 先量化再求和、精确比较;shuffle 探针互斥分支、去 signal handler、C 探针 query API;新增 vta/divzero 探针。

第二轮(本次):reduction 数量统一为 66/66(64 矩阵+2 控制);prelu 结论限定为"本次测试矩阵中的 16 个组合"、oracle 标注为共同 reference 源码推导;RV64-003 补 Zvfbfwma 运行时指令探测并将结论收紧为"本次精简构建和环境未提供目标路径";shuffle 补全 release benchdnn/dtype/tag/0x4x64 日志;补 release/debug 库 `execute()` 反汇编;SHA 清单拆分为本地可校验 `SHA256SUMS` 与 `REMOTE-ARTIFACT-SHA256.txt`;build-config 修正 `-ONEDNN_BUILD_GRAPH` 笔误为 `-DONEDNN_BUILD_GRAPH`;`build_probes.sh` 更新为全量探针构建脚本;finding 文档 HEAD 字段更新。

## 环境与构建事实

- Release benchdnn 构建:371 个 ninja 步骤,8 核约 42 分钟(ccache 冷缓存);Debug 约 25 分钟(ccache 热缓存)。
- 板上 native 工具链:gcc 13.2(riscv64)、cmake 3.28.3、ninja 1.11.1;`_Float16` 可用。
- 本仓库 HEAD 与基线 `8f49eae32` 之间无产品源码/测试/构建文件差异(仅审计文档)。
