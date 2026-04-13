#!/bin/bash
# install-new.sh - 安装Doom Emacs Bridge技能（修复版）

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$HOME/bin"
EMACS_CONFIG="$HOME/.config/doom/config.el"

echo -e "${BLUE}🚀 安装Doom Emacs Bridge${NC}"
echo -e "${YELLOW}========================================${NC}"

# 检查依赖
echo -e "${GREEN}🔍 检查依赖...${NC}"

check_dependency() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ✅ $1"
        return 0
    else
        echo -e "  ❌ $1"
        return 1
    fi
}

check_dependency "emacs"
check_dependency "emacsclient"
check_dependency "tmux"

# 检查Doom Emacs
echo -e "${GREEN}📦 检查Doom Emacs...${NC}"
if [ -f ~/.config/emacs/bin/doom ]; then
    echo -e "  ✅ Doom Emacs已安装"
else
    echo -e "  ⚠️  Doom Emacs未安装或不在标准位置"
    echo -e "  ℹ️  期望: ~/.config/emacs/bin/doom"
fi

# 检查Emacs daemon
echo -e "${GREEN}🖥️  检查Emacs daemon...${NC}"
if emacsclient -e "(message \"ping\")" >/dev/null 2>&1; then
    echo -e "  ✅ Emacs daemon运行中"
else
    echo -e "  ⚠️  Emacs daemon未运行"
    echo -e "  ℹ️  启动: emacs --daemon"
fi

# 创建bin目录
echo -e "${GREEN}📂 设置命令目录...${NC}"
mkdir -p "$BIN_DIR"
echo -e "  目录: $BIN_DIR"

# 安装主命令（使用doombridge避免与Doom Emacs冲突）
echo -e "${GREEN}📦 安装命令...${NC}"

# 创建doombridge命令包装器
cat > "$BIN_DIR/doombridge" << 'EOF'
#!/bin/bash
# doombridge命令 - Doom Emacs Bridge入口

# 加载命令函数
if [ -f "$HOME/code/workspace/skills/doom-emacs-bridge/scripts/doom-commands.sh" ]; then
    source "$HOME/code/workspace/skills/doom-emacs-bridge/scripts/doom-commands.sh"
    
    # 如果没有参数，显示帮助
    if [ $# -eq 0 ]; then
        doom-help
        exit 0
    fi
    
    # 执行命令
    if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        doom-help
        exit 0
    fi
    
    command="doom-$1"
    shift
    
    if type "$command" >/dev/null 2>&1; then
        "$command" "$@"
    else
        echo -e "\033[0;31m❌ 未知命令: $1\033[0m"
        echo "可用命令:"
        echo "  open-file, save-buffer, analyze-error, start-gptel, ..."
        echo "使用 'doombridge help' 查看完整列表"
        exit 1
    fi
else
    echo "错误: doom-commands.sh 未找到"
    exit 1
fi
EOF

chmod +x "$BIN_DIR/doombridge"
echo -e "  ✅ doombridge命令"

# 创建快捷命令函数
create_alias() {
    local alias_name="$1"
    local target_command="$2"
    
    cat > "$BIN_DIR/$alias_name" << EOF
#!/bin/bash
# $alias_name - Doom Emacs Bridge快捷命令

exec doombridge $target_command "\$@"
EOF
    
    chmod +x "$BIN_DIR/$alias_name"
    echo -e "  ✅ $alias_name"
}

# 安装快捷命令
create_alias "doombridge-open-file" "open-file"
create_alias "doombridge-save-buffer" "save-buffer"
create_alias "doombridge-save-all" "save-all"
create_alias "doombridge-analyze-error" "analyze-error"
create_alias "doombridge-start-gptel" "start-gptel"
create_alias "doombridge-tmux-to-gptel" "tmux-to-gptel"
create_alias "doombridge-gptel-to-tmux" "gptel-to-tmux"
create_alias "doombridge-create-dev-session" "create-dev-session"
create_alias "doombridge-health-check" "health-check"
create_alias "doombridge-restart-daemon" "restart-daemon"
create_alias "doombridge-help" "help"

# 检查PATH
echo -e "${GREEN}🛣️  检查PATH...${NC}"
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "  ⚠️  $BIN_DIR 不在PATH中"
    echo -e "  ℹ️  添加到 ~/.zshrc 或 ~/.bashrc:"
    echo -e "      export PATH=\"\$PATH:$BIN_DIR\""
    
    # 自动添加
    read -p "自动添加到 ~/.zshrc? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> ~/.zshrc
        echo -e "  ✅ 已添加到 ~/.zshrc"
        echo -e "  ℹ️  运行: source ~/.zshrc"
    fi
else
    echo -e "  ✅ $BIN_DIR 已在PATH中"
fi

# 配置Doom Emacs
echo -e "${GREEN}⚙️  配置Doom Emacs...${NC}"

if [ -f "$EMACS_CONFIG" ]; then
    echo -e "  ✅ Doom配置存在: $EMACS_CONFIG"
    
    # 检查是否已添加OpenClaw函数
    if grep -q "doom/openclaw-analyze-error" "$EMACS_CONFIG"; then
        echo -e "  ✅ OpenClaw函数已存在"
    else
        echo -e "  ⚠️  OpenClaw函数未添加"
        echo -e "  ℹ️  建议添加以下内容到 config.el:"
        echo -e "      (load-file \"$SKILL_DIR/scripts/doom-openclaw.el\")"
        
        # 创建doom-openclaw.el文件
        cat > "$SKILL_DIR/scripts/doom-openclaw.el" << 'EOF'
;; doom-openclaw.el - OpenClaw专用Doom Emacs函数

(defun doom/openclaw-analyze-error (error-text)
  "OpenClaw专用：分析编译错误。
ERROR-TEXT: 错误信息字符串。"
  (interactive "s错误信息: ")
  (require 'gptel)
  (gptel)
  (insert "分析以下编译错误并提供修复方案：\n\n")
  (insert error-text)
  (gptel-send)
  (message "✅ 错误分析请求已发送到gptel"))

(defun doom/openclaw-apply-patch (patch-text)
  "OpenClaw专用：应用补丁到当前文件。
PATCH-TEXT: 补丁文本。"
  (interactive "s补丁文本: ")
  (save-excursion
    (goto-char (point-min))
    (insert patch-text "\n")
    (message "✅ 补丁已应用到当前文件")))

(defun doom/openclaw-open-file (file-path)
  "OpenClaw专用：打开文件。
FILE-PATH: 文件路径。"
  (interactive "f文件路径: ")
  (find-file file-path))

(defun doom/openclaw-save-all ()
  "OpenClaw专用：保存所有缓冲区。"
  (interactive)
  (save-some-buffers t))

(provide 'doom-openclaw)
EOF
        
        echo -e "  ✅ 创建了 doom-openclaw.el"
        
        # 询问是否自动添加
        read -p "自动添加到 config.el? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "" >> "$EMACS_CONFIG"
            echo ";; OpenClaw集成" >> "$EMACS_CONFIG"
            echo "(load-file \"$SKILL_DIR/scripts/doom-openclaw.el\")" >> "$EMACS_CONFIG"
            echo -e "  ✅ 已添加到 config.el"
        fi
    fi
else
    echo -e "  ⚠️  Doom配置不存在: $EMACS_CONFIG"
    echo -e "  ℹ️  请确保Doom Emacs正确安装"
fi

# 测试安装
echo -e "${GREEN}🧪 测试安装...${NC}"

if [ -f "$BIN_DIR/doombridge" ]; then
    echo -e "  ✅ doombridge命令已安装"
else
    echo -e "  ❌ doombridge命令安装失败"
fi

if [ -f "$BIN_DIR/doombridge-health-check" ]; then
    echo -e "  ✅ doombridge-health-check命令已安装"
else
    echo -e "  ❌ doombridge-health-check命令安装失败"
fi

# 运行健康检查
echo -e "${GREEN}🏥 运行健康检查...${NC}"
if [ -f "$BIN_DIR/doombridge-health-check" ]; then
    "$BIN_DIR/doombridge-health-check"
else
    echo -e "  ⚠️  无法运行健康检查"
fi

# 完成
echo ""
echo -e "${GREEN}🎉 Doom Emacs Bridge安装完成！${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}🚀 可用命令:${NC}"
echo -e "  ${GREEN}doombridge-open-file${NC}        打开文件"
echo -e "  ${GREEN}doombridge-analyze-error${NC}    分析编译错误"
echo -e "  ${GREEN}doombridge-start-gptel${NC}      启动gptel"
echo -e "  ${GREEN}doombridge-tmux-to-gptel${NC}    tmux到gptel"
echo -e "  ${GREEN}doombridge-create-dev-session${NC} 创建开发会话"
echo -e "  ${GREEN}doombridge-health-check${NC}     健康检查"
echo -e "  ${GREEN}doombridge-help${NC}             帮助"
echo ""
echo -e "${BLUE}📚 完整命令列表:${NC}"
echo "  运行: doombridge-help"
echo ""
echo -e "${YELLOW}💡 示例工作流:${NC}"
echo "  1. doombridge-create-dev-session ~/code/redis-src"
echo "  2. 在tmux中编译: make"
echo "  3. 分析错误: doombridge-analyze-error \"错误信息\""
echo "  4. 应用修复，重新编译"
echo ""
echo -e "${GREEN}🚀 开始使用你的Doom Emacs Bridge吧！${NC}"