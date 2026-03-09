#!/bin/bash

set -euo pipefail

GCC_VERSION=${GCC_VERSION:-15}
export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git &&
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# === Phase 1: 系统依赖 + gosu（动态切换用户神器）===
apt-get update && apt-get install -y --no-install-recommends \
    build-essential apt-utils zsh vim tmux \
    libssl-dev ack-grep rsync ccache software-properties-common \
    python3-dev net-tools bc bear libelf-dev pandoc tree \
    libxpm-dev libjpeg-dev libpng-dev libgif-dev libtiff-dev \
    libgnutls28-dev pkg-config fontconfig libjansson-dev \
    fonts-emojione shfmt markdown shellcheck ispell \
    glslang-tools texinfo libtree-sitter-dev libncurses-dev \
    python3-pip python3-venv python3-full pipx \
    ripgrep fd-find libtool sudo gosu &&
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# GCC 安装：架构自适应
ARCH=$(dpkg --print-architecture) # 或 uname -m | grep -q aarch64 && echo arm64

echo "Detected architecture: $ARCH"

if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    echo "arm64 detected: fallback to GCC 14 (gcc-15 not reliably available in PPA)"
    GCC_VERSION=14
else
    echo "amd64/x86_64: trying GCC ${GCC_VERSION}"
fi

add-apt-repository ppa:ubuntu-toolchain-r/test -y &&
    apt-get update &&
    apt-get install -y gcc-${GCC_VERSION} g++-${GCC_VERSION} &&
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 60 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} &&
    update-alternatives --set gcc /usr/bin/gcc-${GCC_VERSION} &&
    rm -rf /var/lib/apt/lists/*

if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    if [ -f "/tmp/build-gcc.sh" ]; then
        echo "Falling back to build-gcc.sh for potential custom GCC build"
        bash /tmp/build-gcc.sh || echo "build-gcc.sh failed, continuing with system fallback"
    fi
fi
GCC_VERSION=15
apt-get install -y libgccjit-${GCC_VERSION}-dev

# locale
apt update
apt -y install locales tzdata
locale-gen en_US.UTF-8
echo "LANG=en_US.UTF-8" >>/etc/default/locale
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata
