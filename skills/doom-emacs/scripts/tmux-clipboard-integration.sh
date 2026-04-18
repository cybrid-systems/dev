#!/bin/bash
# tmux-clipboard-integration.sh - 无头环境下的tmux剪贴板集成

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查tmux
check_tmux() {
    if ! command -v tmux >/dev/null 2>&1; then
        echo -e "${RED}❌ tmux未安装${NC}"
        return 1
    fi
    
    if ! tmux info >/dev/null 2>&1; then
        echo -e "${RED}❌ tmux服务器未运行${NC}"
        return 1
    fi
    
    return 0
}

# 1. 从tmux复制到临时文件（无剪贴板方案）
tmux_copy_to_temp() {
    local lines="${1:--50}"  # 默认捕获50行
    local temp_file="/tmp/tmux-clipboard-$(date +%s).txt"
    
    check_tmux || return 1
    
    echo -e "${GREEN}📋 捕获tmux内容到临时文件...${NC}"
    
    # 捕获tmux窗格内容
    tmux capture-pane -p -S "$lines" > "$temp_file"
    
    local line_count=$(wc -l < "$temp_file")
    local char_count=$(wc -c < "$temp_file")
    
    echo -e "  文件: ${BLUE}$temp_file${NC}"
    echo -e "  行数: ${BLUE}$line_count${NC}"
    echo -e "  字符: ${BLUE}$char_count${NC}"
    
    # 显示预览
    echo -e "${GREEN}📄 预览（前10行）:${NC}"
    head -10 "$temp_file" | sed 's/^/  /'
    
    echo "$temp_file"
}

# 2. 从tmux复制并发送到gptel
tmux_to_gptel() {
    local lines="${1:--50}"
    
    check_tmux || return 1
    
    echo -e "${GREEN}🤖 捕获tmux内容并发送到gptel...${NC}"
    
    # 捕获内容到临时文件
    local temp_file=$(tmux_copy_to_temp "$lines")
    
    if [ -z "$temp_file" ] || [ ! -f "$temp_file" ]; then
        echo -e "${RED}❌ 捕获失败${NC}"
        return 1
    fi
    
    # 读取内容
    local content=$(cat "$temp_file")
    
    # 发送到gptel（通过doombridge）
    if command -v doombridge >/dev/null 2>&1; then
        echo -e "${BLUE}发送到gptel分析...${NC}"
        doombridge analyze-error "$content"
    else
        echo -e "${YELLOW}⚠️  doombridge未找到，直接显示内容:${NC}"
        echo "$content" | head -20
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
}

# 3. 从文件复制到tmux（粘贴）
file_to_tmux() {
    local file_path="$1"
    
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        echo -e "${RED}❌ 需要有效的文件路径${NC}"
        echo "用法: file_to_tmux /path/to/file.txt"
        return 1
    fi
    
    check_tmux || return 1
    
    echo -e "${GREEN}📤 发送文件内容到tmux...${NC}"
    
    local line_count=$(wc -l < "$file_path")
    echo -e "  文件: ${BLUE}$file_path${NC}"
    echo -e "  行数: ${BLUE}$line_count${NC}"
    
    # 读取文件并发送到tmux
    while IFS= read -r line; do
        # 转义特殊字符
        line=$(echo "$line" | sed "s/'/'\\\\''/g")
        tmux send-keys -t "$TMUX_TARGET" "$line" C-m
        sleep 0.05  # 避免发送过快
    done < "$file_path"
    
    echo -e "${GREEN}✅ 文件内容已发送到tmux${NC}"
}

# 4. 创建完整的开发工作流
dev_workflow() {
    local project_dir="${1:-$(pwd)}"
    local session_name="dev-$(basename "$project_dir")"
    
    echo -e "${BLUE}🚀 启动完整开发工作流${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # 步骤1: 创建tmux开发会话
    echo -e "${GREEN}1. 创建tmux开发会话...${NC}"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo -e "  会话已存在: $session_name"
    else
        tmux new -d -s "$session_name" -n "editor" -c "$project_dir"
        tmux new-window -t "$session_name" -n "shell" -c "$project_dir"
        echo -e "  创建会话: $session_name"
    fi
    
    # 步骤2: 编译项目
    echo -e "${GREEN}2. 编译项目...${NC}"
    cd "$project_dir" || return 1
    
    if [ -f "Makefile" ] || [ -f "makefile" ]; then
        # 在tmux中编译
        tmux send-keys -t "$session_name":shell "make clean" C-m
        sleep 1
        tmux send-keys -t "$session_name":shell "make 2>&1 | tee /tmp/build-output.txt" C-m
        sleep 2
        
        # 捕获编译输出
        local temp_file=$(tmux_copy_to_temp -100)
        
        # 检查是否有错误
        if grep -q "error:" "$temp_file"; then
            echo -e "  ❌ 编译失败，发现错误"
            echo -e "${GREEN}3. 分析编译错误...${NC}"
            tmux_to_gptel -50
        else
            echo -e "  ✅ 编译成功"
        fi
        
        rm -f "$temp_file"
    else
        echo -e "${YELLOW}⚠️  未找到Makefile，跳过编译${NC}"
    fi
    
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}🎉 开发工作流完成${NC}"
    echo -e "使用: tmux attach -t $session_name"
}

# 5. 实时监控tmux输出
monitor_tmux() {
    local interval="${1:-5}"  # 默认5秒间隔
    
    check_tmux || return 1
    
    echo -e "${GREEN}👁️  实时监控tmux输出...${NC}"
    echo -e "  按Ctrl+C停止监控"
    echo -e "  监控间隔: ${BLUE}${interval}秒${NC}"
    
    local last_content=""
    local temp_file="/tmp/tmux-monitor-$(date +%s).txt"
    
    trap 'echo -e "\n${YELLOW}🛑 停止监控${NC}"; rm -f "$temp_file"; exit 0' INT
    
    while true; do
        # 捕获当前内容
        tmux capture-pane -p -S -100 > "$temp_file" 2>/dev/null
        
        # 计算哈希来检测变化
        local current_hash=$(md5sum "$temp_file" 2>/dev/null | cut -d' ' -f1)
        local last_hash=$(echo "$last_content" | md5sum 2>/dev/null | cut -d' ' -f1)
        
        if [ "$current_hash" != "$last_hash" ]; then
            echo -e "\n${BLUE}🔄 检测到变化 ($(date +%H:%M:%S))${NC}"
            
            # 显示最后几行新内容
            local new_lines=$(tail -5 "$temp_file")
            echo "$new_lines" | sed 's/^/  /'
            
            # 检查是否有错误
            if echo "$new_lines" | grep -q "error:"; then
                echo -e "${YELLOW}⚠️  检测到错误，准备分析...${NC}"
                sleep 2
                tmux_to_gptel -20
            fi
            
            last_content=$(cat "$temp_file")
        fi
        
        sleep "$interval"
    done
}

# 主函数
main() {
    case "${1:-help}" in
        copy)
            tmux_copy_to_temp "${2:--50}"
            ;;
        to-gptel)
            tmux_to_gptel "${2:--50}"
            ;;
        paste)
            file_to_tmux "$2"
            ;;
        workflow)
            dev_workflow "$2"
            ;;
        monitor)
            monitor_tmux "$2"
            ;;
        help|--help|-h)
            cat << EOF
${BLUE}tmux剪贴板集成工具（无头环境）${NC}
${YELLOW}========================================${NC}

${GREEN}命令:${NC}
  copy [行数]          捕获tmux内容到临时文件
  to-gptel [行数]     捕获tmux内容并发送到gptel
  paste <文件>        发送文件内容到tmux
  workflow [目录]     完整开发工作流
  monitor [间隔]      实时监控tmux输出
  help                显示此帮助

${YELLOW}环境变量:${NC}
  TMUX_TARGET         目标tmux会话（默认: 当前会话）

${YELLOW}示例:${NC}
  # 捕获tmux错误并分析
  ./tmux-clipboard-integration.sh to-gptel -100
  
  # 创建Redis开发工作流
  ./tmux-clipboard-integration.sh workflow ~/code/redis-src
  
  # 实时监控编译输出
  ./tmux-clipboard-integration.sh monitor 3
  
  # 复制tmux内容到文件
  ./tmux-clipboard-integration.sh copy -30

${YELLOW}========================================${NC}
EOF
            ;;
        *)
            echo -e "${RED}❌ 未知命令: $1${NC}"
            echo "使用: ./tmux-clipboard-integration.sh help"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"