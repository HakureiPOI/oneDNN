# RV64-004: Shuffle divides by zero for a legal zero-batch descriptor

- 状态：静态确认 + 动态确认（2026-08-27：Debug 构建断言 abort 复现；Release 该特定二进制未观察到可见故障）
- 严重性：high（合法 API descriptor 在 primitive execute 前触发断言/除零，造成 availability failure）
- 审计基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 静态审计文档 HEAD：`529c7247f524902377455c62ab283b44918e285c`
- 动态验证文档基线 HEAD：`dc863e4afba22fba060d7059683a67a9b1bc8e6c`（静态审计文档提交；动态验证结果作为其增量修订）
- 环境：静态审计于 x86_64 WSL2；动态验证于 2026-08-27 在 Spacemit K1 完成。
- primitive / implementation：Shuffle forward/backward / `jit_uni_shuffle_t`
- 涉及文件和符号：
  - `src/common/memory_desc.cpp:48-63`；
  - `src/common/shuffle.cpp:41-83`；
  - `src/cpu/cpu_shuffle_list.cpp:42-52`；
  - `src/cpu/rv64/shuffle/jit_uni_shuffle.hpp:57-123`；
  - `src/cpu/rv64/shuffle/jit_uni_shuffle.cpp:174-214`；
  - `src/common/utils.hpp:362-371`。
- 来源：方法 A（API descriptor acceptance -> RV64 PD -> execute arithmetic）+ 方法 B（#3457 zero/empty boundary neighborhood and #5594 dimension-width neighborhood）。

## 摘要

The public shuffle descriptor validation permits a zero dimension: `memory_desc_sanity_check()` rejects negative dimensions but not zero, and `shuffle_desc_init()` only requires `group_size > 0 && group_size <= dims[axis]`; it does not require batch `dims[0] > 0`. oneDNN's public memory documentation explicitly supports zero-volume memory and states that its buffers are not accessed. A valid descriptor with `MB=0`, `C>0`, and positive spatial dimensions can therefore reach the RV64 shuffle PD. The PD has no zero-dimension rejection. In `execute()`, `tasks = MB * nb_c` becomes zero, then `div_up((dim_t)nthr, tasks)` is evaluated with divisor zero before `parallel_nd` can observe that there are no tasks. `div_up` asserts `b > 0`; in release builds the division is undefined and can trap. This is a deterministic API/availability violation on a legal zero-batch descriptor.

## 可达路径

1. Public memory descriptor construction accepts zero dimensions because `src/common/memory_desc.cpp:48-63` checks only `dims[d] < 0`; zero leaves the product valid.
2. `src/common/shuffle.cpp:41-83` validates axis, group size, format kinds and equal src/dst dimensions. For axis 1, choose `C>0` and a valid group; `MB=0` is not rejected.
3. `src/cpu/cpu_shuffle_list.cpp:42-52` places `CPU_INSTANCE_RV64(jit_uni_shuffle_t)` before `ref_shuffle_t`.
4. `src/cpu/rv64/shuffle/jit_uni_shuffle.hpp:57-123` checks V, dtype, axis, format and offset range, but has no `has_zero_dim_memory()` gate. With `MB=0`, `C>0`, and positive spatial dimensions, `conf_.mb=0`, `conf_.nb_blk>0`, `conf_.sp>0`, and PD init can return success.
5. `src/cpu/rv64/shuffle/jit_uni_shuffle.cpp:174-214` computes `tasks = MB * nb_c` at `:191`, then evaluates `div_up((dim_t)nthr, tasks)` at `:194` when `tasks < nthr`.
6. `src/common/utils.hpp:362-371` requires `b > 0`; debug builds assert, release builds evaluate `(a - 1) / b` with `b=0`.

## 触发条件

A shuffle descriptor with:

```text
src/dst dims = {0, C, D, H, W}   // or the corresponding 2D/3D rank
C > 0, group_size > 0 and C % group_size == 0
D*H*W > 0
axis = 1
src and dst equal, supported dtype/layout, default attributes
```

A simple concrete family is `{MB=0, C=4, W=1}`, `axis=1`, `group_size=2`, plain `ncw`, f32. The same arithmetic applies to forward and backward because both use the same `execute()` task decomposition.

## 被破坏的不变量

Every divisor passed to `div_up` must be strictly positive. A primitive that accepts a zero-work descriptor must either return success without entering a kernel or explicitly return `unimplemented`; it must not derive a thread partition by dividing by the zero number of tasks.

## 根因

The RV64 shuffle execute path assumes `MB * nb_c > 0` when balancing spatial work:

```text
tasks = MB * nb_c;
sp_split_size = tasks >= nthr ? sp : max(1, div_up(sp, div_up(nthr, tasks)));
```

The public and RV64 PD layers do not establish that precondition. The outer `parallel_nd(MB, nb_c, nb_sp, ...)` would naturally represent no work for `MB=0`, but the zero-task partition calculation occurs first and fails before that harmless no-op can happen.

## 方法 A 证据

- **API oracle**: public memory descriptor validation allows zero dims; shuffle descriptor validation does not impose a positive batch dimension. The public zero-volume convention documents supported zero-volume memory and no buffer access: <https://uxlfoundation.github.io/oneDNN/group_dnnl_api_cpp_memory.html>.
- **Control/data-flow oracle**: the RV64 implementation is registered before reference, accepts the descriptor, and divides by `tasks=0` before any no-op loop.
- **Common helper oracle**: `utils::div_up` explicitly asserts a positive divisor, proving the call violates its helper precondition rather than merely producing an unusual partition.
- **Architecture comparison**: x64/reference implementations may have their own zero-work behavior, but the finding does not rely on x64 being ground truth; it follows from public descriptor acceptance and the RV64 helper contract.

## 方法 B 证据与历史关联

- The shuffle JIT was introduced by `02abc0f49` (#5850) after the earlier #3457 family established that zero/empty windows must be handled before arithmetic and memory access. This is a useful boundary-neighborhood heuristic, not the same historical root cause; the public zero-volume contract and current control flow provide the confirmation.
- The five-neighborhood search found no guard in the current shuffle PD/execute path that establishes positive `MB` or short-circuits zero work. This is a new boundary form, not a duplicate of pooling's empty spatial window.
- #5594's dimension-width history is relevant because the task product is `dim_t`, but widening the type does not make a zero divisor safe; the current defect is a zero-work precondition omission.

## 影响扩散面

- Forward and backward RV64 shuffle.
- Supported f32/s32/f16/bf16 layouts that can describe a zero batch and positive C/spatial dimensions.
- The failure occurs before any kernel call, so it is independent of VLEN, vector tail values, input contents, or thread count (except the exact assertion/release symptom).
- Reference fallback is not reached once the RV64 PD returns success.

## 动态验证结果（2026-08-27，Spacemit K1 / X60，VLEN=256）

状态：**Debug 构建动态确认**（assert abort）；**Release 该特定二进制未观察到可见故障**（源代码仍含 C++ 除零 UB）。

- PD 确认接受 zero-batch descriptor（`MB=0,C=4,W=1,axis=1,group=2`，fwd/bwd 均 `impl: jit:rvv`）。
- **Debug：assert abort 全量复现**——C++ 探针 fwd/bwd × OMP 线程 1/4/8（6 组）+ C API 探针（1 组）= 7/7 在 `utils.hpp:367` 触发 `assert(b > 0)`（SIGABRT，exit=134）；benchdnn `--mode=C --shuffle 0x4x1` 同样 abort。Debug 库反汇编（`audit/worklogs/rv64-static-2026-08-26/dynval/evidence/disasm/shuffle-execute-debug.asm`）显示 `execute()` 三次调用未内联的 `utils::div_up`（断言位于该函数内）。
- **Release：该特定二进制未观察到可见故障**——C++ 探针 6/6 exit=0（zero-work 干净完成）；benchdnn f32/f16/s32 × fwd/bwd 共 6 组全部 PASSED，3D `--tag=ncw/nwc` 亦 PASSED（`audit/worklogs/rv64-static-2026-08-26/dynval/evidence/logs/shuffle-rel.log`、`shuffle-rel-extra.log`）。
- Release 机制证据链：`divzero_probe.c` 实测 RISC-V `div` 指令除零不 trap、返回 -1；实际库反汇编（`audit/worklogs/rv64-static-2026-08-26/dynval/evidence/disasm/shuffle-execute-release.asm`）确认 release `execute()` 内联了同一 `div` 结构（`0x6095f8: div a0,a0,s2` 即内层 `div_up(nthr,tasks)`，零除数路径实际经过）。Release 的实际成功行为与该除零机制一致（div 返回 -1 → `div_up` 得 0 → `max(1,...)` 钳为 1 → `parallel_nd(0,...)` 早退）。**源代码仍为 C++ UB**；"未观察到故障"仅描述该特定二进制（该硬件+GCC 13 组合），不泛化。
- `0x4x64` 是 3D `{N,C,W}` 描述，verbose 显示默认 tag 为 `abc`；当 `W=64` 时该 plain `ncw` 布局不匹配 RV64 PD 支持的 blocked/nspc tag，故在 `jit_uni_shuffle.hpp:102` 被拒绝并落 reference。`0x4x1` 的 `abc/ncw` 因 `W=1` 可与 `nwc` 形成 stride 等价而命中 JIT；这不是 4D `nchw/nhwc` 测试，也不能解释为 RV64 JIT 普遍支持 plain `ncw`。
- 探针修订记录：初版 "object is not initialized" 系探针自身 bug（`static_cast<primitive_desc&&>` 移走 PD 句柄 + 无条件构造 backward PD），已修正并全部重跑；C 探针使用 `dnnl_primitive_desc_query(pd, dnnl_query_impl_info_str, ...)`。
- 原始日志：`audit/worklogs/rv64-static-2026-08-26/dynval/evidence/logs/shuffle-dbg.log`、`shuffle-rel.log`、`shuffle-rel-extra.log`、`benchdnn-dbg-abort.log`、`divzero-probe.log`。

## 复现命令（动态阶段已执行；命令与日志见 evidence/logs/）

In an RV64 build, create a zero-batch shuffle descriptor with valid `axis=1`, `group_size`, equal src/dst layouts, and default attributes. Use `ONEDNN_VERBOSE=all` to confirm the selected implementation; then execute with `--mode=C --fast-ref=false -v6 --impl=<verified jit:rvv name>` or a focused API harness. Test debug and release/RelWithAssert builds separately. Expected behavior is a successful zero-work execution that does not access source or destination buffers, matching the public zero-volume convention and the reference path's natural empty iteration.

## 预期与静态实际结果

- Expected: the accepted zero-volume descriptor executes successfully as zero work without touching source/destination buffers or evaluating partition arithmetic that requires a positive task count.
- Static actual: RV64 PD can accept the descriptor; `tasks=0`; `div_up(nthr, 0)` is called. Debug asserts at `utils.hpp:367`; release has division-by-zero undefined behavior.
- 上述为静态阶段推导；2026-08-27 板上实测：Debug abort（exit 134）、Release 该特定二进制干净完成（exit 0），见"动态验证结果"。

## 反证和误报排除

- Zero dimensions are not an invalid negative-dimension descriptor; the common memory descriptor check explicitly allows zero.
- This is not an invalid user buffer or an execute call with missing arguments; the failure occurs during valid task setup.
- This is not a performance-only zero-work path; the divisor precondition is violated and can abort before returning status.
- The finding does not assume a particular x64 implementation is correct; the public descriptor acceptance and local `div_up` contract are sufficient.
- A global framework zero-dimension short-circuit would exclude the finding, but static inspection of `primitive_execute` (`src/common/primitive_iface.cpp:116-201`) shows it enqueues the primitive without a generic zero-work return. That guard is absent from the current path.

## 现有测试为何未捕获

`tests/gtests/test_shuffle.cpp` covers positive dimensions and layout/group cases but does not provide a zero-batch execute case. RISC-V CI uses QEMU VLEN 128/256 and does not add zero-dimension shuffle coverage. The dedicated 2026-08-27 probes dynamically confirmed the target RV64 implementation and the Debug abort, but the existing automated test matrix still lacks this regression case.

## 修复方向（不在审计阶段直接改代码）

Add an explicit zero-work guard in the shuffle PD/execute contract. Preferred behavior is to return success before creating/partitioning the kernel when `has_zero_dim_memory()` is true, or to reject the RV64 optimized PD with `unimplemented` so a zero-work-safe implementation can handle it. If execution remains responsible, check `tasks == 0` before `div_up` and return success without touching input/output buffers. Add forward/backward zero-batch regression coverage.

## 尚未解决的问题

- The current Release binary completed zero work without a visible failure, but that observation does not make the source-level C++ division by zero portable or defined across compilers and targets.
- No automated regression test currently protects the legal zero-batch case; the dedicated probe evidence should be converted into forward/backward coverage for supported dtypes and layouts.
