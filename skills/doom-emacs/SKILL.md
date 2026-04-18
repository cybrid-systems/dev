---
name: doom-emacs
description: 完整的Doom Emacs开发环境配置、使用和集成。包括gptel AI聊天、LSP语言服务器、tmux集成、OpenClaw桥接等完整工作流。使用当设置Doom Emacs开发环境、配置AI辅助编程、语言服务器、终端集成或创建自动化开发工作流时。
---

# Doom Emacs 完整开发环境技能

这个技能整合了三个相关的技能：
1. **doom-gptel** - AI聊天集成
2. **doom-lsp** - 语言服务器集成
3. **doom-emacs-bridge** - OpenClaw桥接工具

## 🚀 快速开始

### 1. 基础环境检查

```bash
# 检查Doom Emacs安装
emacs --version
ls ~/.config/doom/

# 检查daemon是否运行
ps aux | grep emacs
emacsclient -e "(+emacs-features 'daemon)"

# 启动daemon（如果未运行）
emacs --daemon
```

### 2. 一键安装所有工具

```bash
# 克隆或进入技能目录
cd ~/code/workspace/skills/doom-emacs

# 运行完整安装脚本
./scripts/install-all.sh

# 或者分别安装
./scripts/install-gptel.sh
./scripts/install-lsp.sh
./scripts/install-bridge.sh
```

### 3. 验证安装

```bash
# 检查所有组件
doombridge health-check
tci help
tmux2gptel --help
```

## 🤖 GPTel AI聊天集成

### 基础配置

```elisp
;; ~/.config/doom/config.el
(use-package! gptel
  :config
  (setq! gptel-api-key "your-deepseek-api-key"))

(setq gptel-model 'deepseek-chat
      gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :endpoint "/chat/completions"
        :stream t
        :key gptel-api-key
        :models '("deepseek-chat" "deepseek-coder")))
```

### 多提供商支持

```elisp
;; 配置多个AI提供商
(setq gptel-providers
      `((:name "DeepSeek"
         :key ,(lambda () (auth-source-pick-first-password :host "api.deepseek.com"))
         :host "api.deepseek.com"
         :models ("deepseek-chat" "deepseek-coder"))
        (:name "OpenAI"
         :key ,(lambda () (getenv "OPENAI_API_KEY"))
         :host "api.openai.com"
         :models ("gpt-4" "gpt-3.5-turbo"))
        (:name "Anthropic"
         :key ,(lambda () (getenv "ANTHROPIC_API_KEY"))
         :host "api.anthropic.com"
         :models ("claude-3-opus" "claude-3-sonnet"))))
```

### 高级功能

```elisp
;; 自定义提示模板
(setq gptel-default-prompt
      "You are an expert programmer. Provide concise, accurate answers with code examples when relevant.")

;; 自动上下文管理
(defun my/gptel-context-manager ()
  "Add project context to gptel queries."
  (when-let ((project (project-current)))
    (concat "Project: " (project-root project) "\n"
            "Files: " (mapconcat 'identity
                                (mapcar 'file-relative-name
                                        (project-files project))
                                ", "))))

(add-hook 'gptel-pre-send-hook #'my/gptel-context-manager)
```

## 🔧 LSP语言服务器集成

### 语言服务器配置

```elisp
;; C/C++ with clangd
(after! lsp-clangd
  (setq lsp-clients-clangd-args '("--background-index"
                                  "--clang-tidy"
                                  "--completion-style=detailed"
                                  "--header-insertion=never"
                                  "--query-driver=/usr/bin/g++")))

;; Python with pyright
(after! lsp-pyright
  (setq lsp-pyright-auto-import-completions t
        lsp-pyright-type-checking-mode "basic"))

;; Rust with rust-analyzer
(after! rustic
  (setq rustic-lsp-server 'rust-analyzer))

;; JavaScript/TypeScript
(after! lsp-mode
  (add-to-list 'lsp-language-id-configuration '(web-mode . "javascript"))
  (add-to-list 'lsp-language-id-configuration '(typescript-mode . "typescript")))
```

### 编译命令数据库

```elisp
;; 自动生成compile_commands.json
(use-package! compile-commands
  :config
  (setq compile-commands-generate-commands
        '((cmake . "cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 .")
          (meson . "meson setup build --buildtype=debug")
          (make . "bear -- make"))))

;; 自动检测项目类型
(add-hook 'project-find-functions #'compile-commands-project-find)
```

### 性能优化

```elisp
;; 延迟加载LSP
(setq lsp-auto-configure t
      lsp-auto-guess-root t
      lsp-log-io nil
      lsp-keep-workspace-alive nil)

;; 内存限制
(setq lsp-clients-clangd-memory-limit 4096
      lsp-pyright-memory-limit 2048)

;; 文件大小限制
(setq lsp-file-watch-threshold 1000)
```

## 🌉 OpenClaw桥接工具

### 核心命令

安装后可用命令：

```bash
# 健康检查
doombridge health-check

# 文件操作
doombridge open-file ~/code/project/src/main.c 42
doombridge save-all

# 错误分析
doombridge analyze-error "编译错误信息..."

# 开发会话
doombridge create-dev-session ~/code/project

# tmux集成
doombridge tmux-to-gptel
doombridge gptel-to-tmux
```

### 配置OpenClaw Agent

```markdown
# ~/code/workspace/AGENTS.md 添加

## Doom Emacs工作流

### 核心原则
你不是在"模拟"开发环境，而是**直接使用**用户的Doom Emacs环境：
- 同一个Emacs daemon
- 同一个gptel配置
- 同一个文件系统
- 同一个开发工作流

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
```

## 🔗 tmux集成工作流

### 基础集成

```bash
# 安装tmux集成工具
cd ~/code/workspace/skills/doom-emacs
./scripts/install-tmux-integration.sh

# 可用命令
tmux2gptel -n 50        # 复制tmux内容到剪贴板
gptel2tmux              # 发送gptel响应到tmux
dev-session ~/code/proj # 创建开发会话
```

### 高级tmux集成（无头环境）

```bash
# 使用tci工具（tmux clipboard integration）
tci help                    # 查看帮助
tci copy -50               # 捕获tmux内容到临时文件
tci to-gptel -30           # 捕获并发送到gptel
tci paste /path/file.txt   # 发送文件内容到tmux
tci workflow ~/code/proj   # 完整开发工作流
tci monitor 5              # 实时监控
```

### tmux配置

```bash
# ~/.tmux.conf.local
# Oh My Tmux配置
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# 系统剪贴板集成
set -g set-clipboard on
tmux_conf_copy_to_os_clipboard=true

# Vi模式复制
set -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# 前缀键（Alt+o）
set -g prefix M-o
bind M-o send-prefix
```

## 🛠️ 开发工作流示例

### Redis开发工作流

```bash
# 1. 创建开发会话
dev-session ~/code/redis-src

# 2. 编译并捕获错误
cd ~/code/redis-src
make clean
make 2>&1 | tee /tmp/build.log

# 3. 分析错误（如果有）
if grep -q "error:" /tmp/build.log; then
    tci to-gptel -50
    # 在gptel中分析错误并获取修复建议
fi

# 4. 应用修复
doombridge open-file src/dict.c 120
# 根据gptel建议编辑文件
doombridge save-all

# 5. 验证修复
make clean && make
```

### AI编程语言设计实验室

```bash
# 1. 创建Racket开发环境
dev-session ~/code/ai-programming-language-design -l racket

# 2. 运行实验
cd ~/code/ai-programming-language-design
racket experiments/day-03-typed-contracts.rkt

# 3. 分析输出
tci copy -30
# 粘贴到gptel进行讨论

# 4. 修改实验代码
doombridge open-file experiments/day-03-typed-contracts.rkt
# 添加新的契约示例
doombridge save-all
```

## 📊 故障排除

### 常见问题

#### 1. Emacs daemon未运行
```bash
# 检查状态
ps aux | grep emacs

# 启动daemon
emacs --daemon

# 或使用systemd
systemctl --user start emacs
```

#### 2. gptel API连接失败
```bash
# 检查API密钥
echo $DEEPSEEK_API_KEY

# 测试连接
curl -X POST https://api.deepseek.com/chat/completions \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"test"}]}'
```

#### 3. LSP服务器未启动
```bash
# 检查LSP日志
tail -f ~/.emacs.d/.local/doom.log

# 手动启动LSP
M-x lsp-workspace-restart
```

#### 4. tmux集成失败
```bash
# 检查tmux服务器
tmux info

# 检查剪贴板工具
which xclip xsel pbcopy

# 使用无头环境方案
tci copy -50
```

### 调试工具

```elisp
;; 启用详细日志
(setq gptel-log-level 'debug
      lsp-log-io t
      lsp-print-performance t)

;; 查看LSP状态
M-x lsp-describe-session
M-x lsp-workspace-folders-open

;; 查看gptel状态
M-x gptel-menu
```

## 🎯 最佳实践

### 1. 项目特定配置

```elisp
;; 项目根目录的.dir-locals.el
((nil . ((lsp-clients-clangd-args . ("--background-index"
                                     "--clang-tidy"
                                     "--query-driver=/usr/local/bin/g++"))
         (compile-commands-file . "build/compile_commands.json")))
 (c-mode . ((mode . c++)
            (c-basic-offset . 4)))
 (python-mode . ((python-shell-interpreter . "python3")
                 (lsp-pyright-venv-path . "venv"))))
```

### 2. 性能优化配置

```elisp
;; 按需加载
(use-package! lsp-mode
  :defer t
  :commands lsp)

(use-package! gptel
  :defer t
  :commands gptel)

;; 内存管理
(setq gc-cons-threshold (* 100 1024 1024)  ; 100MB
      read-process-output-max (* 1024 1024)) ; 1MB
```

### 3. 团队标准化

```bash
# 创建团队配置模板
cp -r ~/code/workspace/skills/doom-emacs/team-config/ .

# 安装脚本
./team-config/install-team.sh

# 文档
open team-config/README.md
```

## 📁 技能结构

```
doom-emacs/
├── SKILL.md                    # 主文档（本文件）
├── scripts/
│   ├── install-all.sh          # 一键安装所有组件
│   ├── install-gptel.sh        # 安装gptel配置
│   ├── install-lsp.sh          # 安装LSP配置
│   ├── install-bridge.sh       # 安装OpenClaw桥接
│   ├── install-tmux-integration.sh
│   ├── tmux2gptel.sh
│   ├── gptel2tmux.sh
│   ├── dev-session.sh
│   └── tmux-clipboard-integration.sh
├── references/
│   ├── gptel-config.el         # gptel配置示例
│   ├── lsp-config.el           # LSP配置示例
│   ├── tmux-integration.el     # tmux集成函数
│   └── doom-config.el          # 完整Doom配置
├── team-config/                # 团队标准化配置
│   ├── install-team.sh
│   ├── .dir-locals.el
│   └── README.md
└── examples/
    ├── redis-workflow.sh       # Redis开发示例
    ├── racket-workflow.sh      # Racket开发示例
    └── python-workflow.sh      # Python开发示例
```

## 🔄 更新和维护

```bash
# 更新技能
cd ~/code/workspace/skills/doom-emacs
git pull origin main

# 重新安装
./scripts/install-all.sh --force

# 检查更新
doombridge check-updates
```

## 🎉 开始使用

选择适合你的工作流：

1. **快速开始**：运行`./scripts/install-all.sh`
2. **按需安装**：只安装需要的组件
3. **团队部署**：使用`team-config/`目录
4. **自定义配置**：修改`references/`中的示例

现在你拥有了完整的Doom Emacs开发环境，集成了AI辅助编程、语言服务器、终端集成和自动化工具链！🚀