---
name: doom-emacs-bridge
description: 让OpenClaw像真人开发者一样直接使用你的Doom Emacs环境。包括启动daemon、调用gptel分析错误、编辑文件、保存等完整工作流。使用当你想让OpenClaw agent直接操作你的Doom Emacs而不是内置编辑器时。
---

# Doom Emacs Bridge Skill

让OpenClaw agent像真人开发者一样直接使用你的Doom Emacs环境，包括gptel AI分析、文件编辑、编译错误修复等完整工作流。

## 核心思想

OpenClaw不是"模拟"或"替代"你的开发环境，而是**直接使用**你已经配置好的Doom Emacs：
- 同一个Emacs daemon
- 同一个gptel配置
- 同一个Evil键位
- 你所有的Doom模块和主题

## 先决条件

✅ **已安装并配置**：
- Doom Emacs（已安装并配置好gptel）
- tmux（用于终端操作）
- OpenClaw agent环境

✅ **已启动**：
- Emacs daemon: `emacs --daemon`
- 或配置为systemd服务自动启动

## 快速开始

### 1. 验证环境

```bash
# 检查Emacs daemon是否运行
emacsclient -e "(message \"Doom Emacs ready\")" 2>/dev/null

# 检查gptel是否可用
emacsclient -e "(require 'gptel)" 2>/dev/null

# 检查tmux
tmux list-sessions
```

### 2. 基础命令

```bash
# 打开文件
doom-open-file ~/code/redis-src/src/dict.c

# 分析编译错误
doom-analyze-error "dict.c:122:20: error: initialization of 'char *' from 'uint64_t'"

# 保存所有缓冲区
doom-save-all

# 重启daemon（如果需要）
doom-restart-daemon
```

## 核心功能

### 文件操作

#### 打开/编辑文件
```bash
# 打开文件（图形界面）
doom-open-file ~/projects/myapp/src/main.c

# 打开文件（终端界面）
doom-open-file-terminal ~/projects/myapp/src/main.c

# 在特定行打开
doom-open-file-at-line ~/projects/myapp/src/main.c 42
```

#### 保存/关闭
```bash
# 保存当前缓冲区
doom-save-buffer

# 保存所有缓冲区
doom-save-all

# 关闭当前缓冲区
doom-close-buffer

# 关闭所有缓冲区
doom-close-all
```

### gptel AI集成

#### 错误分析
```bash
# 分析编译错误
doom-analyze-error "$(cat compile-error.log)"

# 分析代码片段
doom-analyze-code "$(cat problematic-function.c)"

# 请求代码审查
doom-code-review ~/projects/myapp/src/main.c
```

#### 对话交互
```bash
# 启动gptel对话
doom-start-gptel

# 发送消息到gptel
doom-gptel-send "请解释Redis字典数据结构的实现"

# 复制gptel响应
doom-copy-gptel-response
```

### 开发工作流

#### 编译错误修复循环
```bash
# 1. 编译项目
cd ~/projects/myapp && make 2>&1 | tee compile.log

# 2. 如果有错误，分析错误
if grep -q "error:" compile.log; then
    doom-analyze-error "$(cat compile.log)"
    
    # 3. 等待AI响应，然后应用修复
    # （手动或自动应用AI建议）
    
    # 4. 重新编译验证
    make
fi
```

#### 代码重构辅助
```bash
# 请求重构建议
doom-refactor-suggest ~/projects/myapp/src/old.c

# 应用重构
doom-apply-refactor ~/projects/myapp/src/old.c ~/projects/myapp/src/new.c
```

### tmux集成

#### 内容传输
```bash
# 复制tmux内容到gptel
doom-tmux-to-gptel

# 发送gptel响应到tmux
doom-gptel-to-tmux

# 捕获tmux窗格到文件
doom-capture-tmux-pane /tmp/tmux-output.txt
```

#### 会话管理
```bash
# 创建开发会话
doom-create-dev-session ~/projects/myapp

# 附加到开发会话
doom-attach-dev-session ~/projects/myapp

# 列出所有tmux会话
doom-list-tmux-sessions
```

## 完整工作流示例

### 场景：修复Redis编译错误

```bash
#!/bin/bash
# redis-fix-workflow.sh

# 1. 进入项目目录
cd ~/code/redis-src

# 2. 编译并捕获错误
make clean
make 2>&1 | tee /tmp/redis-compile.log

# 3. 如果有错误，使用Doom Emacs分析
if grep -q "error:" /tmp/redis-compile.log; then
    echo "发现编译错误，使用Doom Emacs gptel分析..."
    
    # 4. 打开错误文件（如果有具体文件）
    ERROR_FILE=$(grep -o "\.c:[0-9]" /tmp/redis-compile.log | head -1 | cut -d: -f1)
    if [ -n "$ERROR_FILE" ]; then
        doom-open-file "src/$ERROR_FILE"
    fi
    
    # 5. 分析错误
    doom-analyze-error "$(cat /tmp/redis-compile.log)"
    
    echo "请查看Doom Emacs中的gptel响应，然后："
    echo "1. 复制AI建议"
    echo "2. 应用修复到文件"
    echo "3. 重新编译验证"
else
    echo "编译成功！"
fi
```

### 场景：代码审查和优化

```bash
#!/bin/bash
# code-review-workflow.sh

# 1. 选择要审查的文件
FILE_TO_REVIEW="~/projects/myapp/src/main.c"

# 2. 打开文件
doom-open-file "$FILE_TO_REVIEW"

# 3. 请求代码审查
doom-code-review "$FILE_TO_REVIEW"

# 4. 等待AI响应，讨论改进建议

# 5. 应用建议（手动或半自动）
echo "根据AI建议改进代码，然后："
echo "1. 保存文件: doom-save-all"
echo "2. 运行测试验证"
```

## 配置

### 环境变量

在`~/.bashrc`或`~/.zshrc`中添加：

```bash
# Doom Emacs Bridge配置
export DOOM_EMACS_DAEMON=true
export DOOM_GPTEL_MODEL="deepseek-chat"
export DOOM_TMUX_SESSION_PREFIX="dev"
export DOOM_WORKSPACE_ROOT="$HOME/code"

# API密钥（如果使用环境变量）
export DEEPSEEK_API_KEY="sk-your-key"
# 或
export OPENAI_API_KEY="sk-your-key"
```

### Doom Emacs配置

确保`~/.config/doom/config.el`包含：

```elisp
;; OpenClaw专用函数
(defun doom/openclaw-analyze-error (error-text)
  "分析编译错误。"
  (interactive "s错误信息: ")
  (gptel)
  (insert "分析以下编译错误并提供修复方案：\n\n")
  (insert error-text)
  (gptel-send))

(defun doom/openclaw-apply-patch (patch-text)
  "应用补丁到当前文件。"
  (interactive "s补丁文本: ")
  (save-excursion
    (goto-char (point-min))
    (insert patch-text "\n")
    (message "✅ 补丁已应用")))

;; 导出供shell调用
(provide 'doom-openclaw)
```

## 故障排除

### Emacs daemon问题

```bash
# 检查daemon状态
ps aux | grep emacs.*daemon

# 启动daemon
emacs --daemon

# 重启daemon
doom-restart-daemon

# 杀死daemon
emacsclient -e "(kill-emacs)"
```

### gptel连接问题

```bash
# 测试gptel配置
emacsclient -e "(gptel-test-connection)"

# 检查API密钥
emacsclient -e "(message \"API key: %s\" (if gptel-api-key \"set\" \"not set\"))"

# 重新加载配置
doom-reload-config
```

### tmux集成问题

```bash
# 检查tmux服务器
tmux info

# 检查剪贴板集成
echo "test" | xclip -selection clipboard
xclip -selection clipboard -o

# 检查tmux复制模式
tmux list-keys -T copy-mode-vi | grep "begin-selection"
```

## 性能优化

### 1. 保持daemon运行
```bash
# 使用systemd服务
sudo systemctl enable --now doom-emacs.service
```

### 2. 预加载常用模块
```elisp
;; 在Doom配置中预加载
(use-package! gptel :demand t)  ; 立即加载
```

### 3. 使用Emacs server
```bash
# 启动时启用server
emacs --daemon --with-server

# 多客户端连接
emacsclient -c -t  # 终端客户端
emacsclient -c     # 图形客户端
```

## 安全考虑

### 1. API密钥安全
- 使用环境变量或auth-source存储API密钥
- 不要将密钥硬编码在配置文件中
- 定期轮换密钥

### 2. 文件访问控制
- OpenClaw只能访问授权目录
- 重要文件设置适当权限
- 定期备份工作文件

### 3. 操作确认
- 危险操作前要求确认
- 支持撤销操作
- 记录所有修改

## 扩展功能

### 自定义工作流
```bash
# 创建自定义工作流脚本
doom-create-workflow my-workflow << 'EOF'
#!/bin/bash
# 自定义工作流
cd $1
doom-analyze-error "$(make 2>&1)"
# ...更多步骤
EOF
```

### 插件系统
```bash
# 安装插件
doom-install-plugin code-review

# 列出可用插件
doom-list-plugins

# 更新插件
doom-update-plugins
```

## 与OpenClaw集成

### 在AGENTS.md中添加
```markdown
## Doom Emacs工作流

OpenClaw agent使用你的Doom Emacs环境进行开发：

1. **文件编辑**: 使用`doom-open-file`打开文件
2. **错误分析**: 使用`doom-analyze-error`分析编译错误
3. **AI协助**: 通过gptel获取代码建议
4. **终端集成**: 与tmux无缝协作

所有操作都在你的真实Doom Emacs环境中进行，保持一致的开发体验。
```

### 在SOUL.md中添加
```markdown
## 开发哲学

作为AI助手，我直接使用你的开发工具：
- Doom Emacs是我的编辑器
- gptel是我的AI伙伴
- tmux是我的终端环境

我不是模拟开发，而是**成为**你的开发环境的一部分。
```

## 更新和维护

### 更新技能
```bash
# 从git更新
cd ~/code/workspace/skills/doom-emacs-bridge
git pull

# 重新安装命令
./scripts/install.sh
```

### 检查健康状态
```bash
# 运行健康检查
doom-health-check

# 查看日志
doom-view-logs

# 报告问题
doom-report-issue
```

---

**提示**: 这个技能不是替代你的开发工作，而是增强它。OpenClaw成为你的开发伙伴，直接操作你已经熟悉和喜爱的工具链。