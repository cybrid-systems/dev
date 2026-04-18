#!/bin/bash
# install-lsp.sh - 安装LSP语言服务器配置

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🔧 安装LSP语言服务器配置${NC}"
echo -e "${YELLOW}========================================${NC}"

# 检查语言服务器
echo -e "${GREEN}🔍 检查语言服务器...${NC}"

check_lsp() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ✅ $1: $(command -v "$1")"
        return 0
    else
        echo -e "  ⚠️  $1 (未安装)"
        return 1
    fi
}

echo -e "${BLUE}C/C++:${NC}"
check_lsp "clangd"
check_lsp "clang-tidy"
check_lsp "bear"

echo -e "${BLUE}Python:${NC}"
check_lsp "python3"
check_lsp "pyright"
check_lsp "pylsp"

echo -e "${BLUE}Rust:${NC}"
check_lsp "rustc"
check_lsp "rust-analyzer"
check_lsp "cargo"

echo -e "${BLUE}JavaScript/TypeScript:${NC}"
check_lsp "node"
check_lsp "npm"
check_lsp "typescript-language-server"

echo -e "${BLUE}其他:${NC}"
check_lsp "bash-language-server"
check_lsp "docker-langserver"

# 检查Doom LSP模块
echo -e "${GREEN}📦 检查Doom LSP模块...${NC}"
DOOM_INIT="$HOME/.config/doom/init.el"
if [ -f "$DOOM_INIT" ]; then
    if grep -q ":tools lsp" "$DOOM_INIT"; then
        echo -e "  ✅ LSP模块已启用"
    else
        echo -e "  ⚠️  LSP模块未启用"
        echo -e "  ℹ️  在init.el中添加: :tools lsp"
    fi
    
    # 检查语言模块
    LANGUAGES=("cc" "python" "rust" "javascript" "web")
    for lang in "${LANGUAGES[@]}"; do
        if grep -q ":lang $lang" "$DOOM_INIT"; then
            echo -e "  ✅ $lang 模块已启用"
        else
            echo -e "  ⚠️  $lang 模块未启用"
        fi
    done
else
    echo -e "  ⚠️  Doom init.el未找到"
fi

# 创建LSP配置
echo -e "${GREEN}📄 创建LSP配置...${NC}"
LSP_CONFIG="$SKILL_DIR/references/lsp-config.el"
if [ -f "$LSP_CONFIG" ]; then
    echo -e "  ✅ LSP配置已存在: $LSP_CONFIG"
else
    echo -e "  ⚠️  LSP配置未找到"
fi

# 测试LSP功能
echo -e "${GREEN}🧪 测试LSP功能...${NC}"

# 创建测试文件
TEST_DIR="/tmp/lsp-test-$$"
mkdir -p "$TEST_DIR"

# C测试文件
cat > "$TEST_DIR/test.c" << 'EOF'
#include <stdio.h>

int main() {
    printf("Hello, LSP!\n");
    return 0;
}
EOF

# Python测试文件
cat > "$TEST_DIR/test.py" << 'EOF'
def hello():
    print("Hello, LSP!")

if __name__ == "__main__":
    hello()
EOF

echo -e "  ✅ 创建测试文件: $TEST_DIR/"

# 检查编译命令数据库
echo -e "${GREEN}📊 检查编译命令数据库...${NC}"
if command -v bear &> /dev/null; then
    cd "$TEST_DIR"
    echo "int main() { return 0; }" > test.c
    bear -- gcc -c test.c 2>/dev/null || true
    
    if [ -f "compile_commands.json" ]; then
        echo -e "  ✅ 编译命令数据库生成成功"
        echo -e "  ℹ️  文件: $TEST_DIR/compile_commands.json"
    else
        echo -e "  ⚠️  编译命令数据库生成失败"
    fi
else
    echo -e "  ⚠️  bear未安装，跳过编译命令测试"
fi

# 语言服务器安装指南
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}📋 语言服务器安装指南:${NC}"
echo ""
echo -e "1. ${BLUE}C/C++ (clangd)${NC}:"
echo -e "   Ubuntu/Debian:"
echo -e "      sudo apt install clangd clang-tidy bear"
echo -e "   macOS:"
echo -e "      brew install llvm bear"
echo ""
echo -e "2. ${BLUE}Python (pyright)${NC}:"
echo -e "   pip安装:"
echo -e "      pip install pyright"
echo -e "   npm安装:"
echo -e "      npm install -g pyright"
echo ""
echo -e "3. ${BLUE}Rust (rust-analyzer)${NC}:"
echo -e "   通过rustup:"
echo -e "      rustup component add rust-analyzer"
echo -e "   或手动安装:"
echo -e "      git clone https://github.com/rust-lang/rust-analyzer.git"
echo -e "      cd rust-analyzer"
echo -e "      cargo xtask install --server"
echo ""
echo -e "4. ${BLUE}JavaScript/TypeScript${NC}:"
echo -e "   npm安装:"
echo -e "      npm install -g typescript typescript-language-server"
echo ""
echo -e "5. ${BLUE}其他语言服务器${NC}:"
echo -e "   Bash: npm install -g bash-language-server"
echo -e "   Docker: npm install -g dockerfile-language-server-nodejs"
echo -e "   JSON/YAML: npm install -g vscode-langservers-extracted"

# Doom配置建议
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}⚙️  Doom LSP配置建议:${NC}"
echo ""
echo -e "1. ${BLUE}启用模块${NC} (在 ~/.config/doom/init.el):"
echo -e "   :tools lsp"
echo -e "   :lang cc        # C/C++"
echo -e "   :lang python    # Python"
echo -e "   :lang rust      # Rust"
echo -e "   :lang javascript # JavaScript"
echo -e "   :lang web       # HTML/CSS"
echo ""
echo -e "2. ${BLUE}添加LSP配置${NC} (在 ~/.config/doom/config.el):"
echo -e "   $(cat "$LSP_CONFIG" | head -15 | sed 's/^/   /')"
echo ""
echo -e "3. ${BLUE}项目特定配置${NC} (.dir-locals.el):"
cat > "$TEST_DIR/.dir-locals.el.example" << 'EOF'
((nil . ((compile-commands-file . "build/compile_commands.json")))
 (c-mode . ((lsp-clients-clangd-args . ("--background-index"
                                        "--clang-tidy"
                                        "--query-driver=/usr/bin/g++"))))
 (python-mode . ((lsp-pyright-venv-path . "venv")
                 (python-shell-interpreter . "venv/bin/python"))))
EOF
echo -e "   文件: $TEST_DIR/.dir-locals.el.example"
echo ""
echo -e "4. ${BLUE}性能优化${NC}:"
echo -e "   • 设置内存限制"
echo -e "   • 禁用不必要的LSP功能"
echo -e "   • 使用文件监视阈值"

# 测试命令
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}🧪 测试命令:${NC}"
echo ""
echo -e "1. ${BLUE}检查LSP状态${NC}:"
echo -e "   M-x lsp-describe-session"
echo -e "   M-x lsp-workspace-folders-open"
echo ""
echo -e "2. ${BLUE}重启LSP${NC}:"
echo -e "   M-x lsp-workspace-restart"
echo ""
echo -e "3. ${BLUE}查看日志${NC}:"
echo -e "   tail -f ~/.emacs.d/.local/doom.log"
echo ""
echo -e "4. ${BLUE}测试特定语言${NC}:"
echo -e "   # C/C++"
echo -e "   emacsclient -e \"(lsp-clangd-version)\""
echo -e "   # Python"
echo -e "   emacsclient -e \"(lsp-pyright-version)\""

# 清理
rm -rf "$TEST_DIR"

echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}✅ LSP配置安装完成${NC}"
echo -e "现在可以在Emacs中使用LSP功能了！🚀"
echo -e "${BLUE}提示:${NC} 打开一个源代码文件，LSP会自动启动。"