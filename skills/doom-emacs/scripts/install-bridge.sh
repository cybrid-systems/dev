#!/bin/bash
# install-bridge.sh - 安装OpenClaw桥接工具

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🌉 安装OpenClaw桥接工具${NC}"
echo -e "${YELLOW}========================================${NC}"

# 检查OpenClaw
echo -e "${GREEN}🔍 检查OpenClaw环境...${NC}"
if command -v openclaw &> /dev/null; then
    OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
    echo -e "  ✅ OpenClaw已安装: $OPENCLAW_VERSION"
else
    echo -e "  ⚠️  OpenClaw未安装"
    echo -e "  ℹ️  请先安装OpenClaw:"
    echo -e "      npm install -g openclaw"
fi

# 检查Emacs环境
echo -e "${GREEN}📦 检查Emacs环境...${NC}"
if ! command -v emacs &> /dev/null; then
    echo -e "${RED}❌ Emacs未安装${NC}"
    exit 1
fi

if ! command -v emacsclient &> /dev/null; then
    echo -e "${RED}❌ emacsclient未安装${NC}"
    exit 1
fi

echo -e "  ✅ Emacs版本: $(emacs --version | head -1)"

# 检查Doom配置
echo -e "${GREEN}⚙️ 检查Doom配置...${NC}"
DOOM_CONFIG="$HOME/.config/doom/config.el"
if [ -f "$DOOM_CONFIG" ]; then
    echo -e "  ✅ Doom配置存在: $DOOM_CONFIG"
    
    # 检查gptel配置
    if grep -q "gptel" "$DOOM_CONFIG"; then
        echo -e "  ✅ gptel已配置"
    else
        echo -e "  ⚠️  gptel未配置"
        echo -e "  ℹ️  桥接工具需要gptel支持"
    fi
else
    echo -e "  ⚠️  Doom配置不存在"
fi

# 安装桥接脚本
echo -e "${GREEN}📦 安装桥接脚本...${NC}"
BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"

install_script() {
    SCRIPT="$1"
    SRC="$SCRIPT_DIR/$SCRIPT"
    DEST="$BIN_DIR/$SCRIPT"
    
    if [ -f "$SRC" ]; then
        cp "$SRC" "$DEST"
        chmod +x "$DEST"
        echo -e "  ✅ $SCRIPT"
        
        # 创建无扩展名别名
        ALIAS_NAME="${SCRIPT%.sh}"
        if [ "$SCRIPT" != "$ALIAS_NAME" ]; then
            ln -sf "$DEST" "$BIN_DIR/$ALIAS_NAME"
            echo -e "    → 别名: $ALIAS_NAME"
        fi
    else
        echo -e "  ❌ $SCRIPT (未找到)"
    fi
}

# 查找桥接相关脚本
BRIDGE_SCRIPTS=()
for script in "$SCRIPT_DIR"/*.sh; do
    if [[ "$(basename "$script")" =~ ^doom- ]] || [[ "$(basename "$script")" =~ bridge ]]; then
        BRIDGE_SCRIPTS+=("$(basename "$script")")
    fi
done

if [ ${#BRIDGE_SCRIPTS[@]} -eq 0 ]; then
    echo -e "  ⚠️  未找到桥接脚本"
    echo -e "  ℹ️  从doom-emacs-bridge技能复制脚本"
    
    # 尝试从原技能目录复制
    SOURCE_SKILL="$HOME/code/workspace/skills/doom-emacs-bridge/scripts"
    if [ -d "$SOURCE_SKILL" ]; then
        cp "$SOURCE_SKILL"/doom-*.sh "$SCRIPT_DIR/" 2>/dev/null || true
        cp "$SOURCE_SKILL"/tmux-integration.sh "$SCRIPT_DIR/" 2>/dev/null || true
        
        # 重新查找
        for script in "$SCRIPT_DIR"/*.sh; do
            if [[ "$(basename "$script")" =~ ^doom- ]] || [[ "$(basename "$script")" =~ bridge ]]; then
                BRIDGE_SCRIPTS+=("$(basename "$script")")
            fi
        done
    fi
fi

# 安装找到的脚本
for script in "${BRIDGE_SCRIPTS[@]}"; do
    install_script "$script"
done

# 创建doombridge主命令
echo -e "${GREEN}🚀 创建doombridge主命令...${NC}"
DOOMBRIDGE_MAIN="$BIN_DIR/doombridge"
cat > "$DOOMBRIDGE_MAIN" << 'EOF'
#!/bin/bash
# doombridge - OpenClaw Doom Emacs桥接主命令

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 命令映射
declare -A COMMANDS=(
    ["open-file"]="doom-open-file.sh"
    ["save-all"]="doom-save-all.sh"
    ["analyze-error"]="doom-analyze-error.sh"
    ["create-dev-session"]="doom-create-dev-session.sh"
    ["health-check"]="doom-health-check.sh"
    ["restart-daemon"]="doom-restart-daemon.sh"
    ["tmux-to-gptel"]="doom-tmux-to-gptel.sh"
    ["gptel-to-tmux"]="doom-gptel-to-tmux.sh"
)

# 查找实际脚本文件
find_script() {
    local cmd="$1"
    local script="${COMMANDS[$cmd]}"
    
    if [ -n "$script" ]; then
        # 检查多个可能的位置
        for dir in "$SCRIPT_DIR" "$HOME/bin" "/usr/local/bin"; do
            if [ -f "$dir/$script" ]; then
                echo "$dir/$script"
                return 0
            fi
        done
    fi
    
    return 1
}

# 显示帮助
show_help() {
    echo "doombridge - OpenClaw Doom Emacs桥接工具"
    echo ""
    echo "用法: doombridge <命令> [参数...]"
    echo ""
    echo "可用命令:"
    echo "  open-file <文件> [行号]     打开文件到指定行"
    echo "  save-all                    保存所有打开的文件"
    echo "  analyze-error <错误信息>    使用gptel分析编译错误"
    echo "  create-dev-session <目录>   创建tmux开发会话"
    echo "  health-check                运行健康检查"
    echo "  restart-daemon              重启Emacs daemon"
    echo "  tmux-to-gptel               复制tmux内容到gptel"
    echo "  gptel-to-tmux               发送gptel响应到tmux"
    echo "  help                        显示此帮助"
    echo ""
    echo "示例:"
    echo "  doombridge open-file ~/code/project/src/main.c 42"
    echo "  doombridge analyze-error \"编译错误信息...\""
    echo "  doombridge health-check"
}

# 主函数
main() {
    local cmd="$1"
    
    if [ -z "$cmd" ] || [ "$cmd" = "help" ] || [ "$cmd" = "--help" ] || [ "$cmd" = "-h" ]; then
        show_help
        exit 0
    fi
    
    # 查找并执行命令
    local script_path
    if script_path=$(find_script "$cmd"); then
        shift
        exec "$script_path" "$@"
    else
        echo "错误: 未知命令 '$cmd'"
        echo ""
        show_help
        exit 1
    fi
}

main "$@"
EOF

chmod +x "$DOOMBRIDGE_MAIN"
echo -e "  ✅ doombridge主命令: $DOOMBRIDGE_MAIN"

# 检查PATH
echo -e "${GREEN}🛣️ 检查PATH...${NC}"
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "  ⚠️  $BIN_DIR 不在PATH中"
    echo -e "  ℹ️  添加到 ~/.zshrc 或 ~/.bashrc:"
    echo -e "      export PATH=\"\$PATH:$BIN_DIR\""
    
    read -p "自动添加到 ~/.zshrc? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> ~/.zshrc
        echo -e "  ✅ 已添加到 ~/.zshrc"
        echo -e "  ℹ️  运行: source ~/.zshrc"
    fi
else
    echo -e "  ✅ $BIN_DIR 在PATH中"
fi

# 健康检查
echo -e "${GREEN}🧪 运行健康检查...${NC}"
if [ -f "$BIN_DIR/doom-health-check.sh" ]; then
    "$BIN_DIR/doom-health-check.sh"
elif [ -f "$BIN_DIR/doombridge" ]; then
    "$BIN_DIR/doombridge" health-check
else
    echo -e "  ⚠️  健康检查脚本未找到"
fi

# 配置OpenClaw Agent
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}🤖 配置OpenClaw Agent...${NC}"

AGENTS_MD="$HOME/code/workspace/AGENTS.md"
if [ -f "$AGENTS_MD" ]; then
    if grep -q "doombridge" "$AGENTS_MD"; then
        echo -e "  ✅ AGENTS.md已包含doombridge配置"
    else
        echo -e "  ⚠️  AGENTS.md未配置doombridge"
        echo -e "  ℹ️  添加以下内容到AGENTS.md:"
        cat << 'EOF'

## Doom Emacs工作流

### 可用命令
```bash
# 文件操作
doombridge open-file <文件> [行号]      # 打开文件
doombridge save-all                     # 保存所有文件

# 错误分析
doombridge analyze-error "错误信息"     # 使用gptel分析编译错误

# 开发环境
doombridge create-dev-session <目录>    # 创建tmux开发会话
doombridge tmux-to-gptel                # 复制tmux内容到gptel
doombridge gptel-to-tmux                # 发送gptel响应到tmux

# 系统命令
doombridge health-check                 # 运行健康检查
doombridge restart-daemon               # 重启Emacs daemon
doombridge help                         # 查看帮助
```

### 开发循环
1. **编译**: 在tmux中运行`make`
2. **分析**: 使用`doombridge analyze-error`分析错误
3. **修复**: 根据gptel建议编辑代码
4. **验证**: 重新编译，重复直到成功
EOF
    fi
else
    echo -e "  ⚠️  AGENTS.md未找到: $AGENTS_MD"
fi

# 测试桥接功能
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}🧪 测试桥接功能...${NC}"

echo -e "1. ${BLUE}测试文件打开${NC}:"
if [ -f "$BIN_DIR/doombridge" ]; then
    TEST_FILE="/tmp/test-bridge-$$.txt"
    echo "测试文件" > "$TEST_FILE"
    
    echo -e "   创建测试文件: $TEST_FILE"
    echo -e "   运行: doombridge open-file $TEST_FILE"
    
    # 注意：实际打开文件需要Emacs daemon
    echo -e "   ℹ️  此命令需要在Emacs daemon运行时工作"
    
    rm -f "$TEST_FILE"
else
    echo -e "   ⚠️  doombridge未找到"
fi

echo -e "2. ${BLUE}测试健康检查${NC}:"
if [ -f "$BIN_DIR/doombridge" ]; then
    echo -e "   运行: doombridge health-check"
    "$BIN_DIR/doombridge" health-check 2>&1 | head -10
else
    echo -e "   ⚠️  doombridge未找到"
fi

# 使用示例
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}📚 使用示例:${NC}"
echo ""
echo -e "1. ${BLUE}Redis开发工作流${NC}:"
echo -e "   cd ~/code/redis-src"
echo -e "   make 2>&1 | tee /tmp/build.log"
echo -e "   doombridge analyze-error \"\$(grep -A5 error: /tmp/build.log)\""
echo ""
echo -e "2. ${BLUE}实时错误分析${NC}:"
echo -e "   # 在tmux中编译"
echo -e "   make"
echo -e "   # 捕获错误并分析"
echo -e "   tci to-gptel -30"
echo ""
echo -e "3. ${BLUE}完整开发会话${NC}:"
echo -e "   doombridge create-dev-session ~/code/project"
echo -e "   # 在新tmux会话中开发"
echo ""
echo -e "4. ${BLUE}与OpenClaw集成${NC}:"
echo -e "   # 在OpenClaw agent中使用"
echo -e "   export PATH=\"\$PATH:\$HOME/bin\""
echo -e "   doombridge open-file ~/code/project/src/main.c"

# 故障排除
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}🔧 故障排除:${NC}"
echo ""
echo -e "1. ${BLUE}命令未找到${NC}:"
echo -e "   确保 ~/bin 在PATH中"
echo -e "   运行: source ~/.zshrc"
echo ""
echo -e "2. ${BLUE}Emacs daemon未运行${NC}:"
echo -e "   启动: emacs --daemon"
echo -e "   检查: ps aux | grep emacs"
echo ""
echo -e "3. ${BLUE}gptel未配置${NC}:"
echo -e "   配置API密钥"
echo -e "   检查: ~/.config/doom/config.el"
echo ""
echo -e "4. ${BLUE}权限问题${NC}:"
echo -e "   确保脚本可执行: chmod +x ~/bin/*"
echo ""
echo -e "5. ${BLUE}调试模式${NC}:"
echo -e "   设置: export DOOMBRIDGE_DEBUG=1"
echo -e "   查看详细输出"

echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}✅ OpenClaw桥接工具安装完成${NC}"
echo -e "现在OpenClaw agent可以直接操作你的Doom Emacs环境了！🚀"
echo -e "${BLUE}提示:${NC} 运行 'doombridge help' 查看所有可用命令。"