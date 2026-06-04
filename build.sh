#!/bin/bash
set -euo pipefail

GCC_VERSION=${GCC_VERSION:-16}
export DEBIAN_FRONTEND=noninteractive
export TZ=Asia/Shanghai

echo "=== 开始安装所有系统依赖（Ubuntu 26.04 + GCC ${GCC_VERSION}） ==="

#!/bin/bash
set -euo pipefail

GCC_VERSION=${GCC_VERSION:-16}
export DEBIAN_FRONTEND=noninteractive
export TZ=Asia/Shanghai

echo "=== 开始安装所有系统依赖（Ubuntu 26.04 + GCC 15.2.0） ==="

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    software-properties-common openssh-client curl gnupg wget git

date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z" || true

sudo apt-get install -y --no-install-recommends \
    build-essential apt-utils sudo gosu htop iotop tree less \
    vim tmux zsh ack-grep pandoc bear net-tools bc libelf-dev libncurses-dev \
    libssl-dev libxml2-dev libedit-dev libz-dev libcurl4-openssl-dev \
    libxpm-dev libjpeg-dev libpng-dev libgif-dev libtiff-dev \
    libgnutls28-dev pkg-config fontconfig libjansson-dev \
    fonts-noto-color-emoji shfmt glslang-tools libgit2-dev \
    libtree-sitter-dev libx11-dev libxt-dev libxaw7-dev libxmu-dev \
    python3-dev python3-pip python3-venv python3-full pipx \
    markdown shellcheck ispell ripgrep fd-find libtool \
    xvfb libgtk2.0-0t64 libglib2.0-0 libcairo2 libpango-1.0-0 \
    libpangocairo-1.0-0 libgdk-pixbuf-2.0-0 \
    texinfo flex bison libgmp3-dev libmpfr-dev libmpc-dev \
    locales tzdata

# === Ubuntu 26.04 专属修改：无需 PPA，直接安装 GCC 15.2 + libgccjit ===
sudo apt-get update

sudo apt-get install -y --no-install-recommends \
    gcc-${GCC_VERSION} g++-${GCC_VERSION} \
    libgccjit-${GCC_VERSION}-dev

sudo update-alternatives --remove-all gcc || true

sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 60 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION}
sudo update-alternatives --set gcc /usr/bin/gcc-${GCC_VERSION}

sudo locale-gen en_US.UTF-8
echo "LANG=en_US.UTF-8" | sudo tee /etc/default/locale
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
sudo dpkg-reconfigure --frontend noninteractive tzdata

git config --global merge.conflictstyle diff3

sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
echo "=== 所有依赖安装完成（Ubuntu 26.04 + GCC 15.2.0 + libgccjit 已就绪） ==="
