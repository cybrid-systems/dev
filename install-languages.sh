#!/bin/bash
set -euo pipefail
echo "=== 安装语言工具 (NodeJS/Python/Rust/Racket) ==="
export HOME=/home/dev

# ==================== Node.js (LTS) ====================
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# ==================== Python 工具 ====================
# 以dev用户运行pipx，避免root pip问题
su - dev -c "pipx ensurepath"
su - dev -c "pipx install isort pipenv nose pytest black pyflakes"

# ==================== Rust + fd ====================
# 先安装fd-find（fdfind来源）
apt-get update && apt-get install -y fd-find && rm -rf /var/lib/apt/lists/*

# 以dev用户运行rustup，避免HOME/euid错误
su - dev -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable"

# 链接fd（fdfind到fd）
ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true

# ==================== Racket ====================
# 添加PPA并apt安装（替换sh installer，避免兼容问题）
add-apt-repository ppa:plt/racket -y
apt-get update
apt-get install -y racket

# 系统级安装包（作为root，使用--installation）
raco pkg install --auto --skip-installed --installation fmt racket-langserver

echo "=== 语言工具安装完成 ==="
