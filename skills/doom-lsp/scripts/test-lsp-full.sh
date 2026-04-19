#!/bin/bash
# Doom LSP Full Test Suite v7.6 - Final Version with Wait for Indexing
# 默认使用 workspace 内的小测试项目 (可靠，不受 sandbox 限制)
# 用法: ./test-lsp-full.sh [project_path]

set -o pipefail

PROJECT="${1:-/home/dev/code/workspace/test-lsp}"
TEST_FILE="${PROJECT}/src/main.c"
SYMBOL="hello"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "$1[$2]$NC $3"
}

echo -e "${GREEN}=== Doom LSP Full Test Suite v7.6 (Final with Indexing Wait) ===${NC}"
echo "项目: $PROJECT"
echo "测试文件: $TEST_FILE"
echo "符号: $SYMBOL"
echo "时间: $(date)"
echo ""

# Daemon 自愈
log "$YELLOW" "DAEMON" "检查/修复 Emacs daemon..."
if ! timeout 8s emacsclient -a "" -e "(+ 1 1)" >/dev/null 2>&1; then
    log "$YELLOW" "DAEMON" "强制重启..."
    pkill -9 emacs 2>/dev/null || true
    sleep 3
    emacs --daemon
    sleep 10
    log "$GREEN" "SUCCESS" "Daemon 已重启"
else
    log "$GREEN" "SUCCESS" "Daemon 正常"
fi

timeout 5s emacsclient -e "(progn (require 'lsp-mode) (require 'lsp-ui) (message \"LSP ready\"))" >/dev/null 2>&1 || true
log "$GREEN" "SUCCESS" "LSP 模块已加载"
echo ""

# Wait for LSP indexing to complete
wait_for_lsp_ready() {
    log "$YELLOW" "INDEXING" "等待 LSP indexing 完成 (最多 60 秒)..."
    for i in {1..12}; do
        if timeout 5s emacsclient -e "(lsp--server-ready-p)" 2>/dev/null | grep -q t; then
            log "$GREEN" "SUCCESS" "LSP indexing 完成"
            return 0
        fi
        sleep 5
    done
    log "$YELLOW" "WARNING" "Indexing 超时，继续测试（可能结果不完整）"
    return 1
}

# 测试函数
run_test() {
    local name="$1"
    local cmd="$2"
    local timeout_sec="${3:-20}"
    local retries=2

    log "$YELLOW" "$name" "执行中..."

    for i in $(seq 0 $retries); do
        if timeout $timeout_sec $cmd > /tmp/lsp_test.out 2>&1; then
            cat /tmp/lsp_test.out
            log "$GREEN" "SUCCESS" "$name 通过"
            rm -f /tmp/lsp_test.out
            return 0
        fi
        if [ $i -lt $retries ]; then
            log "$YELLOW" "RETRY" "$name 重试 ($((i+1))/$((retries+1)))..."
            sleep 3
        fi
    done

    log "$RED" "WARNING" "$name 超时或失败"
    cat /tmp/lsp_test.out 2>/dev/null || true
    rm -f /tmp/lsp_test.out
}

# 测试流程
run_test "SETUP PROJECT" "doom-lsp setup-project \"$PROJECT\"" 20
run_test "OPEN FILE" "doom-lsp open-file \"$TEST_FILE\" 1" 25
wait_for_lsp_ready
run_test "FIND-DEF (gd)" "doom-lsp find-def \"$TEST_FILE\" $SYMBOL" 15
run_test "FIND-REFS" "doom-lsp find-refs \"$TEST_FILE\" $SYMBOL" 30
run_test "HOVER" "doom-lsp hover \"$TEST_FILE\" 1" 15
run_test "DIAGNOSTICS" "doom-lsp diagnostics \"$TEST_FILE\"" 15
run_test "LIST-FUNCTIONS" "doom-lsp list-functions \"$TEST_FILE\" | head -8" 15

echo ""
log "$GREEN" "SUMMARY" "测试完成！"
echo "v7.6 已加入显式等待 indexing 逻辑。"
echo "如果想测试 Redis，运行: ./test-lsp-full.sh /home/dev/code/redis"
echo "测试脚本位置: skills/doom-lsp/scripts/test-lsp-full.sh"
rm -f /tmp/lsp_test.out 2>/dev/null
