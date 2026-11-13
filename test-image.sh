#!/bin/bash
# Smoke-test the Aura-minimal image. Override the tag with IMAGE=...
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/cybrid-systems/aura-ci:v0.1.1}"

if ! command -v docker >/dev/null 2>&1; then
    echo "docker is not installed" >&2
    exit 1
fi

echo "host arch: $(uname -m)"
echo "image: ${IMAGE}"

docker run --rm "$IMAGE" bash -c '
set -euo pipefail
echo "arch: $(uname -m)"
echo "gcc: $(gcc --version | head -n 1)"
gcc --version | head -n 1 | grep -q "16\.2\."
echo "cmake: $(cmake --version | head -n 1)"
echo "ninja: $(ninja --version)"
echo "mold: $(mold --version | head -n 1)"
echo "clang: $(clang --version | head -n 1)"
echo "lld: $(ld.lld --version | head -n 1)"
echo "clang-format: $(clang-format --version | head -n 1)"
echo "clang-tidy: $(clang-tidy --version | head -n 1)"
clang_ver=$(clang --version | sed -n "s/.*clang version \\([0-9.]*\\).*/\\1/p" | head -n 1)
scan_ver=$(clang-scan-deps --version | sed -n "s/.*LLVM version \\([0-9.]*\\).*/\\1/p" | head -n 1)
echo "clang-scan-deps: LLVM version ${scan_ver}"
test -n "$clang_ver"
test "$scan_ver" = "$clang_ver"
echo "llvm-cov: $(llvm-cov --version | head -n 1)"
echo "llvm-profdata: $(llvm-profdata --version | head -n 1)"
llvm-config --link-static --libnames core orcjit native nativecodegen mc >/dev/null
echo "libgit2: $(pkg-config --modversion libgit2)"
python3 -c "import pexpect"
ruff --version
test -n "$(find /usr/lib/gcc -name libstdc++.modules.json -print -quit)"

cat > /tmp/atomic.cpp << "EOF"
#include <atomic>
int main() {
    std::atomic<int> value{0};
    value.fetch_add(1, std::memory_order_relaxed);
    return value.load(std::memory_order_relaxed) == 1 ? 0 : 1;
}
EOF
g++ -std=c++26 -fcontracts -freflection -fuse-ld=mold /tmp/atomic.cpp -o /tmp/atomic_mold
clang++ -fuse-ld=lld /tmp/atomic.cpp -o /tmp/atomic_lld
/tmp/atomic_mold
/tmp/atomic_lld
echo "aura toolchain smoke passed"
'

echo "image test passed"
