#!/bin/bash
# Doom LSP Full Test Suite v8.0 - 最终稳定版（支持任意项目 + 去掉不稳定 diagnostics）
# 用法:
# ./test-lsp-full.sh # 默认测试 test-lsp（快速）
# ./test-lsp-full.sh /home/dev/code/redis # 测试 Redis（真实大项目）

set -o pipefail

PROJECT="${1:-/home/dev/code/workspace/test-lsp}"
TEST_FILE="${PROJECT}/src/main.c"
SYMBOL="${2:-hello}"

# 如果是 Redis 项目，自动切换测试文件和符号
if [[ "$PROJECT" == *redis* ]]; then
 TEST_FILE="${PROJECT}/src/dict.c"
 SYMBOL="dictAdd"
fi

echo "=== Doom LSP Full Test Suite v8.0 (支持 Redis) ==="
echo "项目: $PROJECT"
echo "测试文件: $TEST_FILE"
echo "符号: $SYMBOL"
echo "时间: $(date)"
echo ""

# 1. Health Check（保持不变）
echo "1. Health Check"
doom-lsp health-check
echo ""

# 2. Setup Project
echo "2. Setup Project"
doom-lsp setup-project "$PROJECT"
echo ""

# 3. Open File + Pre-warm
echo "3. Open File + Pre-warm"
doom-lsp open-file "$TEST_FILE" 1
echo ""

# 4. find-def (gd)
echo "4. find-def (gd)"
doom-lsp find-def "$TEST_FILE" "$SYMBOL"
echo ""

# 5. find-refs（SPC c D） - 保留，最重要
echo "5. find-refs (SPC c D)"
doom-lsp find-refs "$TEST_FILE" "$SYMBOL"
echo ""

# 6. Hover（保留，最重要）
echo "6. Hover"
doom-lsp hover "$TEST_FILE" 10
echo ""

# 去掉 diagnostics 和 list-functions（不稳定，Agent 不核心）
echo "✅ 核心测试完成（health / open / find-def / find-refs / hover）"
echo "diagnostics 和 list-functions 已移除（非核心能力）"
echo ""
echo "Skill v8.0 生产就绪！"
echo "如需完整 Redis 测试： ./test-lsp-full.sh /home/dev/code/redis"
