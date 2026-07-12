#!/bin/bash
set -euo pipefail
echo "=== 安装语言工具 (NodeJS/Python/Rust) ==="
export HOME=/home/dev

echo "=== Installing Node.js from official tarball (bypasses nodesource) ==="

# 自动检测架构
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    NODE_ARCH="linux-arm64"
    echo "检测到 arm64 架构，使用 linux-arm64 tarball"
else
    NODE_ARCH="linux-x64"
    echo "检测到 x64 架构，使用 linux-x64 tarball"
fi

# ====================== 动态获取最新版本（不要硬编码！） ======================
echo "=== 正在动态获取最新 Node.js 版本 ==="
NODE_VERSION=$(curl -sL --max-time 15 https://nodejs.org/dist/index.json | grep -o '"version":"v[^"]*"' | head -1 | cut -d'"' -f4 | tr -d 'v' || true)
if [ -z "$NODE_VERSION" ]; then
    NODE_VERSION="26.3.0"
    echo "⚠️ 无法从 nodejs.org 获取最新版本，使用 fallback: ${NODE_VERSION}"
else
    echo "✅ Node.js 最新版本: ${NODE_VERSION}"
fi
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${NODE_ARCH}.tar.xz"

cd /tmp
curl -fsSL -o node.tar.xz "$NODE_URL"
sudo mkdir -p /usr/local/lib/nodejs
sudo tar -xJf node.tar.xz -C /usr/local/lib/nodejs
sudo ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-${NODE_ARCH}/bin/* /usr/local/bin/

rm -f node.tar.xz
echo "Node.js ${NODE_VERSION} (${NODE_ARCH}) 安装完成"

# === 安装 pnpm（使用官方 standalone 脚本，最稳定，不依赖 npm global）===
export SHELL=/bin/bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
hash -r
pnpm --version || echo "pnpm may need PATH refresh"
echo "pnpm installed successfully"

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
echo "正在为 dev 用户安装 pexpect 并验证..."
if ! su - dev -c "
    pip install pexpect --user --break-system-packages
    python3 -c 'import pexpect; print(\"✅ pexpect 安装成功，路径：\", pexpect.__file__)'
"; then
    echo "❌ pexpect 安装失败或验证不通过，请检查网络或 Python 环境"
    exit 1
fi
# --- 新增：给 root 用户全局安装（CI 直接可用）---
pip install --break-system-packages pexpect

# ==================== Rust + fd ====================
# 先安装fd-find
apt-get update && apt-get install -y fd-find && rm -rf /var/lib/apt/lists/*

# 以dev用户运行rustup，避免HOME/euid问题
su - dev -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable"

# 链接fd
ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true
