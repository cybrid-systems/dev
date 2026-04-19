#!/bin/bash
# doom-lsp-simple-working.sh - 简单能工作的版本
# 专注于解决实际问题

EMACSCLIENT="emacsclient -a ''"

# 简单输出处理
clean_output() {
    sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g'
}

case "$1" in
    # 只实现最核心的功能
    find-refs)
        if [ $# -lt 3 ]; then
            echo "用法: doom-lsp find-refs <文件> <符号>"
            echo "示例: doom-lsp find-refs ~/code/redis/src/dict.c dictAdd"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        
        echo "正在查找 $SYMBOL 的引用..."
        echo "文件: $(basename "$FILE")"
        echo ""
        
        # 使用最简单的方法：直接触发，不等待
        $EMACSCLIENT -n -e "(progn
          (find-file \"$FILE\")
          (lsp)
          (goto-char (point-min))
          (when (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
            (lsp-find-references)
            (message \"引用查找已触发\")))" >/dev/null 2>&1 &
        
        echo "✅ 已触发引用查找"
        echo ""
        echo "查看结果:"
        echo "1. 切换到 Emacs"
        echo "2. 按 C-x b 输入 *xref*"
        echo "3. 查看引用列表"
        echo ""
        echo "注意: 大项目可能需要时间索引"
        ;;
    
    # 专门测试小项目
    test-small)
        echo "测试小项目..."
        $0 find-refs /home/dev/code/workspace/test-lsp/src/main.c hello
        ;;
    
    # 专门测试 Redis，带超时
    test-redis)
        echo "测试 Redis 项目（带超时）..."
        echo "注意: Redis 很大，首次需要索引时间"
        echo ""
        
        timeout 10 $0 find-refs /home/dev/code/redis/src/dict.c dictAdd
        if [ $? -eq 124 ]; then
            echo ""
            echo "⚠️  超时 - Redis 可能需要更多时间索引"
            echo "建议先运行: doom-lsp setup-project ~/code/redis"
            echo "然后等待 30-60 秒让 clangd 索引"
        fi
        ;;
    
    setup-project)
        if [ $# -lt 2 ]; then
            echo "用法: doom-lsp setup-project <项目路径>"
            exit 1
        fi
        echo "设置项目: $2"
        if [ -f "$2/compile_commands.json" ]; then
            echo "✅ 找到 compile_commands.json"
            echo "文件: $2/compile_commands.json"
        else
            echo "⚠️  未找到 compile_commands.json"
            echo "LSP 可能需要此文件"
        fi
        ;;
    
    status)
        echo "检查状态..."
        echo ""
        
        # 检查 Emacs
        if $EMACSCLIENT -e "(+ 1 1)" >/dev/null 2>&1; then
            echo "✅ Emacs daemon: 运行中"
        else
            echo "❌ Emacs daemon: 未运行"
        fi
        
        # 检查 clangd
        if ps aux | grep -q "[c]langd"; then
            echo "✅ clangd: 运行中"
        else
            echo "❌ clangd: 未运行"
        fi
        
        # 检查 Redis 项目
        if [ -f "/home/dev/code/redis/compile_commands.json" ]; then
            echo "✅ Redis 项目: 已配置"
        else
            echo "❌ Redis 项目: 未配置"
        fi
        ;;
    
    help)
        echo "doom-lsp - 简单能工作的版本"
        echo ""
        echo "核心问题: Redis 项目太大，clangd 需要时间索引"
        echo ""
        echo "用法:"
        echo "  doom-lsp find-refs <文件> <符号>   # 触发引用查找"
        echo "  doom-lsp setup-project <路径>      # 设置项目"
        echo "  doom-lsp status                    # 检查状态"
        echo "  doom-lsp test-small               # 测试小项目"
        echo "  doom-lsp test-redis               # 测试 Redis"
        echo ""
        echo "对于 Redis 的建议:"
        echo "1. 先运行: doom-lsp setup-project ~/code/redis"
        echo "2. 等待 30-60 秒让 clangd 索引"
        echo "3. 再运行: doom-lsp find-refs ~/code/redis/src/dict.c dictAdd"
        echo ""
        echo "结果在 Emacs 的 *xref* buffer 中查看"
        ;;
    
    *)
        echo "未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        ;;
esac
