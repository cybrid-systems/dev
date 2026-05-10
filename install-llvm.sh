#!/bin/bash
set -euo pipefail

# 1. 架构检测与变量设置
ARCH=$(uname -m)
VERSION="22.1.5"
VERSION_ENCODED="$VERSION%2F" # 编码斜杠
TARGET_PYTHON="libpython3.11.so.1.0"
INSTALL_DIR="/usr/local"
LIB_PATH=""

echo "---------------------------------------"
echo "检测到系统架构: $ARCH"

if [ "$ARCH" == "x86_64" ]; then
    FILENAME="LLVM-${VERSION}-Linux-X64.tar.xz"
    LIB_PATH="/usr/lib/x86_64-linux-gnu"
elif [ "$ARCH" == "aarch64" ]; then
    FILENAME="LLVM-${VERSION}-Linux-ARM64.tar.xz"
    LIB_PATH="/usr/lib/aarch64-linux-gnu"
else
    echo "错误: 不支持的架构 $ARCH"
    exit 1
fi

URL="https://mirrors.tuna.tsinghua.edu.cn/github-release/llvm/llvm-project/LLVM%20${VERSION_ENCODED}/${FILENAME}"

# 2. 下载与安装
echo "正在从清华镜像下载 LLVM ${VERSION}..."
wget -c "$URL" -O "/tmp/$FILENAME"

echo "正在解压并安装到 ${INSTALL_DIR}..."
tar -xJf "/tmp/$FILENAME" -C "$INSTALL_DIR" --strip-components=1
rm "/tmp/$FILENAME"

# 3. 修复 lldb 的 Python 依赖（保留原逻辑）
echo "检查 lldb 的 Python 动态库依赖..."
if [ ! -f "$LIB_PATH/$TARGET_PYTHON" ]; then
    echo "未发现 $TARGET_PYTHON，正在尝试建立软链接..."
    EXISTING_PY=$(find /usr/lib -name "libpython3.*.so.1.0" | head -n 1)
    if [ -n "$EXISTING_PY" ]; then
        echo "发现可用库: $EXISTING_PY"
        ln -sf "$EXISTING_PY" "$LIB_PATH/$TARGET_PYTHON"
        echo "软链接创建成功"
    else
        echo "警告: 未找到 libpython3.x.so.1.0，建议执行: apt install -y python3-dev"
    fi
fi

# 4. 【关键修复】lldb 的 libxml2 依赖（Ubuntu 25.10+/26.04 专用）
echo "修复 lldb 的 libxml2 依赖 (Ubuntu 26.04 使用 libxml2.so.16)..."

apt-get update -qq
apt-get install -y --no-install-recommends libxml2-16 patchelf

# 1. 创建兼容软链接（给其他可能依赖 .so.2 的软件用）
LIBXML2_REAL=$(find /usr/lib -name 'libxml2.so.16*' -type f | head -n 1)
if [ -n "$LIBXML2_REAL" ]; then
    ln -sf "$LIBXML2_REAL" "$LIB_PATH/libxml2.so.2"
    echo "✅ 已创建软链接: libxml2.so.2 → $LIBXML2_REAL"
else
    echo "⚠️  未找到 libxml2.so.16*"
fi

# 2. 使用 patchelf 直接修改 liblldb.so 的依赖（消除 warning 的关键）
echo "使用 patchelf 修改 liblldb 的依赖..."
LLDB_SO=$(find "$INSTALL_DIR/lib" -name 'liblldb.so.22*' -type f | head -n 1)
if [ -n "$LLDB_SO" ] && command -v patchelf >/dev/null 2>&1; then
    patchelf --replace-needed libxml2.so.2 libxml2.so.16 "$LLDB_SO" 2>/dev/null || true
    echo "✅ patchelf 修改完成: $LLDB_SO 现在直接依赖 libxml2.so.16"
else
    echo "⚠️  patchelf 修改失败（未找到 liblldb.so 或 patchelf）"
fi

# 5. 刷新缓存与验证
ldconfig

echo "---------------------------------------"
if command -v clang >/dev/null; then
    echo "✅ LLVM $VERSION 安装完成！"
    clang --version | head -n 1
    lldb --version | head -n 1
else
    echo "安装失败，请检查 PATH 变量。"
fi
