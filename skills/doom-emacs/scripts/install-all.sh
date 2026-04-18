#!/bin/bash
# install-all.sh - 一键安装所有Doom Emacs组件

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 Doom Emacs 完整环境安装${NC}"
echo -e "${YELLOW}========================================${NC}"

# 检查基础依赖
echo -e "${GREEN}🔍 检查基础依赖...${NC}"

check_dep() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ✅ $1"
        return 0
    else
        echo -e "  ❌ $1"
        return 1
    fi
}

check_dep "emacs"
check_dep "tmux"
check_dep "git"
check_dep "curl"

# 检查Doom Emacs安装
echo -e "${GREEN}📦 检查Doom Emacs安装...${NC}"
if [ -d "$HOME/.config/doom" ]; then
    echo -e "  ✅ Doom Emacs配置目录存在"
else
    echo -e "  ⚠️  Doom Emacs配置目录不存在"
    echo -e "  ℹ️  请先安装Doom Emacs:"
    echo -e "      git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs"
    echo -e "      ~/.config/emacs/bin/doom install"
    exit 1
fi

# 安装各个组件
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}1. 安装gptel AI集成...${NC}"
if [ -f "$SCRIPT_DIR/install-gptel.sh" ]; then
    "$SCRIPT_DIR/install-gptel.sh"
else
    echo -e "  ⚠️  gptel安装脚本未找到，跳过"
fi

echo -e "${GREEN}2. 安装tmux集成工具...${NC}"
if [ -f "$SCRIPT_DIR/install-tmux-integration.sh" ]; then
    "$SCRIPT_DIR/install-tmux-integration.sh"
else
    echo -e "  ⚠️  tmux集成安装脚本未找到，跳过"
fi

echo -e "${GREEN}3. 安装OpenClaw桥接...${NC}"
if [ -f "$SCRIPT_DIR/install-bridge.sh" ]; then
    "$SCRIPT_DIR/install-bridge.sh"
else
    echo -e "  ⚠️  桥接安装脚本未找到，跳过"
fi

echo -e "${GREEN}4. 安装LSP配置...${NC}"
if [ -f "$SCRIPT_DIR/install-lsp.sh" ]; then
    "$SCRIPT_DIR/install-lsp.sh"
else
    echo -e "  ⚠️  LSP安装脚本未找到，跳过"
fi

# 创建配置示例
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}📄 创建配置示例...${NC}"

# gptel配置
GPTEL_CONFIG="$SKILL_DIR/references/gptel-config.el"
cat > "$GPTEL_CONFIG" << 'EOF'
;; gptel配置示例
;; 保存为 ~/.config/doom/config.el 或添加到现有配置

(use-package! gptel
  :config
  (setq! gptel-api-key (lambda () (getenv "DEEPSEEK_API_KEY"))))

(setq gptel-model 'deepseek-chat
      gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :endpoint "/chat/completions"
        :stream t
        :key gptel-api-key
        :models '("deepseek-chat" "deepseek-coder")))

;; 多提供商支持
(setq gptel-providers
      `((:name "DeepSeek"
         :key ,(lambda () (getenv "DEEPSEEK_API_KEY"))
         :host "api.deepseek.com"
         :models ("deepseek-chat" "deepseek-coder"))
        (:name "OpenAI"
         :key ,(lambda () (getenv "OPENAI_API_KEY"))
         :host "api.openai.com"
         :models ("gpt-4" "gpt-3.5-turbo"))))

;; 自定义提示
(setq gptel-default-prompt
      "You are an expert programmer. Provide concise, accurate answers with code examples when relevant.")
EOF
echo -e "  ✅ gptel配置: $GPTEL_CONFIG"

# LSP配置
LSP_CONFIG="$SKILL_DIR/references/lsp-config.el"
cat > "$LSP_CONFIG" << 'EOF'
;; LSP配置示例

;; C/C++ with clangd
(after! lsp-clangd
  (setq lsp-clients-clangd-args '("--background-index"
                                  "--clang-tidy"
                                  "--completion-style=detailed"
                                  "--header-insertion=never")))

;; Python with pyright
(after! lsp-pyright
  (setq lsp-pyright-auto-import-completions t
        lsp-pyright-type-checking-mode "basic"))

;; Rust with rust-analyzer
(after! rustic
  (setq rustic-lsp-server 'rust-analyzer))

;; 性能优化
(setq lsp-auto-configure t
      lsp-auto-guess-root t
      lsp-log-io nil
      lsp-keep-workspace-alive nil)

;; 编译命令数据库
(use-package! compile-commands
  :config
  (setq compile-commands-generate-commands
        '((cmake . "cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 .")
          (meson . "meson setup build --buildtype=debug")
          (make . "bear -- make"))))
EOF
echo -e "  ✅ LSP配置: $LSP_CONFIG"

# tmux集成配置
TMUX_CONFIG="$SKILL_DIR/references/tmux-integration.el"
cat > "$TMUX_CONFIG" << 'EOF'
;; tmux-gptel集成函数

(defun my/tmux-capture-to-gptel ()
  "Capture tmux pane content and insert into gptel."
  (interactive)
  (let ((cmd "tmux capture-pane -p -S -1000 | sed '/^[[:space:]]*$/d'"))
    (with-temp-buffer
      (call-process-shell-command cmd nil t)
      (when (derived-mode-p 'gptel-mode)
        (insert (buffer-string))
        (message "Tmux content inserted into gptel")))))

(defun my/gptel-to-tmux ()
  "Send gptel response to tmux for execution."
  (interactive)
  (let ((response (buffer-substring-no-properties
                   (point-min) (point-max))))
    (with-temp-buffer
      (insert response)
      (call-process-region (point-min) (point-max)
                           "bash" nil nil nil
                           "-c" "while IFS= read -r line; do tmux send-keys \"$line\" C-m; sleep 0.1; done")
      (message "Gptel response sent to tmux"))))

;; 键绑定
(map! :map gptel-mode-map
      :localleader
      "t" #'my/tmux-capture-to-gptel
      "T" #'my/gptel-to-tmux)
EOF
echo -e "  ✅ tmux集成配置: $TMUX_CONFIG"

# 完整配置示例
FULL_CONFIG="$SKILL_DIR/references/doom-config.el"
cat > "$FULL_CONFIG" << 'EOF'
;; Doom Emacs完整配置示例
;; 包含gptel、LSP、tmux集成等所有功能

;; ==================== gptel配置 ====================
(use-package! gptel
  :config
  (setq! gptel-api-key (lambda () (getenv "DEEPSEEK_API_KEY"))))

(setq gptel-model 'deepseek-chat
      gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :endpoint "/chat/completions"
        :stream t
        :key gptel-api-key
        :models '("deepseek-chat" "deepseek-coder")))

;; ==================== LSP配置 ====================
;; C/C++
(after! lsp-clangd
  (setq lsp-clients-clangd-args '("--background-index"
                                  "--clang-tidy"
                                  "--completion-style=detailed")))

;; Python
(after! lsp-pyright
  (setq lsp-pyright-auto-import-completions t))

;; 性能优化
(setq lsp-auto-configure t
      lsp-log-io nil)

;; ==================== tmux集成 ====================
(defun my/tmux-capture-to-gptel ()
  "Capture tmux pane content and insert into gptel."
  (interactive)
  (let ((cmd "tmux capture-pane -p -S -1000"))
    (with-temp-buffer
      (call-process-shell-command cmd nil t)
      (when (derived-mode-p 'gptel-mode)
        (insert (buffer-string))
        (message "Tmux content inserted into gptel")))))

(defun my/gptel-to-tmux ()
  "Send gptel response to tmux for execution."
  (interactive)
  (let ((response (buffer-substring-no-properties
                   (point-min) (point-max))))
    (with-temp-buffer
      (insert response)
      (call-process-region (point-min) (point-max)
                           "bash" nil nil nil
                           "-c" "while IFS= read -r line; do tmux send-keys \"$line\" C-m; sleep 0.1; done")
      (message "Gptel response sent to tmux"))))

(map! :map gptel-mode-map
      :localleader
      "t" #'my/tmux-capture-to-gptel
      "T" #'my/gptel-to-tmux)

;; ==================== 开发工作流 ====================
(defun my/compile-with-gptel-capture ()
  "Run make and auto-capture errors to gptel."
  (interactive)
  (let ((default-directory (project-root (project-current))))
    (compile "make")
    (run-at-time "2 sec" nil
                 (lambda ()
                   (when (get-buffer "*compilation*")
                     (with-current-buffer "*compilation*"
                       (when (search-forward "error:" nil t)
                         (my/tmux-capture-to-gptel))))))))

;; 项目特定配置示例
(defun my/setup-project-environment ()
  "Setup environment based on project type."
  (when-let ((project (project-current)))
    (let ((root (project-root project)))
      (cond
       ((file-exists-p (expand-file-name "Cargo.toml" root))
        (setq-local lsp-rust-analyzer-cargo-watch-command "clippy"))
       ((file-exists-p (expand-file-name "setup.py" root))
        (setq-local python-shell-interpreter "python3"))
       ((file-exists-p (expand-file-name "package.json" root))
        (setq-local js-indent-level 2))))))

(add-hook 'project-switch-hook #'my/setup-project-environment)
EOF
echo -e "  ✅ 完整配置示例: $FULL_CONFIG"

# 创建团队配置
echo -e "${GREEN}👥 创建团队配置模板...${NC}"
TEAM_DIR="$SKILL_DIR/team-config"
mkdir -p "$TEAM_DIR"

cat > "$TEAM_DIR/install-team.sh" << 'EOF'
#!/bin/bash
# 团队标准化安装脚本

set -e

echo "安装团队标准化配置..."

# 1. 复制配置文件
cp .dir-locals.el ~/.dir-locals.el.example
cp doom-config.el ~/.config/doom/config.el.d/team.el

# 2. 创建项目模板
mkdir -p ~/templates/project
cp project-template/* ~/templates/project/

# 3. 设置环境变量
echo 'export DEEPSEEK_API_KEY="your-team-key"' >> ~/.env.team
echo 'source ~/.env.team' >> ~/.zshrc

echo "团队配置安装完成！"
EOF

chmod +x "$TEAM_DIR/install-team.sh"

cat > "$TEAM_DIR/.dir-locals.el" << 'EOF'
;; 团队标准化项目配置
((nil . ((fill-column . 80)
         (indent-tabs-mode . nil)
         (tab-width . 4)))
 (c-mode . ((c-basic-offset . 4)
            (c-file-style . "linux")))
 (python-mode . ((python-indent-offset . 4)
                 (py-indent-offset . 4)))
 (js-mode . ((js-indent-level . 2)
             (js-switch-indent-offset . 2))))
EOF

cat > "$TEAM_DIR/README.md" << 'EOF'
# 团队标准化配置

## 安装
```bash
./install-team.sh
```

## 配置说明

### 代码风格
- 缩进: 4空格（C/Python），2空格（JavaScript）
- 行宽: 80字符
- 制表符: 使用空格

### 项目模板
包含标准化的项目结构：
- README.md
- .gitignore
- Makefile
- 代码规范文档

### 环境变量
团队共享的API密钥和配置
EOF

echo -e "  ✅ 团队配置: $TEAM_DIR/"

# 创建工作流示例
echo -e "${GREEN}📋 创建工作流示例...${NC}"
EXAMPLES_DIR="$SKILL_DIR/examples"
mkdir -p "$EXAMPLES_DIR"

# Redis工作流
cat > "$EXAMPLES_DIR/redis-workflow.sh" << 'EOF'
#!/bin/bash
# Redis开发工作流示例

set -e

echo "🚀 Redis开发工作流"

# 1. 创建开发会话
dev-session ~/code/redis-src

# 2. 编译
cd ~/code/redis-src
make clean
make 2>&1 | tee /tmp/redis-build.log

# 3. 分析错误（如果有）
if grep -q "error:" /tmp/redis-build.log; then
    echo "发现编译错误，发送到gptel分析..."
    tci to-gptel -50
    echo "请查看gptel中的分析结果"
fi

# 4. 运行测试
make test

echo "✅ Redis工作流完成"
EOF
chmod +x "$EXAMPLES_DIR/redis-workflow.sh"

# Racket工作流
cat > "$EXAMPLES_DIR/racket-workflow.sh" << 'EOF'
#!/bin/bash
# Racket开发工作流示例

set -e

echo "🚀 Racket AI语言设计工作流"

# 1. 进入项目
cd ~/code/ai-programming-language-design

# 2. 运行实验
racket experiments/day-03-typed-contracts.rkt 2>&1 | tee /tmp/racket-output.log

# 3. 分析结果
echo "实验输出:"
head -20 /tmp/racket-output.log

# 4. 发送到gptel讨论
tci copy -30
echo "内容已复制，可在gptel中粘贴讨论"

echo "✅ Racket工作流完成"
EOF
chmod +x "$EXAMPLES_DIR/racket-workflow.sh"

# Python工作流
cat > "$EXAMPLES_DIR/python-workflow.sh" << 'EOF'
#!/bin/bash
# Python开发工作流示例

set -e

PROJECT_DIR="${1:-.}"

echo "🚀 Python开发工作流: $PROJECT_DIR"

# 1. 设置虚拟环境
cd "$PROJECT_DIR"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

# 2. 安装依赖
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
fi

# 3. 运行测试
if [ -f "setup.py" ]; then
    python setup.py test
elif [ -f "pytest.ini" ]; then
    pytest
fi

# 4. LSP配置
echo "配置Python LSP..."
cat > .dir-locals.el <<PYCONFIG
((python-mode . ((lsp-pyright-venv-path . "venv")
                 (python-shell-interpreter . "venv/bin/python"))))
PYCONFIG

echo "✅ Python工作流完成"
EOF
chmod +x "$EXAMPLES_DIR/python-workflow.sh"

echo -e "  ✅ 工作流示例: $EXAMPLES_DIR/"

# 验证安装
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}🧪 验证安装...${NC}"

check_tool() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ✅ $1"
    else
        echo -e "  ⚠️  $1 (未找到，可能需要重启终端)"
    fi
}

check_tool "tmux2gptel"
check_tool "gptel2tmux"
check_tool "tci"
check_tool "doombridge"

# 检查Emacs daemon状态
echo -e "${GREEN}🔧 检查Emacs daemon...${NC}"
if emacsclient -e "(message \"test\")" >/dev/null 2>&1; then
    echo -e "  ✅ Emacs daemon正在运行"
else
    echo -e "  ℹ️  Emacs daemon未运行，可以运行: emacs --daemon"
fi

# 显示完成信息
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}🎉 安装完成！${NC}"
echo -e "${GREEN}✨ 所有组件已成功安装${NC}"
echo ""
echo "📚 下一步："
echo "1. 查看完整文档: $SKILL_DIR/SKILL.md"
echo "2. 学习快捷键: $SKILL_DIR/references/doom-cheatsheet.md"
echo "3. 运行示例工作流: $EXAMPLES_DIR/"
echo "4. 配置团队环境: $TEAM_DIR/"
echo ""
echo "🚀 快速开始："
echo "• 启动daemon: emacs --daemon"
echo "• 连接到Emacs: emacsclient -c"
echo "• 核心快捷键: SPC c d (定义), SPC c D (引用)"
echo "• AI辅助: M-x gptel"
echo "• 帮助: SPC h k"
echo ""
echo "💡 提示：按 SPC h k 可以查看任何按键的绑定说明！"
echo ""

# 运行安装后提示
if [ -f "$SCRIPT_DIR/post-install-tips.sh" ]; then
    "$SCRIPT_DIR/post-install-tips.sh"
fi