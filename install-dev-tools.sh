#!/bin/bash
set -euo pipefail

echo "=== 安装基础开发工具链 ==="

export DEBIAN_FRONTEND=noninteractive
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/usr/local/lib64}"
export HOME=/home/dev # 显式设置

# ==================== CMake + Ninja ====================
CMAKE_VERSION=v4.3.3
cd /tmp
wget -q https://github.com/Kitware/CMake/archive/refs/tags/$CMAKE_VERSION.tar.gz -O cmake.tar.gz
tar -zxf cmake.tar.gz
cd CMake-${CMAKE_VERSION:1}
./bootstrap --parallel=14 --prefix=/usr/local
make -j14 && sudo make install
cd /tmp && rm -rf cmake* CMake-*

# Ninja
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
