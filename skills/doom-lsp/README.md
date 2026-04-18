# Doom LSP 极简技能

让 OpenClaw 直接使用 Doom Emacs 的 LSP 能力（定义跳转、诊断、补全、hover、rename 等）。

## 快速开始

### 1. 安装技能

```bash
# 克隆或复制到技能目录
cd ~/code/workspace/skills
mkdir -p doom-lsp
# 复制所有文件到此目录
```

### 2. 安装 Bridge 脚本

```bash
cd ~/code/workspace/skills/doom-lsp
chmod +x scripts/doom-lsp-bridge.sh
sudo ln -s $(pwd)/scripts/doom-lsp-bridge.sh /usr/local/bin/doom-lsp
```

### 3. 验证安装

```bash
# 检查 Emacs daemon
emacs --daemon

# 测试 bridge
doom-lsp health-check
```

## 前置要求

1. **Doom Emacs** 已安装并配置
2. **LSP 模块** 已启用（在 `~/.doom.d/init.el` 中添加 `:tools lsp`）
3. **Emacs daemon** 正在运行（`emacs --daemon`）
4. **语言服务器** 已安装（clangd、pyright、rust-analyzer 等）

## 核心命令

```bash
# 健康检查
doom-lsp health-check

# 打开文件（可选行号）
doom-lsp open-file <文件路径> [行号]

# 查看诊断信息
doom-lsp diagnostics <文件路径>

# 跳转到定义
doom-lsp find-def <文件路径> <符号名>

# 查找引用
doom-lsp find-ref <文件路径> <符号名>

# 显示悬停信息
doom-lsp hover <文件路径> <行> <列>

# 重命名符号
doom-lsp rename <文件路径> <行> <列> <新名称>
```

## 使用示例

### 开发工作流

```bash
# 1. 打开文件并启动 LSP
doom-lsp open-file src/main.c 42

# 2. 查看当前错误
doom-lsp diagnostics src/main.c

# 3. 跳转到函数定义
doom-lsp find-def src/main.c "my_function"

# 4. 重命名变量
doom-lsp rename src/main.c 23 15 "new_variable_name"

# 5. 查找所有引用
doom-lsp find-ref src/main.c "my_function"
```

### 与 OpenClaw 集成

在 OpenClaw 中，你可以：

1. **自动诊断代码**：定期运行 `doom-lsp diagnostics` 检查代码质量
2. **智能导航**：使用 `find-def` 和 `find-ref` 理解代码结构
3. **批量重命名**：使用 `rename` 安全地重构代码
4. **实时反馈**：结合 LSP 诊断进行持续集成

## 故障排除

### 常见问题

1. **Emacs daemon 未运行**
   ```bash
   emacs --daemon
   ```

2. **LSP 模块未启用**
   ```bash
   doom install lsp
   ```

3. **权限问题**
   ```bash
   chmod +x scripts/doom-lsp-bridge.sh
   ```

4. **符号链接失败**
   ```bash
   # 手动添加到 PATH
   export PATH="$PATH:~/code/workspace/skills/doom-lsp/scripts"
   ```

### 调试命令

```bash
# 检查 Emacs 状态
ps aux | grep emacs

# 检查 LSP 服务器
doom-lsp health-check

# 测试单个命令
doom-lsp open-file test.py
```

## 配置参考

查看 `references/example-config.el` 获取完整的 Doom Emacs LSP 配置。

## 扩展计划

- **v1.1**: 添加代码补全建议获取
- **v1.2**: 集成 gptel 智能修复
- **v1.3**: 添加 tmux 集成
- **v2.0**: 完整 Doom Emacs 工作流

## 许可证

MIT