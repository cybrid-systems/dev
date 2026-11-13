#!/bin/bash
# Aura build dependencies on Ubuntu 26.
# GCC 16.2, latest CMake, distro Ninja (1.13.2, current upstream), mold,
# libgit2, and the Python tools build.py gate/CI install.
set -euo pipefail

GCC_VERSION="${GCC_VERSION:-16}"
CMAKE_VERSION="${CMAKE_VERSION:-4.5.0}"
export DEBIAN_FRONTEND=noninteractive
export TZ="${TZ:-Asia/Shanghai}"

echo "=== Aura build packages (GCC ${GCC_VERSION}, CMake ${CMAKE_VERSION}) ==="

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    git \
    sudo \
    gnupg \
    locales \
    tzdata \
    pkg-config \
    make \
    ninja-build \
    mold \
    python3 \
    python3-pip \
    python3-venv \
    libc6-dev \
    "gcc-${GCC_VERSION}" \
    "g++-${GCC_VERSION}" \
    libgit2-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libzstd-dev \
    libxml2-dev

# libc6-dev is only a Recommends of gcc-16. Headers are required to compile.
update-alternatives --install /usr/bin/gcc gcc "/usr/bin/gcc-${GCC_VERSION}" 60 \
    --slave /usr/bin/g++ g++ "/usr/bin/g++-${GCC_VERSION}"
update-alternatives --install /usr/bin/cc cc "/usr/bin/gcc-${GCC_VERSION}" 60
update-alternatives --install /usr/bin/c++ c++ "/usr/bin/g++-${GCC_VERSION}" 60
update-alternatives --set gcc "/usr/bin/gcc-${GCC_VERSION}"
update-alternatives --set cc "/usr/bin/gcc-${GCC_VERSION}"
update-alternatives --set c++ "/usr/bin/g++-${GCC_VERSION}"

gcc_line=$(gcc --version | head -n 1)
echo "gcc: ${gcc_line}"
echo "${gcc_line}" | grep -q '16\.2\.' || {
    echo "expected GCC 16.2, got: ${gcc_line}" >&2
    exit 1
}

if [ -z "$(find /usr/lib/gcc -name 'libstdc++.modules.json' -print -quit)" ]; then
    echo "g++-${GCC_VERSION} did not ship libstdc++.modules.json (import std)" >&2
    exit 1
fi
if [ -z "$(find /usr/lib/gcc -name 'libstdc++exp.a' -print -quit)" ]; then
    echo "g++-${GCC_VERSION} did not ship libstdc++exp.a" >&2
    exit 1
fi

locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

# Pinned to aura requirements-dev.txt (ruff, pexpect). CI reinstalls the
# same file; these are on PATH so a local ./build.py gate works.
python3 -m pip install --no-cache-dir --break-system-packages \
    'ruff==0.17.3' \
    'pexpect==4.9.0'

echo "=== CMake ${CMAKE_VERSION} ==="
arch=$(uname -m)
case "$arch" in
    x86_64) cmake_arch=linux-x86_64 ;;
    aarch64 | arm64) cmake_arch=linux-aarch64 ;;
    *)
        echo "unsupported architecture: $arch" >&2
        exit 1
        ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fL --retry 5 --retry-delay 2 \
    -o "$tmp/cmake.tar.gz" \
    "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-${cmake_arch}.tar.gz"

python3 - "$tmp/cmake.tar.gz" /usr/local <<'PY'
import sys
import tarfile

src, dst = sys.argv[1], sys.argv[2]
with tarfile.open(src, "r:gz") as tar:
    members = []
    for member in tar.getmembers():
        name = member.name[2:] if member.name.startswith("./") else member.name
        parts = name.split("/", 1)
        if len(parts) == 2 and parts[1]:
            member.name = parts[1]
            members.append(member)
    tar.extractall(path=dst, members=members)
PY

# cmake-gui needs libxcb, libfontconfig, and libfreetype. This image does
# not install them. Remove the binary so it is not left on PATH.
rm -f /usr/local/bin/cmake-gui

cmake_line=$(cmake --version | head -n 1)
echo "cmake: ${cmake_line}"
echo "${cmake_line}" | grep -q "${CMAKE_VERSION}" || {
    echo "cmake version mismatch: ${cmake_line}" >&2
    exit 1
}

echo "=== toolchain smoke (gcc 16.2 + mold) ==="
cat >"$tmp/atomic.cpp" <<'EOF'
#include <atomic>
int main() {
    std::atomic<int> value{0};
    value.fetch_add(1, std::memory_order_relaxed);
    return value.load(std::memory_order_relaxed) == 1 ? 0 : 1;
}
EOF
g++ -std=c++26 -fcontracts -freflection -fuse-ld=mold \
    "$tmp/atomic.cpp" -o "$tmp/atomic"
"$tmp/atomic"

echo "ninja $(ninja --version)"
echo "mold $(mold --version | head -n 1)"
echo "libgit2 $(pkg-config --modversion libgit2)"
python3 -c 'import pexpect'
ruff --version

apt-get clean
rm -rf /var/lib/apt/lists/*
echo "=== base packages ready ==="
