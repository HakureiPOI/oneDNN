# RV64-002: Reduction reads tail-agnostic accumulator lanes

- 状态：静态确认
- 严重性：high（静默错误结果；所有 RV64 reduction algorithms can hit it at a VLEN-dependent tail）
- 审计基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 当前文档 HEAD：`529c7247f524902377455c62ab283b44918e285c`
- 环境：仅静态审计；x86_64 WSL2；未构建或运行 RV64/QEMU/benchdnn/ctest/sanitizer。
- primitive / implementation：Reduction forward / `jit_uni_reduction_t` and `jit_uni_reduction_kernel_t`
- 涉及文件和符号：
  - `src/cpu/cpu_reduction_list.cpp:38-44`；
  - `src/cpu/rv64/jit_uni_reduction.hpp:41-111`；
  - `src/cpu/rv64/jit_uni_reduction.cpp:26-54`；
  - `src/cpu/rv64/jit_uni_reduction_kernel.cpp:141-215,217-239`。
- 来源：方法 A（RVV tail policy 与 accumulator 数据流的严格差分）+ 方法 B（#5594 宽度审计和 #5361 reduction 新内核的时间/结构邻域）。

## 摘要

The reduction JIT uses `VTA::ta` while updating a vector accumulator for every chunk, then unconditionally changes `vl` to VLMAX and horizontally reduces the entire accumulator register group. For a reduction length of `VLMAX + r` (`0 < r < VLMAX`), the final update runs with `vl=r`; RVV allows tail elements of the destination either to retain their previous values or to be overwritten with all 1s, independently across affected elements. The subsequent `vfred*` runs with `vl=VLMAX` and reads those lanes as if they were guaranteed to retain valid accumulated values. The result can therefore be wrong for sum, mean, max, or min.

This is independent of the unresolved NaN contract: finite inputs are sufficient, and the defect is caused by a tail-lifetime invariant violation.

## Reachability

1. `src/cpu/cpu_reduction_list.cpp:38-44` places `CPU_INSTANCE_RV64(jit_uni_reduction_t)` before `ref_reduction_t`.
2. `src/cpu/rv64/jit_uni_reduction.hpp:45-111` accepts V-capable RV64 CPUs, nonzero f32/f16 reduction descriptors, algorithms `reduction_sum`, `reduction_mean`, `reduction_max`, and `reduction_min`, and canonical dense tags with a nonempty contiguous suffix reduction.
3. `jit_uni_reduction.cpp:26-31` creates the JIT kernel and checks its creation status; `:33-52` invokes it for each output element.
4. `jit_uni_reduction_kernel.cpp:195-215` emits the chunk loop; `:217-239` emits the horizontal reduction.

No invalid descriptor, undefined user buffer, unsupported attribute, or fallback assumption is needed. A legal one-output reduction whose reduced suffix length is just above the hardware VLMAX reaches the kernel.

## Trigger condition

For f32, the accumulator is configured as e32,m8 (`:164-165`, `:200`), so `VLMAX = LMUL * VLEN / SEW`. For VLEN=128, `VLMAX=32`; `reduce_size=33` is a minimal trigger. For f16 max/min, the accumulator is e16,m8 (`:166-167`, `:208`), so VLEN=128 gives `VLMAX=64`; `reduce_size=65` triggers. For f16 sum/mean, the load/update configuration is e16,m4 and the widening destination is e32,m8, giving the same active-lane count as the f32 accumulator; `reduce_size=33` triggers at VLEN=128.

Generally use `reduce_size = VLMAX + 1`, with VLEN=128/256 to demonstrate the dependency. For sum/mean, finite all-ones input can expose an overwritten all-ones bit pattern as qNaN. For max/min, use finite nonuniform input and place the unique extremum in a lane that belongs to the first full chunk but is outside the final short `vl`; if that lane is overwritten, minimumNumber/maximumNumber reduction ignores the qNaN and loses the legitimate extremum. No NaN input is required.

## Broken invariant

Only lanes containing an accumulated input value may be consumed by the final horizontal reduction. A tail lane made agnostic by an earlier `vl=r` operation must never be read later as part of the reduction domain.

## Root cause and pseudo-execution

`emit_loop()` emits the following structure:

```text
initialize v_acc for VLMAX lanes
while (n != 0):
    vl = vsetvli(n, e32/m8 or e16/m4/e16/m8, ta, ma)
    n -= vl
    load v_data[0:vl]
    v_acc[0:vl] = op(v_acc[0:vl], v_data[0:vl])
    // v_acc[vl:VLMAX] may retain its old value or be overwritten with all 1s
vsetvli(x0, x0, accumulator type, m8, ta, ma)  // vl = VLMAX
result = vfred*(v_acc[0:VLMAX], seed)
```

When the last iteration is short, software cannot rely on `v_acc[r:VLMAX]` retaining its earlier valid accumulator values. `emit_horizontal_reduce()` nevertheless passes the whole `v_acc` group to `vfredmax_vs`, `vfredmin_vs`, `vfredosum_vs`, or `vfredusum_vs` with VLMAX active lanes.

## Method A evidence

- **RVV policy oracle**: `VTA::ta` means inactive tail elements may retain the old destination value or be overwritten with all 1s; software cannot rely on preservation. This is the exact policy selected at `jit_uni_reduction_kernel.cpp:200,206-208`.
- **Data-flow oracle**: `emit_horizontal_reduce()` resets `vl` to VLMAX at `:222` or `:232` and reduces `v_acc` without a valid-lane count or tail mask at `:224-236`.
- **Mature/common comparison**: scalar/reference reductions iterate exactly `src_dims` elements (`src/cpu/ref_reduction.cpp:34-60`); they do not include padding or an uninitialized vector tail. x64 reduction kernels carry explicit tail handling instead of reading inactive lanes as data. The difference is semantic, not a tile/performance choice.
- **No legal architecture explanation**: dynamic VL and tail-agnostic policy are valid RVV implementation choices only when inactive lanes are not subsequently observed. The final full-width reduction observes them, violating the policy's software precondition.

## Method B evidence and affected history

- The kernel was introduced by `a95f0060c` (`cpu: rv64: add f32 and f16 rvv reduction kernel (#5361)`). The current baseline still contains the original `VTA::ta` update plus full-width reduction pattern.
- The required #5594 history line establishes that RV64 loop and shape arithmetic must preserve `dim_t`/runtime bounds. This finding is a separate tail-domain violation, but the same `reduce_size` runtime dimension is the trigger axis; the current code does not round or mask it before the final reduction.
- Structural neighborhood search finds the same dynamic-VL pattern in other RV64 kernels, but they store only active lanes or use a matching valid-lane count; no other current reduction guard makes the inactive accumulator lanes valid.
- The unresolved #5370 reduction NaN candidate is not needed here and is intentionally not merged: this finding is reproducible with ordinary finite values and does not depend on NaN semantics.

## Impact surface

- Algorithms: f32 sum/mean/max/min; f16 sum/mean/max/min where the RV64 PD accepts the pair.
- Dtypes: f32 at VLEN-dependent lengths; f16 at both widening sum/mean and native f16 max/min paths. The exact first failing length scales with VLEN.
- Threads: each independent output reduction can fail; threading does not repair the invalid tail. Multiple output elements make the issue wider, but one output is sufficient.
- Layout: all layouts accepted by this PD (`x`, `nc`, `ncw`, `nchw`, `ncdhw`) use the same contiguous suffix kernel.
- The error is silent wrong output, not an expected cross-architecture rounding difference. It can affect any VLEN because the trigger is defined relative to that VLEN.

## Minimal future dynamic validation (not executed)

First confirm implementation with `ONEDNN_VERBOSE=all`, then use `--mode=C --fast-ref=false -v6 --impl=<verified jit:uni name>` in a RISC-V build. At VLEN=128 test:

```text
reduction_max: src={1,1,1,33}, dst={1,1,1,1}, f32 -> f32
reduction_min: same shape
reduction_sum/mean: same shape
reduction_max/min: f16 src/dst={1,1,1,65}
reduction_sum/mean: f16 src={1,1,1,33}, dst={1,1,1,1}, f32 and f16 outputs
```

Use finite nonuniform values and a second set of all ones; repeat at VLEN=256 with `VLMAX+1` lengths, threads 1 and max. The expected result is the scalar/reference reduction over exactly `reduce_size` elements. The test must prove the verbose implementation is RV64 JIT, not reference.

## Expected and statically derived actual behavior

- Expected: reduction over every source element exactly once.
- Static actual behavior: after a short final chunk, the horizontal reduction includes `v_acc` lanes outside the final `vl`; those lanes may retain earlier valid accumulators or be replaced with all-ones bit patterns. For sum/mean, an overwritten floating-point lane becomes qNaN and contaminates the result. For max/min, minimumNumber/maximumNumber ignores that qNaN, so a legitimate earlier contribution—and possibly the unique extremum—can be lost. The result is therefore not guaranteed to equal the expected reduction.
- No runtime output is claimed in this static-only audit.

## False-positive and alternative explanations excluded

- Not a text-only x64/RV64 difference: the issue follows from the explicit RVV `ta` policy and a later full-width read.
- Not floating-point accumulation order: the bug is loss of accumulator state caused by relying on tail preservation that `VTA::ta` does not guarantee.
- Not padding: the PD reduces logical contiguous dimensions and the kernel is called with `reduce_size`, not padded storage width.
- Not an unsupported configuration: the triggering shapes satisfy the RV64 PD's accepted tags, dtype, algorithm, and nonzero-dimension checks.
- Not corrected by the #5594 `dim_t` changes: those changes widen host counters but do not preserve the final vector's valid-lane count.
- Not a NaN-only claim: finite input is enough.

## Existing static tests and why they miss it

`tests/gtests/test_reduction.cpp` contains ordinary small fixed cases; `tests/benchdnn/reduction` covers algorithms and f16 rounding but does not enumerate VLEN-relative `VLMAX+1` lengths. Current RISC-V CI uses QEMU VLEN=128/256 for selected tests but has no static guarantee that the reduction implementation is targeted, and special reduction tail lengths are not shown in the skip/workflow sources. The static audit did not execute any test.

## Repair direction (no source change in this audit)

Preserve every accumulator lane that already contains a contribution. One valid design is to initialize the complete VLMAX accumulator to the identity, use tail-undisturbed updates (`VTA::tu`) for every chunk, and keep the final horizontal reduction at VLMAX; lanes beyond a short first/only chunk then remain at the identity, while lanes from earlier full chunks survive a short final update. Another valid design is to reduce each chunk immediately into a scalar or separately tracked valid accumulator. Do **not** reduce only with the final short `vl`: for `VLMAX+r`, lanes `r..VLMAX-1` still contain legitimate contributions from the first chunk. Any fix must cover f32, f16 native max/min, f16 widening sum/mean, all VLENs, and must not observe agnostic/masked-off state.

## Unresolved questions

- Dynamic execution is intentionally absent; the target-dependent choice between retaining a tail element and overwriting it with all 1s is not claimed.
- A separate reduction max/min NaN semantic candidate remains open until the public reduction NaN contract is established; it is not required for this finding.
