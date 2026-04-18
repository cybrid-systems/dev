# Doom LSP 极简技能 v2.1.0

让 OpenClaw 直接使用 Doom Emacs 的 LSP 能力，并提供 Redis 专用分析工具。

## 🚀 快速开始

### 1. 安装技能

```bash
# 进入技能目录
cd ~/code/workspace/skills/doom-lsp

# 安装基础 LSP 工具
chmod +x scripts/doom-lsp-bridge.sh
sudo ln -sf $(pwd)/scripts/doom-lsp-bridge.sh /usr/local/bin/doom-lsp

# 安装 Redis 分析工具
chmod +x install-redis-analyzer.sh
./install-redis-analyzer.sh
```

### 2. 验证安装

```bash
# 检查基础工具
doom-lsp health-check

# 检查 Redis 分析工具
redis-analyzer help
```

### 3. 配置环境（可选）

```bash
# 设置 Redis 目录
export REDIS_DIR=/home/dev/code/redis

# 设置项目编译数据库
doom-lsp setup-project "$REDIS_DIR"
```

## 📋 前置要求

### 基础要求
1. **Doom Emacs** 已安装并配置
2. **LSP 模块** 已启用（在 `~/.doom.d/init.el` 中添加 `:tools lsp`）
3. **Emacs daemon** 正在运行（`emacs --daemon`）
4. **语言服务器** 已安装（clangd、pyright、rust-analyzer 等）

### Redis 分析要求
1. **Redis 源码**：需要 Redis 项目目录
2. **编译数据库**：需要 `compile_commands.json` 文件
3. **环境变量**：建议设置 `REDIS_DIR` 环境变量

## 🛠️ 核心命令

### 基础 LSP 命令
```bash
# 健康检查
doom-lsp health-check

# 项目设置
doom-lsp setup-project <目录>
doom-lsp check-compile-db <路径>

# 文件导航
doom-lsp open-file <文件> [行] [列]
doom-lsp list-functions <文件>

# 符号操作
doom-lsp find-symbol <文件> <符号>
doom-lsp find-def <文件> <符号>
```

### Redis 分析命令
```bash
# 命令分析
redis-analyzer analyze <command>       # 分析 Redis 命令
redis-analyzer chain <function>        # 分析函数调用链
redis-analyzer report <command>        # 生成分析报告
redis-analyzer batch [commands...]     # 批量分析命令
redis-analyzer interactive             # 交互式分析
```

## 🎯 使用示例

### Redis 开发工作流

```bash
# 1. 设置项目环境
doom-lsp setup-project ~/code/redis

# 2. 分析 SET 命令
redis-analyzer analyze set
# 输出: 找到 setCommand 实现，显示关键调用链

# 3. 批量分析常用命令
redis-analyzer batch set get incr decr
# 输出: 逐个分析每个命令的实现

# 4. 深入分析调用链
redis-analyzer chain dictAdd
# 输出: dictAdd 函数的定义、调用关系和被调用情况

# 5. 生成详细报告
redis-analyzer report set
# 输出: 生成 Markdown 格式的分析报告
```

### 基础代码导航

```bash
# 1. 查找符号位置
doom-lsp find-symbol src/server.c "initServer"
# 输出: 1882:1

# 2. 打开文件查看
doom-lsp open-file src/server.c 1882 1
# Emacs 中打开文件到指定位置

# 3. 跳转到定义
doom-lsp find-def src/server.c "initServer"
# 尝试跳转到函数定义

# 4. 查看代码结构
doom-lsp list-functions src/server.c | head -10
# 列出文件中的函数
```

### 与 OpenClaw 集成

在 OpenClaw 中，你可以：

1. **自动化代码分析**：定期运行 Redis 命令分析
2. **智能代码导航**：快速理解复杂代码结构
3. **批量代码审查**：一次性分析多个相关功能
4. **文档自动生成**：基于分析结果生成技术文档
5. **团队知识共享**：分享分析报告和调用图

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