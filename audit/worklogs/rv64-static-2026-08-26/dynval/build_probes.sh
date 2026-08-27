#!/bin/bash
# Build all dynamic-validation probes for the RV64 audit on the board.
# Probes link against the release build (rpath-pinned); debug-library runs
# of the shuffle probes switch LD_LIBRARY_PATH to build-dbg/src (same
# soname libdnnl.so.3.14).
#
# Usage: bash dynval/build_probes.sh   (from ~/onednn-verify)
set -e
ROOT=~/onednn-verify
BUILD=$ROOT/build-rel
SRC=$ROOT/src
VAL=$ROOT/dynval
cd $ROOT

build_cpp_probe() {
    local name=$1
    g++ -O2 -g -std=c++17 -fopenmp \
        -I$SRC/include -I$BUILD/include \
        $VAL/$name.cpp -o $VAL/$name \
        -L$BUILD/src -ldnnl -Wl,-rpath,$BUILD/src
    echo "built $name (release-linked)"
}

# C++ API probes (release-linked; also run against build-dbg via LD_LIBRARY_PATH)
build_cpp_probe reduction_tail_probe
build_cpp_probe prelu_nan_probe
build_cpp_probe shuffle_zero_batch_probe

# C API probe
g++ -O1 -g -std=c++17 -I$SRC/include -I$BUILD/include \
    $VAL/shuffle_c_probe.c -o $VAL/shuffle_c_probe \
    -L$BUILD/src -ldnnl -Wl,-rpath,$BUILD/src
echo "built shuffle_c_probe (release-linked)"

# Microbenchmarks (no dnnl dependency)
gcc -march=rv64gcv -O1 -o $VAL/vta_probe $VAL/vta_probe.c
echo "built vta_probe"
gcc -O2 -o $VAL/divzero_probe $VAL/divzero_probe.c
echo "built divzero_probe"
gcc -O2 -o $VAL/zvfbfwma_probe $VAL/zvfbfwma_probe.c
echo "built zvfbfwma_probe"

echo ALL_PROBES_BUILT
