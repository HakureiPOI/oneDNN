// RV64-004 dynamic validation harness: shuffle zero-batch division by zero
//
// Baseline: 8f49eae32bdec3674a9a98ea1524a85cd1f302db
// Path: cpu/rv64/shuffle/jit_uni_shuffle.cpp execute():
//   tasks = MB * nb_c = 0;
//   sp_split_size = ... div_up((dim_t)nthr, tasks)  // divisor == 0
// utils::div_up asserts b > 0 in debug; release divides by zero (UB).
//
// Legal descriptor: MB=0, C>0, SP>0, axis=1, valid group.
// Public contract: zero-volume memory is supported, buffers are not accessed.
//
// Usage: ./shuffle_zero_batch_probe <fwd|bwd> [threads via OMP_NUM_THREADS]
// Expected conforming behavior: clean success, no buffer access, exit 0.
//
// The parent shell runs this under `timeout` and records the exit status;
// no signal handlers are installed on purpose so a debug-build assert abort
// or a crash is observable as-is.

#include <cstdio>
#include <cstdlib>
#include <string>
#include "dnnl.hpp"

using namespace dnnl;

int main(int argc, char **argv) {
    const bool bwd = (argc > 1 && std::string(argv[1]) == "bwd");
    const char *thr_s = getenv("OMP_NUM_THREADS");
    printf("direction=%s OMP_NUM_THREADS=%s\n", bwd ? "bwd" : "fwd",
            thr_s ? thr_s : "(default)");
    fflush(stdout);

    try {
        engine eng(engine::kind::cpu, 0);
        stream stm(eng);

        // 3D descriptor: MB=0, C=4, W=1; plain blocked layout (tag abc)
        memory::dims dims = {0, 4, 1};
        auto md = memory::desc(dims, memory::data_type::f32,
                memory::format_tag::abc);

        if (bwd) {
            // backward requires a hint forward PD; constructed only for bwd
            auto hint = shuffle_forward::primitive_desc(eng,
                    prop_kind::forward_inference, md, md, 1 /*axis*/,
                    2 /*group*/);
            printf("hint fwd impl: %s\n", hint.impl_info_str());
            auto pd = shuffle_backward::primitive_desc(eng, md, md,
                    1 /*axis*/, 2 /*group*/, hint);
            printf("bwd impl: %s\n", pd.impl_info_str());
            printf("PD accepted zero-batch descriptor\n");
            fflush(stdout);

            auto diff_src = memory(pd.diff_src_desc(), eng);
            auto diff_dst = memory(pd.diff_dst_desc(), eng);
            auto prim = shuffle_backward::primitive(pd);
            printf("step: executing bwd...\n");
            fflush(stdout);
            prim.execute(stm, {{DNNL_ARG_DIFF_SRC, diff_src},
                                    {DNNL_ARG_DIFF_DST, diff_dst}});
            stm.wait();
            printf("step: execute returned cleanly\n");
            return 0;
        }

        auto pd = shuffle_forward::primitive_desc(eng,
                prop_kind::forward_inference, md, md, 1 /*axis*/, 2 /*group*/);
        printf("fwd impl: %s\n", pd.impl_info_str());
        printf("PD accepted zero-batch descriptor\n");
        fflush(stdout);

        // zero-volume buffers are not accessed per the public contract
        auto src = memory(pd.src_desc(), eng);
        auto dst = memory(pd.dst_desc(), eng);
        auto prim = shuffle_forward::primitive(pd);
        printf("step: executing fwd...\n");
        fflush(stdout);
        prim.execute(stm, {{DNNL_ARG_SRC, src}, {DNNL_ARG_DST, dst}});
        stm.wait();
        printf("step: execute returned cleanly\n");
        return 0;
    } catch (const dnnl::error &e) {
        printf("dnnl::error: status=%d msg=%s\n", e.status, e.message);
        return 3;
    }
}
