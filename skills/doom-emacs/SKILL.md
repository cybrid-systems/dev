---
name: doom-emacs
description: 完整的Doom Emacs开发环境配置、使用和集成。包括gptel AI聊天、LSP语言服务器、tmux集成、OpenClaw桥接等完整工作流。使用当设置Doom Emacs开发环境、配置AI辅助编程、语言服务器、终端集成或创建自动化开发工作流时。
---

# Doom Emacs 完整开发环境技能

> 📅 **最后更新**: 2026-04-18 | **兼容**: Doom Emacs 最新版 + OpenClaw

这个技能整合了三个相关的技能：
1. **doom-gptel** - AI聊天集成
2. **doom-lsp** - 语言服务器集成
3. **doom-emacs-bridge** - OpenClaw桥接工具

## 📖 目录

- [🚀 快速开始](#-快速开始)
- [⌨️ Doom Emacs 核心快捷键](#️-doom-emacs-核心快捷键leader-键速查)
- [🤖 GPTel AI聊天集成](#-gptel-ai聊天集成)
- [🔧 LSP语言服务器集成](#-lsp语言服务器集成)
- [🌉 OpenClaw桥接工具](#-openclaw桥接工具)
- [🔗 tmux集成工作流](#-tmux集成工作流)
- [🛠️ 开发工作流示例](#️-开发工作流示例)
- [📊 故障排除](#-故障排除)
- [🎯 最佳实践](#-最佳实践)
- [📁 技能结构](#-技能结构)
- [🔄 更新和维护](#-更新和维护)
- [📚 扩展资源](#-扩展资源)
- [🎉 开始使用](#-开始使用)

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

## ⌨️ Doom Emacs 核心快捷键（Leader 键速查）

Doom Emacs 使用 **SPC（空格键）** 作为全局 Leader 键，所有常用操作都走这个前缀。

### 代码操作（最常用） `SPC c`

| 快捷键 | 功能 | 对应命令 |
|------------|------------------------|-----------------------------------|
| `SPC c d` | 跳转到定义 | `lsp-find-definition` |
| **`SPC c D`** | **查找引用** | `lsp-find-references` |
| `SPC c a` | 代码动作（快速修复） | `lsp-execute-code-action` |
| `SPC c r` | 重命名符号 | `lsp-rename` |
| `SPC c f` | 格式化当前缓冲区 | `lsp-format-buffer` |
| `SPC c e` | 显示错误/诊断列表 | `flycheck-list-errors` |

### 项目 & 文件 `SPC p / SPC f`

| 快捷键 | 功能 |
|------------|--------------------------|
| `SPC p p` | 切换项目 |
| `SPC p f` | 在项目中查找文件 |
| `SPC f f` | 查找文件 |
| `SPC f r` | 最近打开的文件 |
| `SPC f s` | 保存所有文件 |

### 搜索 & 跳转 `SPC s`

| 快捷键 | 功能 |
|------------|--------------------------|
| `SPC s s` | 项目全文搜索（ripgrep） |
| `SPC s p` | 在当前项目搜索 |
| `SPC s i` | 跳转到符号（imenu） |

### 本 Skill 增强功能

| 快捷键 / 命令 | 功能 |
|------------------------|-------------------------------|
| `doombridge health-check` | 环境健康检查 |
| `doombridge create-dev-session <dir>` | 一键启动开发会话（tmux+Emacs） |
| `M-x gptel` | 打开 AI 聊天窗口 |
| `SPC o d`（推荐自定义）| 打开 doombridge 菜单 |

> 💡 **小技巧**：任何时候按 `SPC h k` 再按一个键，就能实时查看该键的绑定说明。

### 🎯 Daily Recommended Workflow

#### 晨间启动
```bash
# 1. 启动环境
emacs --daemon

# 2. 创建开发会话
doombridge create-dev-session ~/code/my-project

# 3. 连接到 Emacs
emacsclient -c
```

#### 代码分析流程
```elisp
;; 1. 打开项目文件
SPC p p 选择项目
SPC p f src/main.c

;; 2. 深入理解代码
SPC c d   ; 跳转到定义
SPC c D   ; 查找所有引用
SPC s i   ; 查看符号列表

;; 3. AI 辅助分析
M-x gptel
选中代码，C-c < 发送给 AI

;; 4. 应用修改
SPC c r   ; 重命名符号
SPC c f   ; 格式化代码
SPC f s   ; 保存所有文件
```

#### 问题调试流程
```bash
# 1. 编译并捕获错误
cd ~/code/my-project
make 2>&1 | tee /tmp/build.log

# 2. 发送错误到 AI 分析
tci to-gptel -30

# 3. 在 Emacs 中修复
doombridge open-file src/error.c 42
# 根据 GPTel 建议编辑

doombridge save-all
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

## 📚 扩展资源

### 配置示例文件

| 文件 | 用途 |
|------|------|
| [references/gptel-config.el](references/gptel-config.el) | GPTel AI 聊天完整配置 |
| [references/lsp-cybrid.el](references/lsp-cybrid.el) | Cybrid LSP 优化配置 |
| [references/keybindings.el](references/keybindings.el) | 自定义快捷键配置 |
| [references/tmux-integration.el](references/tmux-integration.el) | tmux 集成配置 |
| [references/doom-cheatsheet.md](references/doom-cheatsheet.md) | 完整快捷键速查表 |
| [references/module-structure.md](references/module-structure.md) | 模块化结构参考 |

### 学习路径建议
1. **第一周**: 掌握核心快捷键（`SPC c d/D`, `SPC f f`, `SPC b b`）
2. **第二周**: 学习 LSP 和代码分析功能
3. **第三周**: 集成 GPTel AI 辅助编程
4. **第四周**: 自定义配置和工作流优化

### 社区支持
- [Doom Emacs GitHub](https://github.com/doomemacs/doomemacs)
- [Doom Emacs Discord](https://discord.gg/doomemacs)
- [OpenClaw 社区](https://discord.com/invite/clawd)
- [Cybrid Systems](https://github.com/cybrid-systems)

## 🎉 开始使用

选择适合你的工作流：

1. **快速开始**：运行`./scripts/install-all.sh`
2. **按需安装**：只安装需要的组件
3. **团队部署**：使用`team-config/`目录
4. **自定义配置**：修改`references/`中的示例

现在你拥有了完整的Doom Emacs开发环境，集成了AI辅助编程、语言服务器、终端集成和自动化工具链！🚀

> 💡 **提示**: 按 `SPC h k` 可以随时查看任何按键的绑定说明，这是学习 Doom Emacs 的最佳方式！