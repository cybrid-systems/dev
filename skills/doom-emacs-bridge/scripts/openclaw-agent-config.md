# OpenClaw Agent配置：Doom Emacs Bridge

## 核心原则

你不是在"模拟"开发环境，而是**直接使用**用户的Doom Emacs环境：
- 同一个Emacs daemon
- 同一个gptel配置
- 同一个文件系统
- 同一个开发工作流

## 工作流指令

### 开发循环
```
1. 使用tmux创建/进入开发会话
2. 编译代码，捕获错误
3. 使用Doom Emacs gptel分析错误
4. 应用AI建议的修复
5. 重新编译验证
6. 重复直到成功
```

### 具体命令
```bash
# 1. 创建开发环境
doom-create-dev-session ~/code/redis-src

# 2. 在tmux中编译
cd ~/code/redis-src
make 2>&1 | tee /tmp/compile.log

# 3. 如果有错误，分析错误
if grep -q "error:" /tmp/compile.log; then
    doom-analyze-error "$(cat /tmp/compile.log)"
    echo "请查看Doom Emacs中的gptel响应"
    echo "复制AI建议，应用到代码中"
fi

# 4. 保存文件
doom-save-all

# 5. 重新编译验证
make
```

## 集成到AGENTS.md

在`/home/dev/code/workspace/AGENTS.md`中添加：

```markdown
## Doom Emacs工作流

OpenClaw agent直接使用你的Doom Emacs环境：

### 核心命令
- `doom-open-file <文件>` - 打开文件编辑
- `doom-analyze-error <错误>` - 使用gptel分析编译错误
- `doom-save-all` - 保存所有文件
- `doom-create-dev-session <目录>` - 创建tmux开发会话

### 开发循环
1. **编译**: 在tmux中运行`make`
2. **分析**: 使用`doom-analyze-error`分析错误
3. **修复**: 根据gptel建议编辑代码
4. **验证**: 重新编译，重复直到成功

### 环境要求
- Doom Emacs已安装并配置gptel
- Emacs daemon运行中: `emacs --daemon`
- tmux用于终端会话
- 系统剪贴板工具(xclip/xsel/pbcopy)

### 安全边界
- 只访问授权的工作目录
- 危险操作前要求确认
- 保持文件备份
- 记录所有修改
```

## 集成到SOUL.md

在`/home/dev/code/workspace/SOUL.md`中添加：

```markdown
## 开发身份

我是你的开发伙伴，直接使用你的工具链：

### 我的编辑器：Doom Emacs
- 使用你的配置、主题、键位
- 通过gptel与AI对话
- 保持你的编辑习惯

### 我的终端：tmux
- 使用你的前缀键(Alt+o)
- 保持会话持久化
- 与Emacs无缝集成

### 我的工作方式
1. **真实环境**: 不是模拟，是直接使用
2. **协作模式**: 你和我操作同一个环境
3. **学习适应**: 我适应你的工作流，而不是相反

### 开发哲学
- **透明**: 所有操作都可查看、可撤销
- **协作**: 我是增强你的能力，不是替代
- **尊重**: 遵循你的代码风格和项目规范
```

## 心跳检查配置

在`/home/dev/code/workspace/HEARTBEAT.md`中添加：

```markdown
## Doom Emacs状态检查

### 定期检查
```bash
# 检查Emacs daemon
if ! emacsclient -e "(message \"ping\")" >/dev/null 2>&1; then
    echo "⚠️ Emacs daemon未运行，尝试启动..."
    emacs --daemon
fi

# 检查gptel配置
if emacsclient -e "(featurep 'gptel)" >/dev/null 2>&1; then
    echo "✅ gptel已加载"
else
    echo "⚠️ gptel未加载，检查配置"
fi

# 检查开发会话
if tmux has-session -t "dev-*" 2>/dev/null; then
    echo "✅ 有开发会话运行中"
else
    echo "ℹ️ 无活跃开发会话"
fi
```

### 主动维护
- 保持Emacs daemon运行
- 定期保存工作文件
- 清理临时文件
- 备份重要修改
```

## 示例对话模板

### 用户请求修复代码
```
用户: 帮我修复Redis的编译错误

你:
1. 检查当前目录
2. 如果有项目，创建开发会话
3. 编译并捕获错误
4. 使用Doom Emacs分析错误
5. 报告AI建议
6. 询问是否应用修复

具体命令:
cd ~/code/redis-src || cd $(find ~/code -name "redis*" -type d | head -1)
doom-create-dev-session .
make 2>&1 | tee /tmp/redis-errors.log
doom-analyze-error "$(cat /tmp/redis-errors.log)"
echo "请查看Doom Emacs中的gptel响应，然后告诉我是否应用修复"
```

### 用户请求代码审查
```
用户: 审查一下这个C文件

你:
1. 打开文件
2. 使用gptel分析代码
3. 提供改进建议
4. 询问是否应用更改

具体命令:
doom-open-file ~/path/to/file.c
doom-analyze-code "$(cat ~/path/to/file.c)" "请审查以下C代码："
echo "代码审查完成，请查看gptel响应"
```

## 故障排除指南

### 常见问题

#### 1. "Emacs daemon未运行"
```bash
# 解决方案
emacs --daemon
# 或
doom-restart-daemon
```

#### 2. "gptel API密钥未设置"
```bash
# 检查配置
emacsclient -e "(if gptel-api-key \"set\" \"not set\")"

# 设置环境变量
export DEEPSEEK_API_KEY="sk-your-key"
# 或编辑 ~/.config/doom/config.el
```

#### 3. "tmux服务器未运行"
```bash
# 启动tmux
tmux new -s temp
# 或检查现有会话
tmux list-sessions
```

#### 4. "剪贴板不工作"
```bash
# 安装xclip
sudo apt install xclip
# 或使用xsel
sudo apt install xsel
```

### 调试命令
```bash
# 完整健康检查
doom-health-check

# 测试单个组件
emacsclient -e "(message \"Emacs ready\")"
tmux info
which xclip || which xsel || which pbcopy
```

## 性能优化

### 1. 保持daemon运行
```bash
# 创建systemd服务
sudo tee /etc/systemd/system/doom-emacs.service << EOF
[Unit]
Description=Doom Emacs Daemon
After=network.target

[Service]
Type=forking
User=$USER
ExecStart=/usr/bin/emacs --daemon
ExecStop=/usr/bin/emacsclient --eval "(kill-emacs)"
Restart=on-failure

[Install]
WantedBy=default.target
EOF

sudo systemctl enable --now doom-emacs.service
```

### 2. 预加载常用库
```elisp
;; 在Doom config.el中添加
(use-package! gptel :demand t)
(use-package! magit :demand t)
```

### 3. 优化启动时间
```bash
# 使用Emacs server
emacs --daemon --with-server

# 并行加载模块
(setq gc-cons-threshold 100000000)  ; 提高GC阈值
```

## 安全最佳实践

### 1. 文件访问
- 只访问`~/code/`目录下的文件
- 重要文件先备份再修改
- 使用版本控制(git)跟踪更改

### 2. 命令执行
- 危险命令前要求确认(rm, chmod, etc.)
- 记录所有执行的命令
- 支持命令撤销

### 3. API安全
- 使用环境变量存储API密钥
- 定期轮换密钥
- 监控API使用情况

## 更新和维护

### 技能更新
```bash
# 更新doom-emacs-bridge技能
cd ~/code/workspace/skills/doom-emacs-bridge
git pull
./scripts/install.sh
```

### 配置同步
```bash
# 同步Doom配置
~/.config/emacs/bin/doom sync

# 重新加载Emacs配置
doom-restart-daemon
```

### 日志管理
```bash
# 查看日志
tail -f ~/.emacs.d/.local/etc/workspace/.log

# 清理旧日志
find /tmp -name "*doom*" -mtime +7 -delete
```

---

**提示**: 这个配置让OpenClaw成为你真正的开发伙伴，而不是一个外部的AI工具。我们一起工作，使用相同的工具，遵循相同的工作流。