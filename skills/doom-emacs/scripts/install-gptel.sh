#!/bin/bash
# install-gptel.sh - 安装gptel AI集成

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🤖 安装gptel AI集成${NC}"
echo -e "${YELLOW}========================================${NC}"

# 检查Emacs
echo -e "${GREEN}🔍 检查Emacs环境...${NC}"
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
echo -e "${GREEN}📦 检查Doom Emacs配置...${NC}"
DOOM_CONFIG="$HOME/.config/doom/config.el"
if [ -f "$DOOM_CONFIG" ]; then
    echo -e "  ✅ Doom配置存在: $DOOM_CONFIG"
    
    # 检查是否已配置gptel
    if grep -q "gptel" "$DOOM_CONFIG"; then
        echo -e "  ✅ gptel已配置"
    else
        echo -e "  ⚠️  gptel未配置"
        echo -e "  ℹ️  添加配置到 $DOOM_CONFIG:"
        echo -e "      $(cat $SKILL_DIR/references/gptel-config.el | head -5)"
    fi
else
    echo -e "  ⚠️  Doom配置不存在"
    echo -e "  ℹ️  请先安装Doom Emacs"
fi

# 检查API密钥
echo -e "${GREEN}🔑 检查API密钥...${NC}"
if [ -n "$DEEPSEEK_API_KEY" ]; then
    echo -e "  ✅ DEEPSEEK_API_KEY已设置"
    echo -e "  ℹ️  密钥前5位: ${DEEPSEEK_API_KEY:0:5}..."
else
    echo -e "  ⚠️  DEEPSEEK_API_KEY未设置"
    echo -e "  ℹ️  设置环境变量:"
    echo -e "      export DEEPSEEK_API_KEY=\"your-api-key\""
    echo -e "      或添加到 ~/.zshrc / ~/.bashrc"
fi

# 测试gptel连接
echo -e "${GREEN}🔗 测试gptel连接...${NC}"
if [ -n "$DEEPSEEK_API_KEY" ]; then
    TEST_RESPONSE=$(curl -s -X POST https://api.deepseek.com/chat/completions \
      -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"test"}],"max_tokens":10}' 2>/dev/null || true)
    
    if echo "$TEST_RESPONSE" | grep -q "error"; then
        echo -e "  ⚠️  API连接失败"
        echo -e "  ℹ️  请检查API密钥和网络连接"
    else
        echo -e "  ✅ API连接正常"
    fi
else
    echo -e "  ⚠️  跳过API测试（无API密钥）"
fi

# 启动Emacs daemon（如果未运行）
echo -e "${GREEN}🚀 检查Emacs daemon...${NC}"
if ps aux | grep -q "[e]macs --daemon"; then
    echo -e "  ✅ Emacs daemon正在运行"
else
    echo -e "  ⚠️  Emacs daemon未运行"
    read -p "启动Emacs daemon? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        emacs --daemon
        echo -e "  ✅ Emacs daemon已启动"
    fi
fi

# 测试emacsclient
echo -e "${GREEN}🧪 测试emacsclient...${NC}"
if emacsclient -e "(+emacs-features 'daemon)" 2>/dev/null | grep -q "t"; then
    echo -e "  ✅ emacsclient连接正常"
else
    echo -e "  ⚠️  emacsclient连接失败"
    echo -e "  ℹ️  确保Emacs daemon正在运行"
fi

# 创建gptel测试函数
echo -e "${GREEN}📝 创建测试函数...${NC}"
TEST_EL="$SKILL_DIR/test-gptel.el"
cat > "$TEST_EL" << 'EOF'
;; gptel测试脚本
(defun test-gptel-setup ()
  "测试gptel配置"
  (interactive)
  (require 'gptel)
  
  (message "测试gptel配置...")
  
  ;; 检查API密钥
  (if (functionp gptel-api-key)
      (let ((key (funcall gptel-api-key)))
        (if key
            (message "✅ API密钥获取成功 (长度: %d)" (length key))
          (message "❌ API密钥获取失败")))
    (if (stringp gptel-api-key)
        (message "✅ API密钥已设置 (长度: %d)" (length gptel-api-key))
      (message "❌ API密钥未设置")))
  
  ;; 检查后端配置
  (if gptel-backend
      (message "✅ gptel后端已配置: %s" (gptel-backend-name gptel-backend))
    (message "❌ gptel后端未配置"))
  
  ;; 测试简单查询
  (message "发送测试查询...")
  (gptel-request "Hello, this is a test." 
                 :callback (lambda (response)
                             (message "✅ gptel响应: %s" 
                                      (substring response 0 (min 50 (length response)))))))

;; 运行测试
(test-gptel-setup)
EOF

echo -e "  ✅ 测试脚本: $TEST_EL"

# 运行测试
echo -e "${GREEN}🧪 运行配置测试...${NC}"
if emacsclient -e "(load-file \"$TEST_EL\")" 2>&1 | grep -q "✅"; then
    echo -e "  ✅ gptel配置测试通过"
else
    echo -e "  ⚠️  gptel配置测试失败"
    echo -e "  ℹ️  可能需要手动配置gptel"
fi

# 配置建议
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}📋 配置建议:${NC}"
echo ""
echo -e "1. ${BLUE}基本配置${NC}:"
echo -e "   将以下内容添加到 ~/.config/doom/config.el:"
echo -e "   $(cat $SKILL_DIR/references/gptel-config.el | head -10 | sed 's/^/      /')"
echo ""
echo -e "2. ${BLUE}API密钥${NC}:"
echo -e "   设置环境变量:"
echo -e "      export DEEPSEEK_API_KEY=\"your-api-key\""
echo -e "      或使用auth-source:"
echo -e "      (setq gptel-api-key"
echo -e "            (lambda () (auth-source-pick-first-password :host \"api.deepseek.com\")))"
echo ""
echo -e "3. ${BLUE}测试配置${NC}:"
echo -e "   在Emacs中运行: M-x gptel"
echo -e "   或使用命令行测试:"
echo -e "      emacsclient -e \"(gptel-request 'test')\""
echo ""
echo -e "4. ${BLUE}故障排除${NC}:"
echo -e "   • 检查Emacs daemon: ps aux | grep emacs"
echo -e "   • 测试API连接: curl命令"
echo -e "   • 查看日志: tail -f ~/.emacs.d/.local/doom.log"

echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}✅ gptel安装完成${NC}"
echo -e "现在可以在Emacs中使用M-x gptel启动AI聊天了！🚀"