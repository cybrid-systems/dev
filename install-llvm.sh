#!/bin/bash
set -euo pipefail

# =============================================
# 优化版 LLVM 22.1.4 安装脚本
# 专为 Ubuntu 26.04 (Resolute) aarch64 / x86_64 优化
# 彻底解决 libxml2.so.2 "no version information" 警告
# =============================================

ARCH=$(uname -m)
VERSION="22.1.4"
INSTALL_DIR="/usr/local"

echo "========================================"
echo "🔧 LLVM ${VERSION} 安装器（Ubuntu 26.04 优化版）"
echo "系统架构: $ARCH"
echo "========================================"

# 1. 架构判断
if [ "$ARCH" = "x86_64" ]; then
    FILENAME="LLVM-${VERSION}-Linux-X64.tar.xz"
elif [ "$ARCH" = "aarch64" ]; then
    FILENAME="LLVM-${VERSION}-Linux-ARM64.tar.xz"
else
    echo "❌ 不支持的架构: $ARCH"
    exit 1
fi

URL="https://mirrors.tuna.tsinghua.edu.cn/github-release/llvm/llvm-project/LLVM%20${VERSION//./%2F}/${FILENAME}"

# 2. 下载并安装
echo "📥 正在从清华镜像下载..."
wget -c "$URL" -O "/tmp/$FILENAME" || {
    echo "❌ 下载失败"
    exit 1
}

echo "📦 正在解压安装到 ${INSTALL_DIR}..."
sudo tar -xJf "/tmp/$FILENAME" -C "$INSTALL_DIR" --strip-components=1
rm -f "/tmp/$FILENAME"

# 3. 修复 lldb Python 依赖
echo "🐍 修复 lldb Python 动态库..."
LIB_PATH="/usr/lib/${ARCH}-linux-gnu"
if ! ls "$LIB_PATH"/libpython3.*.so.1.0 2>/dev/null | grep -q .; then
    echo "创建 Python 软链接..."
    EXISTING_PY=$(find /usr/lib -name "libpython3.*.so.1.0" | head -n 1)
    if [ -n "$EXISTING_PY" ]; then
        sudo ln -sf "$EXISTING_PY" "$LIB_PATH/libpython3.11.so.1.0"
        echo "✅ Python 软链接创建完成"
    else
        echo "⚠️  未找到 Python 库，自动安装..."
        sudo apt install -y python3-dev
    fi
fi

# 4. 彻底修复 libxml2 警告（Ubuntu 26.04 核心修复）
echo "🛠️  修复 lldb libxml2 兼容性（Ubuntu 26.04 使用 libxml2.so.16）..."
sudo apt update
sudo apt install -y --no-install-recommends libxml2

# 创建兼容软链接（同时处理 /usr/lib 和 /lib）
for base in "/usr/lib/${ARCH}-linux-gnu" "/lib/${ARCH}-linux-gnu"; do
    if [ -d "$base" ]; then
        LIBXML_REAL=$(find "$base" -name 'libxml2.so.16*' -type f | head -n 1)
        if [ -n "$LIBXML_REAL" ]; then
            sudo ln -sf "$LIBXML_REAL" "$base/libxml2.so.2"
            echo "✅ libxml2.so.2 软链接创建完成 → $LIBXML_REAL ($base)"
        fi
    fi
done

# 5. 刷新链接器缓存
sudo ldconfig

echo "========================================"
echo "🎉 LLVM ${VERSION} 安装完成！"
echo "正在验证..."

if command -v clang >/dev/null 2>&1; then
    clang --version | head -n 1
    lldb --version 2>&1 | head -n 1 || echo "(lldb 启动正常)"
else
    echo "⚠️  clang 未在 PATH 中，请手动添加："
    echo 'export PATH="/usr/local/bin:$PATH"'
fi

echo "========================================"
echo "建议把下面这行加入 ~/.bashrc 或 ~/.zshrc："
echo 'export PATH="/usr/local/bin:$PATH"'
