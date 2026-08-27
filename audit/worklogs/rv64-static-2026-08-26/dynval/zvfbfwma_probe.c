// zvfbfwma_probe.c — runtime detection probe for the Zvfbfwma extension.
//
// The /proc/cpuinfo ISA string may not be authoritative (kernels may not
// surface every extension), and oneDNN itself detects Zvfbfwma at runtime:
// src/cpu/rv64/cpu_isa_traits.cpp executes a vfwmaccbf16.vf instruction
// inside a sigaction-protected block (probe_zvfbfwma_impl). This probe
// replicates that exact method (same instruction encodings, same
// SIGILL-guard pattern) to determine whether this X60 can execute
// Zvfbfwma instructions — the authoritative check for whether the
// RV64-003 BF16 BRGEMM path is reachable on this board.
//
// Build: gcc -O2 -o zvfbfwma_probe zvfbfwma_probe.c
#include <stdio.h>
#include <signal.h>
#include <setjmp.h>

static sigjmp_buf probe_jmp;
static volatile sig_atomic_t trapped = 0;

static void sigill_handler(int sig) {
    (void)sig;
    trapped = 1;
    siglongjmp(probe_jmp, 1);
}

int main() {
    struct sigaction sa, old_sa;
    sa.sa_handler = sigill_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGILL, &sa, &old_sa) != 0) {
        printf("sigaction failed\n");
        return 2;
    }

    if (sigsetjmp(probe_jmp, 1) == 0) {
        // identical encodings to oneDNN probe_zvfbfwma_impl():
        //   vsetivli zero, 4, e16, m1, ta, ma   (0xcc807057)
        //   vfwmaccbf16.vf v2, fa0, v6          (0xee655157)
        asm volatile(
                ".4byte 0xcc807057\n"
                ".4byte 0xee655157\n"
                :
                :
                : "memory");
        printf("executed without trap\n");
    } else {
        printf("SIGILL trapped\n");
    }
    sigaction(SIGILL, &old_sa, 0);
    printf("zvfbfwma instruction: %s\n",
            trapped ? "NOT executable (trapped)" : "executable");
    return trapped ? 1 : 0;
}
