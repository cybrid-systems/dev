#!/bin/bash
# tmux-integration.sh - 增强的tmux集成，无需X11剪贴板

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

# 1. 从tmux复制到文件（无剪贴板）
tmux_copy_to_file() {
    local output_file="${1:-/tmp/tmux-capture.txt}"
    
    check_tmux || return 1
    
    echo -e "${GREEN}📋 捕获tmux内容到文件: $output_file${NC}"
    
    # 捕获当前窗格内容
    tmux capture-pane -p -S -1000 > "$output_file"
    
    local line_count=$(wc -l < "$output_file")
    echo -e "  捕获了 $line_count 行内容"
    
    # 显示前几行
    echo -e "${BLUE}预览（前5行）:${NC}"
    head -5 "$output_file"
    
    echo -e "${GREEN}✅ 内容已保存到: $output_file${NC}"
    echo "$output_file"
}

# 2. 从tmux复制到gptel（直接）
tmux_to_gptel() {
    check_tmux || return 1
    
    echo -e "${GREEN}🤖 捕获tmux内容并发送到gptel...${NC}"
    
    # 捕获内容
    local tmux_content=$(tmux capture-pane -p -S -1000)
    
    if [ -z "$tmux_content" ]; then
        echo -e "${YELLOW}⚠️  tmux内容为空${NC}"
        return 0
    fi
    
    # 统计信息
    local line_count=$(echo "$tmux_content" | wc -l)
    local char_count=$(echo "$tmux_content" | wc -c)
    echo -e "  捕获了 $line_count 行，$char_count 字符"
    
    # 发送到gptel（通过doombridge）
    if command -v doombridge >/dev/null 2>&1; then
        echo -e "${BLUE}发送到gptel...${NC}"
        doombridge analyze-error "$tmux_content"
    else
        echo -e "${YELLOW}⚠️  doombridge未找到，直接显示内容:${NC}"
        echo "$tmux_content" | head -20
    fi
}

# 3. 从gptel复制到tmux（通过粘贴）
gptel_to_tmux() {
    local text="$1"
    
    if [ -z "$text" ]; then
        # 尝试从文件读取
        local gptel_file="/tmp/gptel-response.txt"
        if [ -f "$gptel_file" ]; then
            text=$(cat "$gptel_file")
            echo -e "${GREEN}📄 从文件读取gptel响应${NC}"
        else
            echo -e "${RED}❌ 需要文本内容或gptel响应文件${NC}"
            echo "用法: gptel_to_tmux \"文本\""
            echo "或: echo '响应' > /tmp/gptel-response.txt && gptel_to_tmux"
            return 1
        fi
    fi
    
    check_tmux || return 1
    
    echo -e "${GREEN}📤 发送文本到tmux...${NC}"
    
    # 分割文本为行
    local line_count=$(echo "$text" | wc -l)
    echo -e "  发送 $line_count 行文本"
    
    # 发送到tmux当前窗格
    echo "$text" | while IFS= read -r line; do
        # 转义特殊字符
        line=$(echo "$line" | sed 's/"/\\"/g')
        tmux send-keys "$line" C-m
        sleep 0.05  # 避免发送过快
    done
    
    echo -e "${GREEN}✅ 文本已发送到tmux${NC}"
}

# 4. 保存gptel响应到文件（供后续使用）
save_gptel_response() {
    local response="$1"
    local output_file="${2:-/tmp/gptel-response.txt}"
    
    if [ -z "$response" ]; then
        echo -e "${RED}❌ 需要响应内容${NC}"
        return 1
    fi
    
    echo "$response" > "$output_file"
    echo -e "${GREEN}💾 gptel响应已保存到: $output_file${NC}"
    echo "$output_file"
}

# 5. 完整的开发工作流
dev_workflow() {
    local project_dir="${1:-$(pwd)}"
    
    echo -e "${BLUE}🚀 启动完整开发工作流${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # 步骤1: 创建开发会话
    echo -e "${GREEN}1. 创建开发会话...${NC}"
    if command -v doombridge >/dev/null 2>&1; then
        doombridge create-dev-session "$project_dir"
    else
        echo -e "${YELLOW}⚠️  doombridge未找到，跳过${NC}"
    fi
    
    # 步骤2: 编译项目
    echo -e "${GREEN}2. 编译项目...${NC}"
    cd "$project_dir" || return 1
    
    if [ -f "Makefile" ] || [ -f "makefile" ]; then
        make clean >/dev/null 2>&1
        make_output=$(make 2>&1)
        
        if [ $? -eq 0 ]; then
            echo -e "  ✅ 编译成功"
        else
            echo -e "  ❌ 编译失败"
            echo -e "${BLUE}3. 分析编译错误...${NC}"
            tmux_to_gptel
        fi
    else
        echo -e "${YELLOW}⚠️  未找到Makefile，跳过编译${NC}"
    fi
    
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}🎉 开发工作流完成${NC}"
}

# 主函数
main() {
    case "${1:-help}" in
        copy-to-file)
            tmux_copy_to_file "$2"
            ;;
        to-gptel)
            tmux_to_gptel
            ;;
        from-gptel)
            gptel_to_tmux "$2"
            ;;
        save-response)
            save_gptel_response "$2" "$3"
            ;;
        workflow)
            dev_workflow "$2"
            ;;
        help|--help|-h)
            cat << EOF
${BLUE}tmux集成工具${NC}
${YELLOW}========================================${NC}

${GREEN}命令:${NC}
  copy-to-file [文件]     捕获tmux内容到文件
  to-gptel               捕获tmux内容并发送到gptel
  from-gptel [文本]      发送文本到tmux
  save-response [文本] [文件] 保存gptel响应
  workflow [目录]        完整开发工作流
  help                   显示此帮助

${YELLOW}示例:${NC}
  # 捕获tmux错误并分析
  ./tmux-integration.sh to-gptel
  
  # 保存gptel响应
  echo "修复方案" | ./tmux-integration.sh save-response
  
  # 发送修复到tmux
  ./tmux-integration.sh from-gptel
  
  # 完整工作流
  ./tmux-integration.sh workflow ~/code/redis-src

${YELLOW}========================================${NC}
EOF
            ;;
        *)
            echo -e "${RED}❌ 未知命令: $1${NC}"
            echo "使用: ./tmux-integration.sh help"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"