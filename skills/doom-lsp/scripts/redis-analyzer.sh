#!/bin/bash
# Redis 代码分析工具 - 集成到 doom-lsp skill

REDIS_DIR="${REDIS_DIR:-/home/dev/code/redis}"

# 简单日志
log() {
    echo "[$1] $2"
}

# 检查环境
check_environment() {
    if [ ! -d "$REDIS_DIR" ]; then
        log "ERROR" "Redis 目录不存在: $REDIS_DIR"
        log "INFO" "请设置 REDIS_DIR 环境变量"
        return 1
    fi
    
    if ! command -v doom-lsp >/dev/null 2>&1; then
        log "ERROR" "doom-lsp 未安装"
        log "INFO" "请先安装 doom-lsp 技能"
        return 1
    fi
    
    return 0
}

# 分析 Redis 命令
analyze_command() {
    local CMD="$1"
    local FULL_CMD="${CMD}Command"
    
    echo "🔍 分析 Redis $CMD 命令"
    echo "========================"
    
    # 1. 查找命令引用
    log "INFO" "查找命令引用: $FULL_CMD"
    local POS=$(doom-lsp find-symbol "$REDIS_DIR/src/server.c" "$FULL_CMD" 2>/dev/null | grep -o "^[0-9]*:" | cut -d: -f1)
    
    if [ -z "$POS" ] || [ "$POS" = "NOT_FOUND" ]; then
        log "WARNING" "未找到 $FULL_CMD 引用"
        
        # 尝试直接搜索
        log "INFO" "尝试直接搜索..."
        grep -n "\"$CMD\"" "$REDIS_DIR/src/server.c" | head -3
        return 1
    fi
    
    log "SUCCESS" "找到引用位置: 第 $POS 行"
    
    # 2. 打开查看引用
    doom-lsp open-file "$REDIS_DIR/src/server.c" "$POS" 1 >/dev/null 2>&1
    
    # 3. 查找实现文件
    log "INFO" "查找实现文件..."
    local IMPL_FILE=$(find "$REDIS_DIR/src" -name "*.c" -exec grep -l "void $FULL_CMD" {} \; 2>/dev/null | head -1)
    
    if [ -n "$IMPL_FILE" ]; then
        log "SUCCESS" "实现在: $IMPL_FILE"
        
        # 4. 查找实现行
        local IMPL_LINE=$(grep -n "void $FULL_CMD" "$IMPL_FILE" | head -1 | cut -d: -f1)
        if [ -n "$IMPL_LINE" ]; then
            log "INFO" "实现在第 $IMPL_LINE 行"
            doom-lsp open-file "$IMPL_FILE" "$IMPL_LINE" 1 >/dev/null 2>&1
        fi
        
        # 5. 分析函数内容
        echo ""
        echo "📋 函数分析:"
        echo "-----------"
        
        # 查看函数签名
        sed -n "${IMPL_LINE},$((IMPL_LINE+5))p" "$IMPL_FILE"
        
        # 查找关键调用
        echo ""
        echo "🔗 关键调用:"
        grep -n "GenericCommand\|Key\|dbAdd\|dictAdd" "$IMPL_FILE" | head -5
        
    else
        log "WARNING" "未找到具体实现文件"
        
        # 尝试查找通用实现
        local GEN_CMD=$(echo "$CMD" | sed 's/Command$//')
        find "$REDIS_DIR/src" -name "*.c" -exec grep -l "$GEN_CMD" {} \; 2>/dev/null | head -3
    fi
    
    echo ""
}

# 分析调用链
analyze_call_chain() {
    local FUNC="$1"
    local FILE="$2"
    
    if [ -z "$FILE" ]; then
        # 查找函数所在文件
        FILE=$(find "$REDIS_DIR/src" -name "*.c" -exec grep -l "$FUNC" {} \; 2>/dev/null | head -1)
        if [ -z "$FILE" ]; then
            log "ERROR" "未找到函数: $FUNC"
            return 1
        fi
    fi
    
    echo "🔗 分析调用链: $FUNC"
    echo "=================="
    
    # 1. 查找函数定义
    local LINE=$(grep -n "$FUNC" "$FILE" | grep -E "(^| )$FUNC\(" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        log "INFO" "函数定义在: $FILE:$LINE"
        doom-lsp open-file "$FILE" "$LINE" 1 >/dev/null 2>&1
    fi
    
    # 2. 分析函数体
    echo ""
    echo "📖 函数内容 (行 $LINE 开始):"
    echo "------------------------"
    sed -n "$LINE,$((LINE+20))p" "$FILE" | head -20
    
    # 3. 查找调用关系
    echo ""
    echo "📤 被谁调用:"
    find "$REDIS_DIR/src" -name "*.c" -exec grep -l "$FUNC" {} \; 2>/dev/null | \
        while read F; do
            grep -n "$FUNC" "$F" | head -2 | while read L; do
                echo "  $F:${L%%:*}"
            done
        done | head -10
    
    # 4. 调用了谁
    echo ""
    echo "📥 调用了谁:"
    sed -n "$LINE,$((LINE+50))p" "$FILE" | \
        grep -o "[a-zA-Z_][a-zA-Z0-9_]*(" | \
        sed 's/($//' | \
        sort -u | \
        grep -v "^$FUNC$" | \
        head -10
}

# 生成分析报告
generate_report() {
    local CMD="$1"
    local REPORT_FILE="${2:-/tmp/redis_${CMD}_analysis_$(date +%Y%m%d_%H%M%S).md}"
    
    echo "📊 生成分析报告: $REPORT_FILE"
    echo "============================="
    
    cat > "$REPORT_FILE" << EOF
# Redis $CMD 命令分析报告

生成时间: $(date)

## 命令信息
- **命令**: $CMD
- **Redis 目录**: $REDIS_DIR
- **分析工具**: doom-lsp + redis-analyzer

## 分析步骤

### 1. 命令查找
\`\`\`bash
doom-lsp find-symbol src/server.c "${CMD}Command"
\`\`\`

### 2. 实现文件
\`\`\`bash
find src -name "*.c" -exec grep -l "void ${CMD}Command" {} \;
\`\`\`

### 3. 关键调用
EOF
    
    # 查找实现文件
    local IMPL_FILE=$(find "$REDIS_DIR/src" -name "*.c" -exec grep -l "void ${CMD}Command" {} \; 2>/dev/null | head -1)
    
    if [ -n "$IMPL_FILE" ]; then
        local IMPL_LINE=$(grep -n "void ${CMD}Command" "$IMPL_FILE" | head -1 | cut -d: -f1)
        
        cat >> "$REPORT_FILE" << EOF

在文件 \`$(basename "$IMPL_FILE")\` 第 $IMPL_LINE 行:

\`\`\`c
$(sed -n "$IMPL_LINE,$((IMPL_LINE+10))p" "$IMPL_FILE")
\`\`\`

### 4. 调用链分析
\`\`\`
客户端请求 → processCommand() → ${CMD}Command() → ...
\`\`\`
EOF
    fi
    
    cat >> "$REPORT_FILE" << EOF

## 相关文件
1. \`src/server.c\` - 命令表注册
2. \`$(basename "${IMPL_FILE:-未知}")\` - 命令实现
3. \`src/db.c\` - 数据库操作
4. \`src/dict.c\` - 哈希表实现

## 性能考虑
- 时间复杂度: O(1) 平均
- 内存管理: 引用计数 + 编码优化
- 并发安全: 单线程模型

## 下一步
1. 深入分析内存分配
2. 研究过期键处理
3. 分析集群模式支持
4. 性能测试和优化

---
*报告由 OpenClaw doom-lsp skill 自动生成*
EOF
    
    log "SUCCESS" "报告已生成: $REPORT_FILE"
    echo "文件内容:"
    cat "$REPORT_FILE"
}

# 批量分析命令
batch_analyze() {
    local COMMANDS=("${@:-set get incr decr lpush rpush}")
    
    echo "🚀 批量分析 Redis 命令"
    echo "====================="
    
    for CMD in "${COMMANDS[@]}"; do
        echo ""
        echo "▶️  分析: $CMD"
        echo "-----------"
        analyze_command "$CMD"
    done
    
    echo ""
    echo "✅ 批量分析完成"
    echo "共分析 ${#COMMANDS[@]} 个命令"
}

# 交互式分析
interactive_analysis() {
    echo "💬 Redis 交互式分析工具"
    echo "======================="
    echo "可用命令:"
    echo "  analyze <command>    - 分析指定命令"
    echo "  chain <function>     - 分析调用链"
    echo "  report <command>     - 生成分析报告"
    echo "  batch                - 批量分析常用命令"
    echo "  quit                 - 退出"
    echo ""
    
    while true; do
        read -p "redis-analyzer> " INPUT
        case $INPUT in
            analyze\ *)
                CMD=${INPUT#analyze }
                analyze_command "$CMD"
                ;;
            chain\ *)
                FUNC=${INPUT#chain }
                analyze_call_chain "$FUNC"
                ;;
            report\ *)
                CMD=${INPUT#report }
                generate_report "$CMD"
                ;;
            batch)
                batch_analyze
                ;;
            quit|exit)
                echo "再见！"
                break
                ;;
            "")
                continue
                ;;
            *)
                echo "未知命令: $INPUT"
                echo "输入 'help' 查看帮助"
                ;;
        esac
    done
}

# 主函数
main() {
    if ! check_environment; then
        exit 1
    fi
    
    # 设置项目
    echo "🔧 设置 Redis 项目环境..."
    doom-lsp setup-project "$REDIS_DIR" >/dev/null 2>&1
    
    case "$1" in
        analyze)
            analyze_command "$2"
            ;;
        chain)
            analyze_call_chain "$2" "$3"
            ;;
        report)
            generate_report "$2" "$3"
            ;;
        batch)
            shift
            batch_analyze "$@"
            ;;
        interactive|"")
            interactive_analysis
            ;;
        help)
            echo "用法: redis-analyzer [命令] [参数]"
            echo ""
            echo "命令:"
            echo "  analyze <command>   分析 Redis 命令"
            echo "  chain <function>    分析函数调用链"
            echo "  report <command>    生成分析报告"
            echo "  batch [commands...] 批量分析命令"
            echo "  interactive         交互式分析模式"
            echo "  help                显示帮助"
            echo ""
            echo "示例:"
            echo "  redis-analyzer analyze set"
            echo "  redis-analyzer chain dictAdd"
            echo "  redis-analyzer batch set get incr"
            ;;
        *)
            echo "未知命令: $1"
            echo "使用 'redis-analyzer help' 查看帮助"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"