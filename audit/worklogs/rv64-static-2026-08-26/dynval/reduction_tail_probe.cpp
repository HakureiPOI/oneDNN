// RV64-002 dynamic validation harness: reduction tail-agnostic accumulator read
//
// Baseline: 8f49eae32bdec3674a9a98ea1524a85cd1f302db
// Kernel: src/cpu/rv64/jit_uni_reduction_kernel.cpp
//   emit_loop(): vsetvli(reg_n, ..., VTA::ta) updates v_acc[0:vl];
//                tail lanes [vl:VLMAX] are agnostic on a short last chunk
//   emit_horizontal_reduce(): vl=VLMAX, vfred*(v_red, v_acc) consumes ALL lanes
//
// Board: Spacemit K1 / X60, VLEN=256.
//   f32 (e32,m8): VLMAX = 256*8/32 = 64  -> trigger reduce_size = 65
//   f16 max/min (e16,m8): VLMAX = 128    -> trigger reduce_size = 129
//   f16 sum/mean (e16,m4 load, e32,m8 acc): active lanes = 64 -> 65
//
// Attack: put the unique extremum in a lane of the FIRST full chunk that the
// final short chunk leaves as an agnostic tail (f32: lanes 1..63 for n=65;
// f16: lanes 1..127 for n=129). If the implementation overwrites an agnostic
// tail lane with all-ones, a legit contribution is lost / qNaN contaminates.
//
// Usage: ./reduction_tail_probe <max|min|sum|mean> <f32|f16> <reduce_size> [extremum_lane]
//   extremum_lane defaults to 1 (first chunk, becomes tail). Use 64/128 (in the
//   final active chunk) as a control that must always pass.

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>

#include "dnnl.hpp"

using namespace dnnl;

static float conv_f16(float v) {
    _Float16 h = (_Float16)v;
    return (float)h;
}

static uint16_t f32_to_f16_bits(float v) {
    _Float16 h = (_Float16)v;
    uint16_t bits;
    memcpy(&bits, &h, 2);
    return bits;
}

static float f16_bits_to_f32(uint16_t bits) {
    _Float16 h;
    memcpy(&h, &bits, 2);
    return (float)h;
}

int main(int argc, char **argv) {
    if (argc < 4) {
        printf("usage: %s <max|min|sum|mean> <f32|f16> <reduce_size> [extremum_lane]\n",
                argv[0]);
        return 2;
    }
    const std::string alg_s = argv[1];
    const std::string dt_s = argv[2];
    const long long reduce_size = atoll(argv[3]);
    const long long ext_lane = (argc > 4) ? atoll(argv[4]) : 1;

    algorithm alg;
    if (alg_s == "max") alg = algorithm::reduction_max;
    else if (alg_s == "min") alg = algorithm::reduction_min;
    else if (alg_s == "sum") alg = algorithm::reduction_sum;
    else if (alg_s == "mean") alg = algorithm::reduction_mean;
    else { printf("bad alg\n"); return 2; }

    const bool is_f16 = (dt_s == "f16");
    memory::data_type sdt = is_f16 ? memory::data_type::f16 : memory::data_type::f32;

    engine eng(engine::kind::cpu, 0);
    stream stm(eng);

    memory::dims src_dims = {1, 1, 1, reduce_size};
    memory::dims dst_dims = {1, 1, 1, 1};

    auto src_md = memory::desc(src_dims, sdt, memory::format_tag::abcd);
    auto dst_md = memory::desc(dst_dims, sdt, memory::format_tag::abcd);

    auto pd = reduction::primitive_desc(eng, alg, src_md, dst_md,
            0.0f /*p*/, 0.0f /*eps*/);
    printf("impl: %s\n", pd.impl_info_str());

    auto src_mem = memory(pd.src_desc(), eng);
    auto dst_mem = memory(pd.dst_desc(), eng);

    // ---- build host data: finite, non-uniform, unique extremum at ext_lane
    std::vector<float> host(reduce_size);
    for (long long i = 0; i < reduce_size; i++)
        host[i] = 1.0f + 0.25f * (float)((i * 7) % 13); // finite non-uniform, no NaN
    if (alg_s == "max") host[ext_lane] = 1000.0f;
    if (alg_s == "min") host[ext_lane] = -1000.0f;

    // For f16 inputs, quantize each value to f16 first: the oracle must
    // operate on the same values the kernel actually consumes.
    if (is_f16)
        for (long long i = 0; i < reduce_size; i++)
            host[i] = conv_f16(host[i]);

    // ---- expected result (scalar, exact order-independent semantics)
    // All test values are exactly representable in f16 and the f32 sum of at
    // most 257 such values stays well within the f32 mantissa, so the f32
    // accumulation order does not matter and the oracle below is exact for
    // max/min/sum. For mean the kernel scales by (float)(1/n) in f32; the
    // oracle mimics that single f32 rounding.
    float expected = 0.0f;
    if (alg_s == "max" || alg_s == "min") {
        expected = host[0];
        for (long long i = 1; i < reduce_size; i++) {
            if (alg_s == "max") expected = host[i] > expected ? host[i] : expected;
            else expected = host[i] < expected ? host[i] : expected;
        }
    } else {
        double s = 0;
        for (long long i = 0; i < reduce_size; i++) s += (double)host[i];
        if (alg_s == "mean") {
            // mimic the kernel: f32 multiply by f32(1/n), applied to the
            // (exact) f32 sum
            const float sum_f32 = (float)s;
            const float scale_f32 = 1.0f / (float)reduce_size;
            expected = sum_f32 * scale_f32;
        } else {
            expected = (float)s;
        }
    }

    // ---- write src memory
    if (is_f16) {
        std::vector<uint16_t> raw(reduce_size);
        for (long long i = 0; i < reduce_size; i++)
            raw[i] = f32_to_f16_bits(host[i]);
        void *p = src_mem.get_data_handle();
        memcpy(p, raw.data(), raw.size() * 2);
    } else {
        void *p = src_mem.get_data_handle();
        memcpy(p, host.data(), host.size() * 4);
    }

    auto red = reduction::primitive(pd);
    red.execute(stm,
            {{DNNL_ARG_SRC, src_mem}, {DNNL_ARG_DST, dst_mem}});
    stm.wait();

    // ---- read dst
    float got = 0.0f;
    if (is_f16) {
        uint16_t h;
        memcpy(&h, dst_mem.get_data_handle(), 2);
        got = f16_bits_to_f32(h);
        // narrow the oracle the same way the kernel does (round-to-nearest)
        expected = conv_f16(expected);
    } else {
        memcpy(&got, dst_mem.get_data_handle(), 4);
    }

    // exact comparison: inputs are f16/f32-exact and the oracle mimics the
    // kernel's f32 ops; only a lost/contaminated accumulator lane can differ
    const bool ok = (std::isnan(got) == std::isnan(expected))
            && ((std::isnan(got)) || (got == expected));

    printf("alg=%s dt=%s reduce_size=%lld extremum_lane=%lld VLMAX=%lld\n",
            alg_s.c_str(), dt_s.c_str(), (long long)reduce_size,
            (long long)ext_lane, (long long)(is_f16 && (alg_s == "max" || alg_s == "min") ? 128 : 64));
    printf("expected=%.7g  got=%.7g  %s\n", (double)expected, (double)got,
            ok ? "PASS" : "FAIL");
    if (!ok) printf("*** RV64-002 REPRODUCED ***\n");
    return ok ? 0 : 1;
}
