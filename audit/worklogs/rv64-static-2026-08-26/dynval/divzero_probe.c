// divzero_probe.c — RISC-V integer division-by-zero behavior microbenchmark.
//
// RV64-002/RV64-004 follow-up: determine the observable behavior of the
// `div` instruction with a zero divisor on the Spacemit X60, and of the
// exact source expression used by jit_uni_shuffle_t::execute()
// (utils::div_up) when its divisor is zero.
//
// Part 1: bare asm `div rd, 7, 0` — the RISC-V ISA spec defines this as
//         returning -1 without trapping. Confirmed on hardware.
// Part 2: the C-level pattern `1 + (nthr - 1) / tasks` with tasks == 0.
//         C/C++ semantics: undefined behavior. Observed hardware behavior:
//         div returns -1, so the expression evaluates to 0.
//
// Build: gcc -O2 -o divzero_probe divzero_probe.c
#include <stdio.h>

volatile long tasks = 0;
volatile long nthr_v = 8;

int main() {
    // Part 1: raw instruction behavior
    long q;
    asm volatile(
        "li a0, 7\n"
        "li a1, 0\n"
        "div %0, a0, a1\n"
        : "=r"(q) :: "a0", "a1");
    printf("asm div 7/0 = %ld (spec: -1, no trap)\n", q);

    // Part 2: the exact div_up source expression with b == 0
    long nthr = nthr_v;
    long inner = 1 + (nthr - 1) / tasks; // tasks == 0 -> UB in C/C++
    printf("div_up(%ld, %ld) pattern = 1 + (%ld-1)/%ld = %ld\n", nthr,
            (long)tasks, nthr, (long)tasks, inner);

    // Part 3: the outer expression in execute(): div_up(sp, inner) with
    // sp = 1 and inner = 0
    long sp = 1;
    long outer = 1 + (sp - 1) / inner; // inner == 0 -> UB in C/C++
    printf("div_up(sp=%ld, inner=%ld) = %ld; nstl::max(1, %ld) = 1\n", sp,
            inner, outer, outer);

    printf("conclusion: hardware div-by-zero returns -1 without trapping;\n"
           "the shuffle release path computes wrong intermediate values but\n"
           "the max(1, ...) clamp keeps sp_split_size == 1 and no fault is\n"
           "observable. The C++ source is still UB.\n");
    return 0;
}
