#!/bin/bash
set -euo pipefail

echo "=== 安装基础开发工具链 ==="

export DEBIAN_FRONTEND=noninteractive
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/usr/local/lib64}"
export HOME=/home/dev # 显式设置

# ==================== CMake（官方二进制，用 Python 解压） ====================
CMAKE_VERSION=4.5.0-rc2
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    CMAKE_ARCH=linux-x86_64
    ;;
  aarch64|arm64)
    CMAKE_ARCH=linux-aarch64
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

cd /tmp
echo "Downloading CMake ${CMAKE_VERSION} (${CMAKE_ARCH})..."
wget -q "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-${CMAKE_ARCH}.tar.gz" -O cmake.tar.gz

# 用 Python tarfile 解压，避开系统 tar 的 openat2 问题
python3 - <<'PY'
import tarfile
import os

src = "cmake.tar.gz"
dst = "/usr/local"

print(f"Extracting {src} to {dst} with Python tarfile...")
with tarfile.open(src, "r:gz") as tar:
    # strip-components=1
    members = []
    for m in tar.getmembers():
        if m.name.startswith("./"):
            m.name = m.name[2:]
        parts = m.name.split("/", 1)
        if len(parts) == 2:
            m.name = parts[1]
            members.append(m)
        # 跳过顶层目录本身
    tar.extractall(path=dst, members=members)
print("Extract done.")
PY

rm -f cmake.tar.gz
echo "CMake ${CMAKE_VERSION} installed to /usr/local"

# ==================== Ninja ====================
echo "Building Ninja..."
git clone https://github.com/ninja-build/ninja.git /tmp/ninja
cd /tmp/ninja
git checkout release
python3 ./configure.py --bootstrap
sudo install -m 755 ninja /usr/local/bin/
cd /tmp && rm -rf ninja

# ==================== Oh My Zsh + tmux ====================
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
echo 'export PATH="$HOME/.cargo/bin:$HOME/.config/emacs/bin:$PATH:$HOME/.local/bin"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TERM=xterm-256color' >>~/.zshrc

cd /home/dev
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .
cat >>~/.tmux.conf.local <<'TMUX'
set -g history-limit 100000
set -g status-keys vi
set -g mode-keys vi
set -gu prefix2
unbind C-a
unbind C-b
bind-key -T copy-mode-vi 'v' send -X begin-selection
bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel
set -g prefix M-o
bind M-o send-prefix
set -g default-command "zsh"
TMUX

echo "=== 基础工具链安装完成 ==="
