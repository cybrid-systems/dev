#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
LLVM_VERSION=21.1.7
LLVM_TAR=llvm-project-$LLVM_VERSION.src.tar.xz
LLVM_DIR=llvm-project-$LLVM_VERSION.src

apt update
apt install -y \
    libz-dev \
    libxml2-dev \
    libedit-dev \

cd && wget https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/$LLVM_TAR
tar -xf $LLVM_TAR
cd $LLVM_DIR

mkdir build && cd build
cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    ../llvm

ninja -j10
ninja install

# 清理
cd && rm -rf $LLVM_TAR $LLVM_DIR
