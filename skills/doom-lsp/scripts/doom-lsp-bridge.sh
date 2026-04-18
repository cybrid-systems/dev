#!/bin/bash
# doom-lsp-bridge-simple.sh - 极简稳定版

EMACSCLIENT="emacsclient"

# 简单日志
log() {
    echo "[$1] $2"
}

case "$1" in
    health-check)
        # 检查 Emacs daemon 是否响应（带超时）
        if timeout 1s $EMACSCLIENT -e "(message \"ok\")" >/dev/null 2>&1; then
            log "INFO" "Emacs daemon 正在运行"
            # 检查 LSP 模块（带超时）
            LSP_STATUS=$(timeout 1s $EMACSCLIENT -e "(if (boundp 'lsp-mode) \"loaded\" \"not-loaded\")" 2>/dev/null)
            if [ "$LSP_STATUS" = "\"loaded\"" ]; then
                log "SUCCESS" "LSP 模块已加载"
            else
                log "WARNING" "LSP 模块未加载"
            fi
        else
            log "ERROR" "Emacs daemon 未运行或未响应"
            log "INFO" "请运行: emacs --daemon"
        fi
        ;;
    
    open-file)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp open-file <文件> [行] [列]"
            exit 1
        fi
        
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-1}"
        
        if [ ! -f "$FILE" ]; then
            log "ERROR" "文件不存在: $FILE"
            exit 1
        fi
        
        log "INFO" "打开文件: $FILE (行: $LINE, 列: $COL)"
        
        # 查找 compile_commands.json
        COMPILE_COMMANDS=""
        DIR=$(dirname "$FILE")
        while [ "$DIR" != "/" ]; do
            if [ -f "$DIR/compile_commands.json" ]; then
                COMPILE_COMMANDS="$DIR/compile_commands.json"
                log "INFO" "找到编译数据库: $COMPILE_COMMANDS"
                break
            fi
            DIR=$(dirname "$DIR")
        done
        
        # 打开文件并设置 LSP
        if [ -n "$COMPILE_COMMANDS" ]; then
            # 有编译数据库的情况
            $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (setq-local lsp-clients-clangd-args (list \"--compile-commands-dir=\" (file-name-directory \"$COMPILE_COMMANDS\"))) (lsp))" >/dev/null 2>&1
        else
            # 没有编译数据库的情况
            log "WARNING" "未找到 compile_commands.json，LSP 功能可能受限"
            $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp))" >/dev/null 2>&1
        fi
        
        log "SUCCESS" "文件已打开"
        ;;
    
    find-symbol)
        if [ $# -lt 3 ]; then
            log "ERROR" "用法: doom-lsp find-symbol <文件> <符号>"
            exit 1
        fi
        
        FILE="$2"
        SYMBOL="$3"
        
        if [ ! -f "$FILE" ]; then
            log "ERROR" "文件不存在: $FILE"
            exit 1
        fi
        
        log "INFO" "查找符号: $SYMBOL"
        
        # 使用 grep 查找第一个出现的位置
        LINE_INFO=$(grep -n -m1 "$SYMBOL" "$FILE" 2>/dev/null | head -1)
        if [ -z "$LINE_INFO" ]; then
            log "WARNING" "未找到符号: $SYMBOL"
            echo "NOT_FOUND"
            exit 0
        fi
        
        LINE=$(echo "$LINE_INFO" | cut -d: -f1)
        # 简单估算列位置（第一个字符）
        COL=1
        echo "$LINE:$COL"
        log "SUCCESS" "找到符号位置: $LINE:$COL"
        ;;
    
    find-def)
        if [ $# -lt 3 ]; then
            log "ERROR" "用法: doom-lsp find-def <文件> <符号>"
            exit 1
        fi
        
        FILE="$2"
        SYMBOL="$3"
        
        if [ ! -f "$FILE" ]; then
            log "ERROR" "文件不存在: $FILE"
            exit 1
        fi
        
        # 检查符号是否存在
        if ! grep -q "$SYMBOL" "$FILE" 2>/dev/null; then
            log "ERROR" "符号 '$SYMBOL' 不存在"
            exit 1
        fi
        
        log "INFO" "跳转到定义: $SYMBOL"
        
        # 简单实现：打开文件并尝试跳转
        $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (lsp))" >/dev/null 2>&1
        sleep 0.2
        
        timeout 3s $EMACSCLIENT -e "(progn (find-file \"$FILE\") (search-forward \"$SYMBOL\" nil t) (lsp-find-definition))" >/dev/null 2>&1
        
        if [ $? -eq 124 ]; then
            log "WARNING" "操作超时"
        else
            log "SUCCESS" "已尝试跳转"
        fi
        ;;
    
    list-functions)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp list-functions <文件>"
            exit 1
        fi
        
        FILE="$2"
        
        if [ ! -f "$FILE" ]; then
            log "ERROR" "文件不存在: $FILE"
            exit 1
        fi
        
        log "INFO" "列出函数: $FILE"
        
        # 简单提取函数定义
        if [[ "$FILE" == *.c ]] || [[ "$FILE" == *.cpp ]] || [[ "$FILE" == *.h ]]; then
            grep -n "^[a-zA-Z_].*[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$FILE" | head -15
        elif [[ "$FILE" == *.py ]]; then
            grep -n "^def " "$FILE" | head -15
        else
            log "INFO" "显示文件前15行"
            head -15 "$FILE"
        fi
        ;;
    
    setup-project)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp setup-project <项目目录>"
            exit 1
        fi
        
        PROJECT_DIR="$2"
        if [ ! -d "$PROJECT_DIR" ]; then
            log "ERROR" "项目目录不存在: $PROJECT_DIR"
            exit 1
        fi
        
        log "INFO" "设置项目: $PROJECT_DIR"
        
        # 检查 compile_commands.json
        if [ -f "$PROJECT_DIR/compile_commands.json" ]; then
            log "SUCCESS" "找到 compile_commands.json"
            log "INFO" "编译数据库已就绪，LSP 将能正确理解代码"
            echo "COMPILE_COMMANDS_FOUND:$PROJECT_DIR/compile_commands.json"
        else
            log "WARNING" "未找到 compile_commands.json"
            log "INFO" "LSP 功能可能受限，建议生成编译数据库:"
            echo "1. 使用 bear 工具: bear -- make"
            echo "2. 使用 CMake: cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ."
            echo "3. 使用 compiledb: compiledb make"
            echo "NOT_FOUND"
        fi
        ;;
    
    check-compile-db)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp check-compile-db <文件或目录>"
            exit 1
        fi
        
        TARGET="$2"
        if [ -f "$TARGET" ]; then
            # 是文件，查找其目录中的 compile_commands.json
            DIR=$(dirname "$TARGET")
        else
            # 是目录
            DIR="$TARGET"
        fi
        
        log "INFO" "检查编译数据库: $DIR"
        
        FOUND=""
        while [ "$DIR" != "/" ]; do
            if [ -f "$DIR/compile_commands.json" ]; then
                FOUND="$DIR/compile_commands.json"
                log "SUCCESS" "找到编译数据库: $FOUND"
                echo "$FOUND"
                exit 0
            fi
            DIR=$(dirname "$DIR")
        done
        
        log "WARNING" "未找到 compile_commands.json"
        echo "NOT_FOUND"
        ;;
    
    help)
        echo "Doom LSP Bridge - 极简稳定版（带编译数据库支持）"
        echo ""
        echo "可用命令:"
        echo "  health-check              - 检查环境"
        echo "  setup-project <目录>       - 设置项目并检查编译数据库"
        echo "  check-compile-db <路径>    - 检查编译数据库"
        echo "  open-file <文件> [行] [列] - 打开文件（自动查找编译数据库）"
        echo "  find-symbol <文件> <符号>  - 查找符号位置"
        echo "  find-def <文件> <符号>     - 跳转到定义"
        echo "  list-functions <文件>      - 列出函数"
        echo ""
        echo "关键步骤:"
        echo "  1. 生成 compile_commands.json (bear -- make 等)"
        echo "  2. doom-lsp setup-project <项目目录>"
        echo "  3. doom-lsp open-file <文件>"
        echo ""
        echo "示例:"
        echo "  doom-lsp setup-project ~/code/redis"
        echo "  doom-lsp open-file src/server.c 100 1"
        echo "  doom-lsp find-def src/server.c \"initServer\""
        ;;
    
    *)
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac