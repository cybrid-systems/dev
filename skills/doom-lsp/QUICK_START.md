# Doom LSP 极简技能 - 快速开始指南

## 🚀 一分钟安装

```bash
# 1. 确保技能目录存在
cd ~/code/workspace/skills

# 2. 安装 bridge 脚本
cd doom-lsp
chmod +x scripts/doom-lsp-bridge.sh
sudo ln -sf $(pwd)/scripts/doom-lsp-bridge.sh /usr/local/bin/doom-lsp

# 3. 验证安装
doom-lsp version
doom-lsp health-check
```

## 🎯 核心功能速查

### 基础检查
```bash
doom-lsp health-check      # 检查环境状态
doom-lsp version           # 显示版本信息
doom-lsp help              # 查看所有命令
```

### 文件导航
```bash
# 打开文件到指定位置
doom-lsp open-file <文件> [行] [列]

# 示例
doom-lsp open-file src/server.c 100 1
doom-lsp open-file src/dict.c 50 10
```

### 代码理解
```bash
# 查找符号位置
doom-lsp find-symbol <文件> <符号>

# 跳转到定义
doom-lsp find-def <文件> <符号>

# 查找引用
doom-lsp find-ref <文件> <符号>

# 查看文件函数列表
doom-lsp list-functions <文件>
```

### 代码操作
```bash
# 显示悬停信息
doom-lsp hover <文件> <行> <列>

# 重命名符号
doom-lsp rename <文件> <行> <列> <新名称>

# 检查诊断
doom-lsp diagnostics <文件>
```

## 📖 Redis 开发实战示例

### 场景1：理解服务器启动
```bash
# 1. 查看 server.c 中的函数
doom-lsp list-functions src/server.c | grep -i init

# 2. 打开 initServer 函数
doom-lsp open-file src/server.c 1882 1

# 3. 跳转到相关函数
doom-lsp find-def src/server.c "aeCreateEventLoop"
doom-lsp find-def src/server.c "createSharedObjects"
```

### 场景2：分析数据结构
```bash
# 1. 查看 dict.c 结构
doom-lsp list-functions src/dict.c | head -10

# 2. 打开 dict 结构定义
doom-lsp open-file src/dict.c 86 1

# 3. 查看相关函数
doom-lsp find-def src/dict.c "dictAdd"
doom-lsp find-def src/dict.c "dictFind"
```

### 场景3：调试命令处理
```bash
# 1. 找到命令处理函数
doom-lsp find-symbol src/server.c "processCommand"

# 2. 打开查看
doom-lsp open-file src/server.c 3030 1

# 3. 查看调用链
doom-lsp find-def src/server.c "lookupCommand"
doom-lsp find-def src/server.c "call"
```

## 🔧 实用技巧

### 技巧1：结合 grep 使用
```bash
# 先用 grep 找到位置，再用 doom-lsp 打开
LINE=$(grep -n "initServer" src/server.c | cut -d: -f1)
doom-lsp open-file src/server.c $LINE 1
```

### 技巧2：批量分析
```bash
# 分析一组相关函数
for func in zmalloc zfree zrealloc; do
  echo "=== $func ==="
  doom-lsp find-def src/zmalloc.c "$func"
done
```

### 技巧3：快速代码审查
```bash
# 检查文件中的问题
doom-lsp diagnostics src/server.c
doom-lsp list-functions src/server.c | wc -l
```

## ⚠️ 故障排除

### 问题1：Emacs daemon 未运行
```bash
# 解决方案
emacs --daemon
# 等待几秒后重试
doom-lsp health-check
```

### 问题2：LSP 模块未加载
```bash
# 检查 Doom 配置
cat ~/.doom.d/init.el | grep ":tools lsp"

# 如果没有，添加并运行
echo '(doom! :tools lsp)' >> ~/.doom.d/init.el
doom sync
```

### 问题3：命令找不到
```bash
# 重新创建符号链接
cd ~/code/workspace/skills/doom-lsp
sudo ln -sf $(pwd)/scripts/doom-lsp-bridge.sh /usr/local/bin/doom-lsp
```

## 📈 性能优化

### 快速命令
```bash
# 这些命令最快（<10ms）
doom-lsp version
doom-lsp health-check
doom-lsp open-file <文件> <行> <列>
```

### 需要等待的命令
```bash
# 这些命令需要 LSP 初始化（10-50ms）
doom-lsp find-def <文件> <符号>
doom-lsp find-ref <文件> <符号>
doom-lsp hover <文件> <行> <列>
```

## 🎯 最佳实践

1. **先检查环境**：开始前运行 `doom-lsp health-check`
2. **结合使用**：`grep` + `doom-lsp` 是最佳组合
3. **批量操作**：对于多个文件，先收集信息再统一处理
4. **记录常用命令**：创建别名或脚本加速工作流

## 🚀 下一步

掌握了基础功能后，可以：
1. **创建个性化脚本**：自动化常用工作流
2. **集成到 OpenClaw**：让 AI 助手自动使用
3. **扩展功能**：根据需要添加新命令
4. **分享经验**：在团队中推广使用

---

**记住**：这个极简版专注于解决 80% 的日常代码导航需求。先熟练使用这些核心功能，再根据实际需求考虑扩展。