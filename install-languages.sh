#!/bin/bash
set -euo pipefail
echo "=== 安装语言工具 (NodeJS/Python/Rust) ==="
export HOME=/home/dev

echo "=== Installing Node.js from official tarball (bypasses nodesource) ==="

# 自动检测架构
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    NODE_ARCH="linux-arm64"
    PNPM_ARCH="linux-arm64"
    echo "检测到 arm64 架构，使用 linux-arm64 tarball"
else
    NODE_ARCH="linux-x64"
    PNPM_ARCH="linux-x64"
    echo "检测到 x64 架构，使用 linux-x64 tarball"
fi

# ====================== 动态获取最新 Node.js 版本 ======================
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

# 用 Python tarfile 解压 Node.js
sudo mkdir -p /usr/local/lib/nodejs
python3 - <<PY
import tarfile
src = "node.tar.xz"
dst = "/usr/local/lib/nodejs"
print(f"Extracting {src} to {dst} with Python tarfile...")
with tarfile.open(src, "r:xz") as tar:
    tar.extractall(path=dst)
print("Node.js extract done.")
PY

sudo ln -sf /usr/local/lib/nodejs/node-v${NODE_VERSION}-${NODE_ARCH}/bin/* /usr/local/bin/
rm -f node.tar.xz
echo "Node.js ${NODE_VERSION} (${NODE_ARCH}) 安装完成"

# ====================== 安装 pnpm（官方独立二进制 + Python 解压） ======================
echo "=== Installing pnpm from official binary ==="

# 尝试获取最新版本，失败则 fallback
PNPM_VERSION=$(curl -sL --max-time 10 https://api.github.com/repos/pnpm/pnpm/releases/latest 2>/dev/null | grep -o '"tag_name":"v[^"]*"' | head -1 | cut -d'"' -f4 | tr -d 'v' || true)
if [ -z "$PNPM_VERSION" ]; then
    PNPM_VERSION="12.16.1"
    echo "⚠️ 无法获取最新 pnpm 版本，使用 fallback: ${PNPM_VERSION}"
else
    echo "pnpm version: ${PNPM_VERSION}"
fi

PNPM_URL="https://github.com/pnpm/pnpm/releases/download/v${PNPM_VERSION}/pnpm-${PNPM_ARCH}.tar.gz"
echo "Downloading ${PNPM_URL}"
curl -fsSL -o pnpm.tar.gz "$PNPM_URL" || {
    echo "❌ 下载 pnpm 失败，请检查网络或版本号"
    exit 1
}

mkdir -p /tmp/pnpm-extract
python3 - <<PY
import tarfile
import sys
src = "pnpm.tar.gz"
dst = "/tmp/pnpm-extract"
print(f"Extracting {src} to {dst} with Python tarfile...")
try:
    with tarfile.open(src, "r:gz") as tar:
        tar.extractall(path=dst)
    print("pnpm extract done.")
except Exception as e:
    print(f"Extract failed: {e}", file=sys.stderr)
    sys.exit(1)
PY

# 找到解压出来的 pnpm 二进制并安装
PNPM_BIN=$(find /tmp/pnpm-extract -type f -name 'pnpm' -o -name 'pnpm-*' | head -1 || true)
if [ -z "$PNPM_BIN" ] || [ ! -f "$PNPM_BIN" ]; then
    echo "Failed to find pnpm binary after extract. Contents:"
    find /tmp/pnpm-extract -type f || true
    exit 1
fi
echo "Found pnpm binary: $PNPM_BIN"
sudo install -m 755 "$PNPM_BIN" /usr/local/bin/pnpm
rm -rf /tmp/pnpm-extract pnpm.tar.gz

hash -r
pnpm --version
echo "pnpm installed successfully"

# 为 dev 用户设置 pnpm 环境
mkdir -p /home/dev/.local/share/pnpm
chown -R dev:dev /home/dev/.local

cat >>/home/dev/.zshrc <<'EOF'

# pnpm
export PNPM_HOME="/home/dev/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"
EOF

echo "✅ Node.js + pnpm installed successfully"

# Optional: install openclaw if you still need it
pnpm add -g openclaw@latest || echo "openclaw skipped (optional)"

# ==================== Python 工具 ====================
chown -R dev:dev /home/dev 2>/dev/null || true

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
pip install --break-system-packages pexpect

# ==================== Rust + fd ====================
apt-get update && apt-get install -y fd-find && rm -rf /var/lib/apt/lists/*

su - dev -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable"

ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true
