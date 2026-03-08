#!/bin/bash

set -euo pipefail

GCC_VERSION=${GCC_VERSION:-15}
export DEBIAN_FRONTEND=noninteractive

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

add-apt-repository ppa:ubuntu-toolchain-r/test -y &&
    apt-get update &&
    apt-get install -y gcc-$$ {GCC_VERSION} g++- $${GCC_VERSION} && libgccjit-${GCC_VERSION}-dev &&
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 60 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} &&
    update-alternatives --set gcc /usr/bin/gcc-${GCC_VERSION} &&
    rm -rf /var/lib/apt/lists/*

# locale
apt update
apt -y install locales tzdata
locale-gen en_US.UTF-8
echo "LANG=en_US.UTF-8" >>/etc/default/locale
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata
