// vta_probe.c — direct RVV microbenchmark: does the Spacemit X60 preserve
// tail lanes when VTA::ta (tail-agnostic) is set and a short vl writes the
// destination? This is the exact policy the RV64-002 reduction kernel
// relies on when it later reads all VLMAX lanes of the accumulator.
//
// Method: load 64 sentinel floats into an e32/m8 register group (VLMAX=64
// at VLEN=256), then perform a vfadd.vv with vl=1 (VTA::ta), which updates
// only lane 0 and leaves lanes 1..63 tail-agnostic. Read the register back
// and inspect which lanes changed.
//
// Build: gcc -march=rv64gcv -O1 -o vta_probe vta_probe.c
#include <stdio.h>
#include <stdint.h>
#include <string.h>

int main() {
    float init[64], after[64];
    for (int i = 0; i < 64; i++) init[i] = 100.0f + i; // sentinels

    asm volatile(
        "vsetvli t0, x0, e32, m8, ta, ma\n"   // vl = VLMAX = 64
        "vle32.v v8, (%0)\n"                   // v8 = sentinels
        "li t1, 1\n"
        "vsetvli t0, t1, e32, m8, ta, ma\n"    // vl = 1, ta, ma
        "vmv.v.i v16, 0\n"                     // v16 = zeros (operand)
        "vfadd.vv v8, v8, v16\n"               // updates v8[0]; lanes 1..63 agnostic
        "vsetvli t0, x0, e32, m8, ta, ma\n"    // vl = VLMAX again
        "vse32.v v8, (%1)\n"                   // read back
        : : "r"(init), "r"(after) : "t0", "t1", "v8", "v16", "memory"
    );

    int changed = 0, allones = 0;
    for (int i = 1; i < 64; i++) {
        if (after[i] != init[i]) changed++;
        uint32_t bits;
        memcpy(&bits, &after[i], 4);
        if (bits == 0xffffffff) allones++;
    }
    printf("tail lanes changed: %d/63, all-ones(qNaN bits): %d\n",
            changed, allones);
    printf("after[1]=%.1f after[32]=%.1f after[63]=%.1f (init: %.1f %.1f %.1f)\n",
            after[1], after[32], after[63], init[1], init[32], init[63]);
    return 0;
}
