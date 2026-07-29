#!/bin/bash
# ================================================
# Lobster Dev Environment (cybrid-systems/dev)
# 架构无关测试脚本（支持 x86_64 和 arm64）
# ================================================

set -e

IMAGE="ghcr.io/cybrid-systems/dev:v1.0.5"
CONTAINER_NAME="lobster-test"

echo "🚀 开始测试 Lobster Dev Environment (自动检测架构)..."

# Docker 检测
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi
echo "✅ Docker 已安装 ($(which docker))"

# 显示当前架构（方便确认）
echo "🖥️  当前宿主机架构: $(uname -m)"

# 启动测试容器（去掉 --platform，让 Docker 自动选择）
echo "🧪 启动容器并执行功能测试 (使用 zsh)..."
docker run --rm -it \
    --name "$CONTAINER_NAME" \
    "$IMAGE" /bin/zsh -l -c '
set -e
echo "✅ 容器启动成功 - 使用 zsh"
echo "🖥️  容器架构: $(uname -m)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 工具版本检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Clang / LLVM :" && clang --version | head -n 1
echo "GCC 15       :" && gcc --version | head -n 1
echo "Rust         :" && rustc --version
echo "Cargo        :" && cargo --version
echo "Node.js      :" && node --version
echo "npm          :" && npm --version
echo "Python       :" && python3 --version
echo "CMake        :" && cmake --version | head -n 1
echo "Ninja        :" && ninja --version
echo "Emacs        :" && emacs --version | head -n 1
echo "fd           :" && fd --version
echo "rg           :" && rg --version | head -n 1
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "🧪 编译测试 (Hello World)"
cat > /tmp/test.c << EOF
#include <stdio.h>
int main() { printf("✅ LLVM/Clang + GCC 编译通过！\n"); return 0;  }
EOF
clang /tmp/test.c -o /tmp/test_clang && /tmp/test_clang
gcc /tmp/test.c -o /tmp/test_gcc && /tmp/test_gcc

cat > /tmp/test.rs << EOF
fn main() { println!("✅ Rust 编译通过！");  }
EOF
rustc /tmp/test.rs -o /tmp/test_rust && /tmp/test_rust

echo "🧪 Node.js 测试"
node -e '\''console.log("✅ Node.js 运行正常")'\''

echo "🧪 Python 测试"
python3 -c '\''print("✅ Python 运行正常")'\''

echo "🎉 所有测试通过！Lobster Dev Environment 功能完整。"
'

echo "✅ 测试完成！"
