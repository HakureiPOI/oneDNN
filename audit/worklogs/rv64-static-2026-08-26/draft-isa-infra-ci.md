# RV64 ISA/JIT/共享资源/CI 静态审计记录

- 产品基线：`8f49eae32bdec3674a9a98ea1524a85cd1f302db`
- 文档 HEAD：`529c7247f524902377455c62ab283b44918e285c`
- 模式：只读静态审计；未构建、未运行、未修改产品源码/测试。

## ISA 探测与构建

- `CMakeLists.txt:71-74` 将 `riscv64` 识别为 `DNNL_TARGET_ARCH=RV64`；`src/CMakeLists.txt:41-43` 加入 `xbyak_riscv`；`src/cpu/CMakeLists.txt:33-35,166-168` 纳入公共 JIT utils 与 RV64 object；`src/cpu/rv64/CMakeLists.txt:19-30` 用 glob 递归加入 JIT 源文件。
- `cmake/platform.cmake:122-137` 默认 `RV64_MARCH_FLAG=-march=rv64gc`，注释明确向量代码由 Xbyak_riscv JIT 在运行时发射；`:315-316,426-427` 将 baseline flag 应用到编译。用户显式 `DNNL_ARCH_OPT_FLAGS` 仍可 override，属于明确契约。
- 历史 #3486 的 compile-time try-compile flags 问题已由 `d41e7b973` 后移除；历史 #4638 的全局 RVV intrinsic/SIGILL 路径已改为 baseline + JIT。当前静态结论是旧模式不再存在，不把用户主动 `-march=rv64gcv` override 判为缺陷。
- `cpu_isa_traits.hpp:51-63` 定义 V/Zvfh/Zvfbfwma mask；`:67-101` 的 C++ thread-safe singleton 查询 Xbyak CPU 的 V/VLEN/Zvfh，并调用 BF16 probe；`:104-115` `mayiuse()` 显式按 ISA gate；`platform.cpp:128-180` 用相同能力决定 bf16/f16 支持。
- `third_party/xbyak_riscv/xbyak_riscv_util.hpp:222-228` 在具有 V 时生成 CSR vlenb reader；`:243-252` 暴露能力。VLEN 只映射到 `get_vlen_implementation_id` 的实现 ID（`cpu_isa_traits.hpp:125-135`），多数 JIT 使用动态 VL，不固定 VLEN。
- BF16 probe (`cpu_isa_traits.cpp:31-82`) 暂存 SIGILL disposition，执行 raw `vsetivli` + `vfwmaccbf16.vf`，失败跳回并恢复 handler。静态候选：全局 `sigaction(SIGILL)`、全局 `sigjmp_buf`、无 mutex；若另一个线程在窗口内收到同步 SIGILL，handler 可能对另一线程的 jump buffer `siglongjmp`，形成未定义行为/进程崩溃；也会临时覆盖进程原有 SIGILL handler。没有动态证据，列 C-ISA-1 候选，不升级静态确认。raw probe 注释称 `vsetivli ... uimm=4`，但 `0xcc807057` 的 uimm 字段为 0（正确 uimm=4 的编码应包含相应 bit）；由于目标 BF16 指令在无扩展时仍须解码为非法、VLMAX=0 不改变扩展 trap 判定，该编码差异暂列观察项而非 finding。

## JIT 基座、错误传播和资源

- `rv64/jit_generator.hpp:64-75` 封装 CodeGenerator，默认 max CPU ISA 为 `get_max_cpu_isa()`；`:91-107` 捕获 `generate` 异常，调用 `ready(PROTECT_RWE)`，检查 code pointer 并注册 JIT code；失败返回 `runtime_error`。
- `is_valid_isa` (`:111-115`) 同时检查 kernel limit 和 `mayiuse`，但当前许多派生类依赖 PD 在创建前 gate，不是统一运行时调用点。
- 已核对 `create_kernel()` 调用图：reduction (`jit_uni_reduction.cpp:29`)、shuffle (`shuffle/jit_uni_shuffle.cpp:167-170`)、pooling/eltwise/reorder、BRGEMM wrapper 均通过 `CHECK` 或直接返回 status；binary 也逐个检查多个 kernel。
- 候选 C-JIT-1：softmax kernel 构造函数（`jit_rvv_softmax_kernel.cpp:84-87,138-141,144-147,194-197,425-428,564-567`）直接丢弃 `create_kernel()` 返回值；softmax primitive 初始化只检查分配，未检查构造出的 `jit_ker_`，若合法 codegen/ready 失败，execute 会走 null function pointer。对应 resampling `jit_uni_resampling_kernel.cpp:34-42` 与 `jit_uni_resampling.cpp` 的构造/分配路径也丢弃 status。当前无法从静态输入严格构造 codegen failure，保留候选，未来应注入受控 failure 并确认 primitive creation 返回错误。
- GEMM f32 kernel table (`gemm/jit_rvv_gemm_kernel.cpp:352-390`) 使用 `std::once_flag` 初始化 4 个 transpose 组合、每组合 n_cols 1..6 的 no-bias/bias kernels；调用表只使用已填充的 n_cols。构造函数丢弃 status，但初始化通常发生在 first use，属于与 C-JIT-1 相同的注入失败候选，不单独重复计数。
- Scratchpad：softmax per-thread reduction/interim booking 与 execute key/offset 已闭环（见 softmax 草稿）；reorder `jit_uni_reorder.cpp:200-204,632-638` 的 scale scratchpad 使用 `dim_t` loop；#5839 的 heap 临时区已改为 worker slice。未发现严格可证的容量/线程越界。
- 资源/缓存：RV64 JIT kernels 多数在 primitive 或 static table 生命周期内保持 code pointer；无统一可观察 mutable per-execute state。GEMM table 用 `once_flag`，其表指针在初始化后只读。

## Injectors/RVV state

- `rv64/injectors/jit_uni_binary_injector.*`、`jit_uni_eltwise_injector.*`、`jit_uni_postops_injector.*` 的 post-op capability gate 与 kernel consumer 已静态配对；#5174 alpha 和 #5370 compare+merge/NaN 修复扩散到主要 binary/eltwise/pooling/conv consumers。
- `cpu_isa_traits.hpp:28-42` 强制 `XBYAK_RISCV_V=1`（如未由 build 定义）并关闭 Xbyak 旧版 `vsetvli` 默认参数；调用点多数显式传 LMUL/VTA/VMA。动态 VLEN/tail 仍须现场验证，但单纯 `ta/ma` 不是错误，前提是后续不读 inactive lanes；RV64-002 是该不变量在 reduction 中被违反的独立 finding。
- `third_party/xbyak_riscv/xbyak_riscv_v.hpp:740-760` 编码 vsetivli/vsetvli；BF16 converters/macc emitter 与 PD Zvfbfwma gate 已配对。Xbyak 是 vendored emitter 边界，未把 emitter 单独差异当 oneDNN finding。

## CI/weekly/skips

- `.github/workflows/ci-riscv.yml:67-68` 只有 OMP RelWithAssert SMOKE build；`:137-138` QEMU test matrix VLEN 128/256；`:157-182` setup QEMU、下载 artifact、调用 `automation/riscv/test.sh`。
- `.github/workflows/weekly-riscv.yml:41-42` CI build；`:109-118` 十个 VLEN=128 分片；`:136-161` QEMU test。当前 workflow 未覆盖 VLEN 512/1024、无 V、V-only、缺 Zvfh 或缺 Zvfbfwma、真实硬件。
- `automation/riscv/common.sh:33-38` 使用交叉 GCC 和 `riscv64.cmake`；toolchain `cmake/toolchains/riscv64.cmake:20-30` 固定 `riscv64-linux-gnu-gcc-14/g++-14` 与 sysroot；当前主机没有这些工具。
- `automation/riscv/test.sh:353-371` 使用 `QEMU_LD_PREFIX`，SMOKE 直接执行 ctest 排除表达式，CI 按分片/平衡策略执行；跳过不等于证明正确。
- `skipped-tests.sh:27-56` 固定跳过 matmul COO/CSR、sum、graph SDPA；SMOKE 另跳过 convolution fwd/bwd/eltwise、pooling fwd/bwd、GEMM、RNN 和耗时 graph；CI 另跳过 matmul/IP/graph benchdnn。这里形成历史 #4637/#5162 等边界的覆盖缺口。
- CI 没有静态证据覆盖 NaN/INF/±0、VLMAX+tail、超 `INT_MAX`、缺扩展组合、不同真实 VLEN、并发 SIGILL probe、JIT failure injection。所有动态结论均未执行。

## 处置

- 已排除：历史 compile-time ISA bug (#3486/#4638) 的旧代码、正常 fallback、显式用户 arch override、不同 tile/VLEN 写法、JIT table 的只读并发初始化。
- 候选：C-ISA-1（全局 SIGILL probe handler/jmp buffer）、C-JIT-1（softmax/resampling/部分 GEMM 构造丢弃 create status）。这些需要动态注入/真实硬件或 sanitizer，未升级正式 finding。
- finding：静态确认 RV64-002 reduction tail（`VTA::ta` 后用 VLMAX 横向读）在独立 finding 中处理；静态高置信 RV64-001 PReLU 特殊值差异在另一 finding 中处理。
