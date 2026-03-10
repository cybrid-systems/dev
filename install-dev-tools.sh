#!/bin/bash
set -euo pipefail

echo "=== 安装基础开发工具链 ==="

export DEBIAN_FRONTEND=noninteractive
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/usr/local/lib64}"

# ==================== CMake + Ninja ====================
CMAKE_VERSION=v4.3.0-rc2
cd /tmp
wget -q https://github.com/Kitware/CMake/archive/refs/tags/$CMAKE_VERSION.tar.gz -O cmake.tar.gz
tar -zxf cmake.tar.gz
cd CMake-${CMAKE_VERSION:1}
./bootstrap --parallel=$(nproc) --prefix=/usr/local
make -j$(nproc/2) && make install
cd /tmp && rm -rf cmake* CMake-*

# Ninja
git clone https://github.com/ninja-build/ninja.git /tmp/ninja
cd /tmp/ninja
git checkout release
python3 ./configure.py --bootstrap
install -m 755 ninja /usr/local/bin/
cd /tmp && rm -rf ninja

# ==================== Oh My Zsh + tmux ====================
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true

cd /root
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .
cat >> ~/.tmux.conf.local <<'TMUX'
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
TMUX

# ==================== Node.js (LTS) ====================
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# ==================== Python 工具 ====================
pipx ensurepath
pipx install isort pipenv nose pytest black pyflakes

# ==================== Rust + fd ====================
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true

echo "=== 基础工具链安装完成 ==="
