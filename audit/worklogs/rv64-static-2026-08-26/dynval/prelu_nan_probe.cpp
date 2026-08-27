// RV64-001 dynamic validation harness: PReLU NaN-to-zero divergence
//
// Baseline: 8f49eae32bdec3674a9a98ea1524a85cd1f302db
// Kernel: src/cpu/rv64/jit_uni_prelu.cpp emit_prelu_loop():
//   vfmax_vf(vmax, vsrc, 0); vfmin_vf(vmin, vsrc, 0); vfmadd(vmin, w, vmax)
// RVV vfmax/vfmin use maximumNumber/minimumNumber: one-sided NaN picks the
// numeric operand, so a NaN input collapses to 0. The common reference
// (math_utils.hpp relu_fwd: `s > 0 ? s : s * alpha`) preserves NaN.
//
// Board: Spacemit K1 / X60 (V, Zvfh; no Zvfbfwma -> bf16 not reachable).
//
// Weights ranks must equal src ndims (src/common/prelu.cpp:98 requires
// src_desc->ndims == weights_desc->ndims). For 1D src, per-oc broadcast is
// identical to scalar broadcast ({1}), so only full/scalar are distinct.
//
// Usage: ./prelu_nan_probe <f32|f16> <x|nc|nchw> <full|scalar|per_oc>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "dnnl.hpp"

using namespace dnnl;

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

static uint32_t f32_bits(float v) {
    uint32_t bits;
    memcpy(&bits, &v, 4);
    return bits;
}

int main(int argc, char **argv) {
    if (argc < 4) {
        printf("usage: %s <f32|f16> <x|nc|nchw> <full|scalar|per_oc>\n",
                argv[0]);
        return 2;
    }
    const std::string dt_s = argv[1];
    const std::string tag_s = argv[2];
    const std::string bc_s = argv[3];
    const bool is_f16 = (dt_s == "f16");
    if (tag_s == "x" && bc_s == "per_oc") {
        printf("x/per_oc is identical to x/scalar for 1D src; skipped\n");
        return 2;
    }

    memory::data_type dt
            = is_f16 ? memory::data_type::f16 : memory::data_type::f32;

    engine eng(engine::kind::cpu, 0);
    stream stm(eng);

    // src/dst/weights shapes: weights rank always equals src ndims
    memory::dims src_dims, wei_dims;
    memory::format_tag tag;
    if (tag_s == "x") {
        src_dims = {16};
        wei_dims = (bc_s == "full") ? memory::dims {16} : memory::dims {1};
        tag = memory::format_tag::x;
    } else if (tag_s == "nc") {
        src_dims = {2, 16};
        wei_dims = (bc_s == "full") ? memory::dims {2, 16}
                : (bc_s == "per_oc") ? memory::dims {1, 16}
                                     : memory::dims {1, 1};
        tag = memory::format_tag::ab;
    } else { // nchw, 4D
        src_dims = {2, 16, 3, 3};
        wei_dims = (bc_s == "full") ? memory::dims {2, 16, 3, 3}
                : (bc_s == "per_oc") ? memory::dims {1, 16, 1, 1}
                                     : memory::dims {1, 1, 1, 1};
        tag = memory::format_tag::abcd;
    }

    auto src_md = memory::desc(src_dims, dt, tag);
    auto wei_md = memory::desc(wei_dims, dt, tag);
    auto dst_md = memory::desc(src_dims, dt, tag);

    auto pd = prelu_forward::primitive_desc(eng,
            prop_kind::forward_inference, src_md, wei_md, dst_md);
    printf("impl: %s\n", pd.impl_info_str());

    auto src_mem = memory(pd.src_desc(), eng);
    auto wei_mem = memory(pd.weights_desc(), eng);
    auto dst_mem = memory(pd.dst_desc(), eng);

    const long long src_nelems = src_md.get_size() / (is_f16 ? 2 : 4);
    const long long wei_nelems = wei_md.get_size() / (is_f16 ? 2 : 4);

    std::vector<float> host_src(src_nelems), host_wei(wei_nelems);
    for (long long i = 0; i < src_nelems; i++)
        host_src[i] = (i % 2 == 0) ? 1.5f : -2.5f;
    host_src[0] = std::nanf(""); // the probe element (f32 qNaN)
    for (long long i = 0; i < wei_nelems; i++) host_wei[i] = 0.25f;

    const uint16_t f16_qnan = 0x7e00;
    if (is_f16) {
        std::vector<uint16_t> raw(src_nelems), wraw(wei_nelems);
        for (long long i = 0; i < src_nelems; i++) {
            if (i == 0)
                raw[i] = f16_qnan;
            else
                raw[i] = f32_to_f16_bits(host_src[i]);
        }
        for (long long i = 0; i < wei_nelems; i++)
            wraw[i] = f32_to_f16_bits(host_wei[i]);
        memcpy(src_mem.get_data_handle(), raw.data(), raw.size() * 2);
        memcpy(wei_mem.get_data_handle(), wraw.data(), wraw.size() * 2);
    } else {
        memcpy(src_mem.get_data_handle(), host_src.data(),
                host_src.size() * 4);
        memcpy(wei_mem.get_data_handle(), host_wei.data(),
                host_wei.size() * 4);
    }

    // reference oracle: s > 0 ? s : s * alpha -> NaN input stays NaN
    // (implementation/reference oracle; not an unconditional public API
    //  guarantee per oneDNN docs on NaN inputs)
    auto prim = prelu_forward::primitive(pd);
    prim.execute(stm, {{DNNL_ARG_SRC, src_mem},
            {DNNL_ARG_WEIGHTS, wei_mem}, {DNNL_ARG_DST, dst_mem}});
    stm.wait();

    float got = 0.0f;
    if (is_f16) {
        uint16_t h;
        memcpy(&h, dst_mem.get_data_handle(), 2);
        got = f16_bits_to_f32(h);
        printf("dt=f16 tag=%s broadcast=%s src[0]=qNaN(0x7e00) alpha=0.25\n",
                tag_s.c_str(), bc_s.c_str());
        printf("reference semantics: dst[0]=NaN   actual dst[0]=%.7g "
               "(f16 bits=0x%04x)\n",
                (double)got, h);
        if (std::isnan(got)) {
            printf("PASS: NaN preserved (matches reference semantics)\n");
            return 0;
        }
        printf("DIVERGENCE CONFIRMED: qNaN -> 0 (RV64-001, f16 path)\n");
        return 1;
    }

    memcpy(&got, dst_mem.get_data_handle(), 4);
    printf("dt=f32 tag=%s broadcast=%s src[0]=qNaN alpha=0.25\n",
            tag_s.c_str(), bc_s.c_str());
    printf("reference semantics: dst[0]=NaN   actual dst[0]=%.7g "
           "(f32 bits=0x%08x)\n",
            (double)got, f32_bits(got));
    if (std::isnan(got)) {
        printf("PASS: NaN preserved (matches reference semantics)\n");
        return 0;
    }
    printf("DIVERGENCE CONFIRMED: qNaN -> 0 (RV64-001, f32 path)\n");
    return 1;
}
