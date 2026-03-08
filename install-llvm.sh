#!/bin/bash
set -euo pipefail

# 1. 架构检测与变量设置
ARCH=$(uname -m)
VERSION="22.1.0"
TARGET_PYTHON="libpython3.11.so.1.0"
INSTALL_DIR="/usr/local"

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

URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/${FILENAME}"

# 2. 下载与安装
echo "正在从 GitHub 下载 LLVM ${VERSION}..."
wget -c "$URL" -O "/tmp/$FILENAME"

if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络。"
    exit 1
fi

echo "正在解压并安装到 ${INSTALL_DIR}..."
tar -xJf "/tmp/$FILENAME" -C "$INSTALL_DIR" --strip-components=1
rm "/tmp/$FILENAME"

# 3. 核心修复：修复 lldb 的 Python 依赖
echo "检查 lldb 的动态库依赖..."
if [ ! -f "$LIB_PATH/$TARGET_PYTHON" ]; then
    echo "未发现 $TARGET_PYTHON，正在尝试从现有 Python 库建立软链接..."

    # 查找系统现有的 python 3.x 共享库 (排除 3.11 自身)
    EXISTING_PY=$(find /usr/lib -name "libpython3.*.so.1.0" | head -n 1)

    if [ -n "$EXISTING_PY" ]; then
        echo "发现可用库: $EXISTING_PY"
        ln -sf "$EXISTING_PY" "$LIB_PATH/$TARGET_PYTHON"
        echo "软链接创建成功: $TARGET_PYTHON -> $EXISTING_PY"
    else
        echo "警告: 未在系统中发现任何 libpython3.x.so.1.0，lldb 可能无法运行。"
        echo "建议执行: apt install -y python3-dev"
    fi
fi

# 4. 刷新缓存与验证
ldconfig
echo "---------------------------------------"
if command -v clang >/dev/null; then
    echo "LLVM 22.1.0 安装完成！"
    clang --version | head -n 1
    lldb --version | head -n 1
else
    echo "安装失败，请检查 PATH 变量。"
fi
