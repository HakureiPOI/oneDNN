// RV64-004 minimal C-API probe: isolate primitive creation vs execution
// failure with exact status codes (no C++ wrapper exceptions).
//
// Baseline: 8f49eae32bdec3674a9a98ea1524a85cd1f302db
//
// Usage: ./shuffle_c_probe <MB>   (0 = the defect case, >0 = control)
//
// The parent shell runs this under `timeout` and records the exit status.

#include <stdio.h>
#include <stdlib.h>
#include "dnnl.h"

static const char *st(dnnl_status_t s) {
    switch (s) {
        case dnnl_success: return "success";
        case dnnl_invalid_arguments: return "invalid_arguments";
        case dnnl_out_of_memory: return "out_of_memory";
        case dnnl_unimplemented: return "unimplemented";
        case dnnl_runtime_error: return "runtime_error";
        default: return "other";
    }
}

int main(int argc, char **argv) {
    const int mb = (argc > 1) ? atoi(argv[1]) : 0;
    printf("MB=%d C=4 W=1 axis=1 group=2\n", mb);

    dnnl_engine_t eng = NULL;
    dnnl_status_t s = dnnl_engine_create(&eng, dnnl_cpu, 0);
    printf("engine: %s\n", st(s));
    if (s != dnnl_success) return 1;

    dnnl_dims_t dims = {mb, 4, 1};
    dnnl_memory_desc_t md = NULL;
    s = dnnl_memory_desc_create_with_tag(&md, 3, dims, dnnl_f32, dnnl_ncw);
    printf("md: %s\n", st(s));
    if (s != dnnl_success) return 1;

    dnnl_primitive_desc_t pd = NULL;
    s = dnnl_shuffle_forward_primitive_desc_create(&pd, eng,
            dnnl_forward_inference, md, md, 1, 2, NULL);
    printf("pd create: %s\n", st(s));
    if (s != dnnl_success) return 1;

    {
        const char *impl = NULL;
        s = dnnl_primitive_desc_query(pd, dnnl_query_impl_info_str,
                0, (void *)&impl);
        printf("pd impl: %s (%s)\n", impl ? impl : "(null)", st(s));
    }

    dnnl_primitive_t prim = NULL;
    s = dnnl_primitive_create(&prim, pd);
    printf("primitive create: %s\n", st(s));
    if (s != dnnl_success) {
        printf(">>> primitive creation failed\n");
        return 2;
    }

    dnnl_memory_t src = NULL, dst = NULL;
    s = dnnl_memory_create(&src, md, eng, DNNL_MEMORY_ALLOCATE);
    printf("src mem: %s\n", st(s));
    s = dnnl_memory_create(&dst, md, eng, DNNL_MEMORY_ALLOCATE);
    printf("dst mem: %s\n", st(s));
    if (s != dnnl_success) return 3;

    dnnl_stream_t stm = NULL;
    s = dnnl_stream_create(&stm, eng, dnnl_stream_default_flags);
    printf("stream: %s\n", st(s));
    if (s != dnnl_success) return 3;

    dnnl_exec_arg_t args[2] = {{DNNL_ARG_SRC, src}, {DNNL_ARG_DST, dst}};
    printf("step: executing...\n");
    fflush(stdout);
    s = dnnl_primitive_execute(prim, stm, 2, args);
    printf("execute: %s  <-- RV64-004 interest point\n", st(s));
    s = dnnl_stream_wait(stm);
    printf("wait: %s\n", st(s));
    return 0;
}
