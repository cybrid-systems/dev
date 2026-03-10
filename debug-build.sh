#!/bin/bash
set -e

STAGE=${1:-final}
PLATFORM=${2:-linux/arm64} # Mac 用 arm64，服务器改成 linux/amd64

echo "🚀 正在构建阶段: $STAGE (平台: $PLATFORM)"

docker buildx build --platform $PLATFORM \
    --target $STAGE \
    -t ghcr.io/cybrid-systems/dev:$STAGE \
    --load .

echo "✅ 阶段 $STAGE 构建成功！"
echo "🔍 测试容器（按 Ctrl+D 退出）："
echo "docker run -it --rm ghcr.io/cybrid-systems/dev:$STAGE zsh"
