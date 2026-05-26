#!/bin/bash
set -euo pipefail
echo "=== 安装语言工具 (NodeJS/Python/Rust/Racket) ==="
export HOME=/home/dev

# ====================== Node.js 24（官方 tarball，支持 arm64/x64）======================
echo "=== Installing Node.js 24 from official tarball (bypasses nodesource) ==="

# 自动检测架构
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    NODE_ARCH="linux-arm64"
    RACKET_ARCH="aarch64"
    echo "检测到 arm64 架构，使用 linux-arm64 tarball"
else
    NODE_ARCH="linux-x64"
    RACKET_ARCH="x86_64"
    echo "检测到 x64 架构，使用 linux-x64 tarball"
fi

NODE_VERSION="24.15.0" # 当前最新 24.x LTS（2026-04）
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${NODE_ARCH}.tar.xz"

cd /tmp
curl -fsSL -o node.tar.xz "$NODE_URL"
sudo mkdir -p /usr/local/lib/nodejs
sudo tar -xJf node.tar.xz -C /usr/local/lib/nodejs
sudo ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-${NODE_ARCH}/bin/* /usr/local/bin/

rm -f node.tar.xz
echo "Node.js ${NODE_VERSION} (${NODE_ARCH}) 安装完成"

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
export PATH="$PNPM_HOME/bin:$PATH"
EOF

# 当前 shell 也生效
export PNPM_HOME="/home/dev/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"

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
su - dev -c "pip install pexpect --user --break-system-packages"

# ==================== Rust + fd ====================
# 先安装fd-find
apt-get update && apt-get install -y fd-find && rm -rf /var/lib/apt/lists/*

# 以dev用户运行rustup，避免HOME/euid问题
su - dev -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable"

# 链接fd
ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true

# ====================== Racket 9.1（官方最新，支持 arm64 + x86_64）======================
echo "=== Installing Racket 9.1 (官方安装器，支持 arm64/x86) ==="

cd /tmp
INSTALLER="racket-9.1-${RACKET_ARCH}-linux-buster-cs.sh"

echo "正在下载 Racket 9.1 (${RACKET_ARCH})..."
curl -fsSL -o "$INSTALLER" "https://download.racket-lang.org/releases/9.1/installers/$INSTALLER"

chmod +x "$INSTALLER"

# 安装（最干净的方式）
sudo ./"$INSTALLER" --unix-style --dest /usr/local/racket

# 创建全局软链接（racket、raco 等命令直接可用）
sudo ln -sf /usr/local/racket/bin/* /usr/local/bin/

rm -f "$INSTALLER"
echo "Racket 9.1 安装完成 ✓"

# 以dev用户运行raco pkg install（用户级，避免root下petite加载问题）
su - dev -c "raco pkg install --auto --skip-installed fmt racket-langserver"

echo "=== 语言工具安装完成 ==="
