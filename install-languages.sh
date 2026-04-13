#!/bin/bash
set -euo pipefail
echo "=== 安装语言工具 (NodeJS/Python/Rust/Racket) ==="
export HOME=/home/dev

# ==================== Node.js (LTS) ====================
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0 &&
    sudo corepack enable pnpm &&
    sudo corepack prepare pnpm@latest --activate &&
    pnpm setup &&
    cat >>~/.zshrc <<'EOF'

export PNPM_HOME="/home/dev/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
EOF
export PNPM_HOME="/home/dev/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
pnpm add -g openclaw@latest

# ==================== Python 工具 ====================
# 先确保/home/dev/.cache权限（可选，但防止root写问题）
chown -R dev:dev /home/dev 2>/dev/null || true

# 以dev用户运行pipx，避免权限问题
su - dev -c "pipx ensurepath"
su - dev -c "pipx install isort pipenv nose pytest black pyflakes"

# ==================== Rust + fd ====================
# 先安装fd-find
apt-get update && apt-get install -y fd-find && rm -rf /var/lib/apt/lists/*

# 以dev用户运行rustup，避免HOME/euid问题
su - dev -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable"

# 链接fd
ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true

# ==================== Racket ====================
# 添加PPA并apt安装
add-apt-repository ppa:plt/racket -y
apt-get update
apt-get install -y racket

# 以dev用户运行raco pkg install（用户级，避免root下petite加载问题）
su - dev -c "raco pkg install --auto --skip-installed fmt racket-langserver"

echo "=== 语言工具安装完成 ==="
