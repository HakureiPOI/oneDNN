# RV64-004: Shuffle divides by zero for a legal zero-batch descriptor

- 状态：静态确认
- 严重性：high（合法 API descriptor 在 primitive execute 前触发断言/除零，造成 availability failure）
- 审计基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 当前文档 HEAD：`529c7247f524902377455c62ab283b44918e285c`
- 环境：仅静态审计；x86_64 WSL2；未构建或运行 RV64/QEMU/benchdnn/ctest。
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

## 最小未来动态验证（本阶段未执行）

In an RV64 build, create a zero-batch shuffle descriptor with valid `axis=1`, `group_size`, equal src/dst layouts, and default attributes. Use `ONEDNN_VERBOSE=all` to confirm the selected implementation; then execute with `--mode=C --fast-ref=false -v6 --impl=<verified jit:rvv name>` or a focused API harness. Test debug and release/RelWithAssert builds separately. Expected behavior is a successful zero-work execution that does not access source or destination buffers, matching the public zero-volume convention and the reference path's natural empty iteration.

## 预期与静态实际结果

- Expected: the accepted zero-volume descriptor executes successfully as zero work without touching source/destination buffers or evaluating partition arithmetic that requires a positive task count.
- Static actual: RV64 PD can accept the descriptor; `tasks=0`; `div_up(nthr, 0)` is called. Debug asserts at `utils.hpp:367`; release has division-by-zero undefined behavior.
- No runtime crash is claimed because this stage did not execute code.

## 反证和误报排除

- Zero dimensions are not an invalid negative-dimension descriptor; the common memory descriptor check explicitly allows zero.
- This is not an invalid user buffer or an execute call with missing arguments; the failure occurs during valid task setup.
- This is not a performance-only zero-work path; the divisor precondition is violated and can abort before returning status.
- The finding does not assume a particular x64 implementation is correct; the public descriptor acceptance and local `div_up` contract are sufficient.
- A global framework zero-dimension short-circuit would exclude the finding, but static inspection of `primitive_execute` (`src/common/primitive_iface.cpp:116-201`) shows it enqueues the primitive without a generic zero-work return. That guard is absent from the current path.

## 现有测试为何未捕获

`tests/gtests/test_shuffle.cpp` covers positive dimensions and layout/group cases but does not provide a zero-batch execute case. RISC-V CI uses QEMU VLEN 128/256 and does not add zero-dimension shuffle coverage. Existing tests cannot be treated as proof because the target RV64 implementation was not dynamically confirmed in this audit.

## 修复方向（不在审计阶段直接改代码）

Add an explicit zero-work guard in the shuffle PD/execute contract. Preferred behavior is to return success before creating/partitioning the kernel when `has_zero_dim_memory()` is true, or to reject the RV64 optimized PD with `unimplemented` so a zero-work-safe implementation can handle it. If execution remains responsible, check `tasks == 0` before `div_up` and return success without touching input/output buffers. Add forward/backward zero-batch regression coverage.

## 尚未解决的问题

- No debug assertion or release division-by-zero was executed in this static-only audit; future execution is regression validation, not a prerequisite for the static reachability conclusion.
