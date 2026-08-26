# RV64-003: BF16 BRGEMM JIT misaligns the RISC-V stack

- 状态：静态确认（ABI invariant violation; runtime crash impact not dynamically reproduced）
- 严重性：medium（可达 ABI 合规缺陷；当前 leaf kernel 的数值错误或崩溃尚未证明）
- 审计基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 当前文档 HEAD：`529c7247f524902377455c62ab283b44918e285c`
- 环境：仅静态审计；x86_64 WSL2；未构建或运行 RV64/QEMU/benchdnn/ctest。
- primitive / implementation：BF16 BRGEMM JIT kernel used by RV64 MatMul, inner product, and convolution.
- 涉及文件和符号：
  - `src/cpu/rv64/brgemm/jit_brgemm_kernel.cpp:821-883,1158-1169`，`jit_brgemm_bf16_kernel_t::generate()`；
  - `src/cpu/rv64/brgemm/brgemm.cpp:99-123`，dtype kernel selection and status propagation；
  - `src/cpu/rv64/rvv_brgemm_matmul.cpp:179-251` and corresponding BF16 inner-product/convolution PD gates；
  - comparison paths in the same file: f32 `:99-104,391-397`, f16 `:493-499,771-777`, s8 `:1273-1277`.
- 来源：方法 A（RV64 ABI contract and generated prologue）+ 方法 B（BF16 JIT expansion/time neighborhood and shared BRGEMM consumers）。

## 摘要

The BF16 BRGEMM JIT saves six callee-saved GPRs (`s0` through `s5`) after `addi(sp, sp, -56)`, and restores with `+56`. On RV64 LP64, the stack pointer must be 16-byte aligned at procedure entry and remain aligned throughout a procedure. If the caller enters with `sp % 16 == 0`, the generated prologue leaves `sp % 16 == 8`. The neighboring f32 and f16 kernels reserve 48 bytes and the s8 kernel 32 bytes, both preserving 16-byte alignment. This is an actual ABI invariant violation in the BF16 implementation, not a tile or VLEN difference.

The generated body is currently a leaf and makes no normal C++ call. Its emitted stack accesses are 8-byte loads/stores at 8-byte-aligned offsets, so this static finding does not prove a current numerical error, invalid memory access, or crash. It does establish a reachable psABI conformance violation; a future emitted call or an operation that explicitly requires 16-byte stack alignment would make the violation directly observable.

## 可达路径

1. RV64 convolution/inner-product/MatMul lists register BF16-capable BRGEMM implementations. Their PDs require `mayiuse(zvfbfwma)` and compatible BF16 descriptors; the exact MatMul gate is visible in `rvv_brgemm_matmul.cpp:179-251`, with analogous gates in `rvv_brgemm_inner_product.cpp` and `rvv_brgemm_conv.cpp`.
2. The shared `brgemm_kernel_create()` selects `brgemm_kernel_bf16_t` whenever `brg.dt_a == data_type::bf16` (`brgemm.cpp:104-111`), calls `create_kernel()` and returns the generated kernel when successful (`:117-123`).
3. The kernel's function pointer is invoked through `brgemm_kernel_execute()` by the MatMul/inner-product/convolution consumers.
4. `jit_brgemm_bf16_kernel_t::generate()` emits the prologue at `jit_brgemm_kernel.cpp:876-882` and the epilogue at `:1163-1169`.

The path is therefore reachable for a legal BF16 BRGEMM problem on a V+Zvfbfwma CPU; it does not depend on unsupported attributes, invalid memory descriptors, or fallback failure.

## 触发条件

- RV64 LP64 ABI caller enters the BF16 BRGEMM function with the required 16-byte aligned stack;
- BF16 BRGEMM PD passes the Zvfbfwma gate and creates `brgemm_kernel_bf16_t`;
- kernel executes its generated prologue.

No special dimensions, tail, NaN, or VLEN are required. The 56-byte frame is unconditional in the BF16 `generate()` body.

## 被破坏的不变量

The RISC-V ELF psABI requires `sp` to be aligned to a 128-bit (16-byte) boundary on procedure entry and to remain aligned throughout the procedure. A callee must restore the original stack pointer before returning. The BF16 kernel restores the value but violates the alignment requirement during the entire generated body.

## 根因

`jit_brgemm_bf16_kernel_t::generate()` reserves exactly six 64-bit spill slots:

```text
addi sp, sp, -56
sd s0, 0(sp) ... sd s5, 40(sp)
...
ld s0, 0(sp) ... ld s5, 40(sp)
addi sp, sp, 56
ret
```

Six slots require 48 bytes; the extra 8 bytes makes the frame size non-multiple-of-16. The f32 and f16 generators reserve `-48/+48`; s8 reserves `-32/+32`. The BF16 path is the only sibling with the 56-byte frame and has no compensating alignment adjustment.

## 方法 A 证据

- **ABI oracle**: RISC-V LP64 stack alignment is a public calling-convention requirement, independent of x64 instruction layout.
- **Generated-code data flow**: the exact `-56`/`+56` pair is visible at lines `876` and `1168`; all six saved registers are callee-saved registers `s0-s5`.
- **Sibling oracle**: the same BRGEMM generator uses aligned 48-byte frames for f32/f16 and 32-byte frame for s8, demonstrating that a multiple-of-16 frame is the intended local pattern.
- **Reachability oracle**: BF16 BRGEMM creation is explicitly selected by dtype and gated by runtime Zvfbfwma; the problematic generator is not dead code.

## 方法 B 证据与影响扩散

- The BF16 kernel was added in the 2026 BF16 BRGEMM expansion (`3bac96b8b` and subsequent #5403 lineage). The sibling frame code was copied/extended for BF16 but changed the frame size to 56 without preserving the ABI alignment invariant. This time/sibling neighborhood helps locate the regression, but it is not an independent historical bug-fix oracle.
- All shared BRGEMM consumers use the same `brgemm_kernel_bf16_t`: BF16 MatMul, inner product, and convolution. A single generator fix has cross-primitive impact.
- This is independent of #5594 loop-width and #5370 NaN fixes; no input-value or dimension edge is required.

## API/规范依据

- RISC-V ELF psABI, calling convention / stack pointer alignment: <https://riscv-non-isa.github.io/riscv-elf-psabi-doc/>.
- The ABI requires 16-byte alignment for RV64 LP64 procedure stack state; a 56-byte decrement from an aligned entry is 8-byte aligned.

## 最小未来动态验证（本阶段未执行）

Use a RV64 V+Zvfbfwma build and first confirm the exact BRGEMM implementation with `ONEDNN_VERBOSE=all`. Then run a minimal BF16 MatMul/inner-product/convolution case with `--mode=C --fast-ref=false -v6 --impl=<verified brgemm:rvv_zvfbfwma name>`. Inspect the generated prologue with a disassembler or JIT dump. A dedicated validation-only kernel variant may emit a nested ABI-conforming call or explicitly aligned stack operation to make the misalignment observable. Repeat with normal and large K/N, threads 1 and max. The static result does not claim that the current leaf body or ordinary QEMU must fault.

## 预期与实际

- Expected: `sp % 16 == 0` throughout the generated function body, with all callee-saved registers restored.
- Static actual: after the BF16 prologue, `sp % 16 == 8`; it returns to alignment only at the epilogue.
- No dynamic crash/output is claimed in this static-only stage.

## 反证和误报排除

- Not an x64/RV64 textual difference: the RISC-V ABI explicitly defines the invariant.
- Not merely a performance or stack-size choice: 56 is not a legal aligned frame size under the LP64 ABI.
- Not unreachable BF16 code: the shared BRGEMM factory selects it by dtype, and current PDs gate BF16 to the required runtime extension.
- Not fixed by caller alignment: an aligned entry plus a non-multiple-of-16 decrement necessarily produces the misalignment.
- The absence of an immediate fault in a no-call JIT body would not make the generated function ABI-conforming; it only limits the dynamically observable symptom.

## 现有测试为何未捕获

RISC-V CI explicitly enables Zvfbfwma but does not inspect generated stack alignment. Ordinary numerical BRGEMM cases do not perform a current emitted operation known to require 16-byte stack alignment, and passing numerical tests would not prove calling-convention conformance. The static audit did not execute CI or tests.

## 修复方向（不在审计阶段直接改代码）

Reserve a frame size that is a multiple of 16 (for example 64 bytes, or 48 bytes if no additional spill is required), keep all spill offsets within the frame, and restore the exact original stack pointer. Add a generated-code/ABI regression check for every BF16 BRGEMM consumer and compare f32/f16/s8 sibling prologues.

## 尚未解决的问题

- No RV64 disassembly or runtime alignment-checking harness is available in this environment.
- The exact runtime symptom is not known; the confirmed result is the ABI invariant violation, not a demonstrated current availability or numerical failure.
