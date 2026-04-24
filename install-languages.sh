#!/bin/bash
set -euo pipefail
echo "=== 安装语言工具 (NodeJS/Python/Rust/Racket) ==="
export HOME=/home/dev

# ==================== Node.js 24 (官方二进制安装 - 兼容 Shadowrocket) ====================
echo "=== Installing Node.js 24 from official tarball (bypasses nodesource) ==="

# 清理之前失败的安装
apt-get purge -y nodejs npm libnode* || true
apt-get autoremove -y || true

# 下载并安装官方 Node.js 24.15.0（2026年4月最新 LTS）
NODE_VERSION="24.15.0"
curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz

tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1
rm -f /tmp/node.tar.xz

# 验证安装
node --version
npm --version

# === Corepack + pnpm ===
npm install -g corepack@latest
corepack enable pnpm
corepack prepare pnpm@latest --activate

# 为 dev 用户设置 pnpm 环境
mkdir -p /home/dev/.local/share/pnpm
chown -R dev:dev /home/dev/.local

cat >>/home/dev/.zshrc <<'EOF'

# pnpm
export PNPM_HOME="/home/dev/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
EOF

# 当前 shell 也生效
export PNPM_HOME="/home/dev/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

pnpm --version
echo "✅ Node.js + pnpm installed successfully"

# Optional: install openclaw if you still need it
pnpm add -g openclaw@latest || echo "openclaw skipped (optional)"

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
