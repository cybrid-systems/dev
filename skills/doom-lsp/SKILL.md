---
name: doom-lsp
description: 让 OpenClaw 直接使用 Doom Emacs 的 LSP 能力（定义跳转、诊断、补全、hover、rename 等）
version: 2.1.0 (稳定修复版)
author: Grok-assisted
tags: [emacs, doom, lsp, coding-agent, ide]
---

# Doom LSP 极简技能（仅 LSP 版）

本技能教 OpenClaw 代理如何**直接操作用户本地的 Doom Emacs**，充分利用 LSP 的代码智能能力。

## 前置要求（必须满足）

1. 已安装 **Doom Emacs** 并启用 `:tools lsp` 模块（`doom install lsp`）。
2. Emacs daemon 正在运行：`emacs --daemon`（建议加到开机自启）。
3. 项目目录下有正确的语言服务器（clangd、pyright、rust-analyzer 等会自动下载）。

## 核心命令（OpenClaw 可直接执行）

### 基础 LSP 命令
```bash
# 安装后可用命令（放在 PATH 或用完整路径）
doom-lsp help                          # 查看帮助
doom-lsp health-check                  # 检查环境状态
doom-lsp setup-project <目录>          # 设置项目并检查编译数据库

doom-lsp check-compile-db <路径>       # 检查编译数据库位置
doom-lsp open-file <文件> [行] [列]    # 打开文件（自动查找编译数据库）
doom-lsp find-symbol <文件> <符号>     # 查找符号位置（输出: 行:列 或 NOT_FOUND）
doom-lsp find-def <文件> <符号>        # 跳转到符号定义（带错误检查）
doom-lsp list-functions <文件>         # 列出文件中的函数
```

### Redis 专用分析工具
```bash
# Redis 代码分析（需要设置 REDIS_DIR 环境变量）
redis-analyzer help                    # 查看帮助
redis-analyzer analyze <command>       # 分析 Redis 命令
redis-analyzer chain <function>        # 分析函数调用链
redis-analyzer report <command>        # 生成分析报告
redis-analyzer batch [commands...]     # 批量分析命令
redis-analyzer interactive             # 交互式分析模式
```

### 关键特性
- **编译数据库支持**: 自动查找和使用 `compile_commands.json`
- **错误符号检测**: 不存在的符号立即报错，不会虚假成功
- **超时保护**: LSP 操作有超时限制，避免卡死
- **项目感知**: 理解项目结构，提供准确的代码分析
- **Redis 专用**: 完整的 Redis 代码分析工作流

### 🎯 重要：C/C++ 项目必须步骤
对于 Redis 等 C/C++ 项目，需要 `compile_commands.json` 文件 LSP 才能正确工作：

```bash
# 1. 确保有 compile_commands.json
cd ~/code/redis
ls compile_commands.json  # 应该存在

# 2. 设置项目
doom-lsp setup-project ~/code/redis

# 3. 开始使用
doom-lsp open-file src/server.c 1882 1

# 4. 使用分析工具
redis-analyzer analyze set
redis-analyzer batch set get incr decr
```

## OpenClaw 工作流示例

### 示例 1：完整 Redis LSP 工作流

```bash
# 1. 项目设置（关键步骤！）
doom-lsp setup-project ~/code/redis
# 输出: [SUCCESS] 找到 compile_commands.json

# 2. 检查编译数据库
doom-lsp check-compile-db src/server.c
# 输出: /home/dev/code/redis/compile_commands.json

# 3. 打开文件（自动使用编译数据库）
doom-lsp open-file src/server.c 1882 1  # initServer

# 4. 跳转到定义（现在能正确理解代码）
doom-lsp find-def src/server.c "initServer"
doom-lsp find-def src/server.c "aeCreateEventLoop"
```

### 示例 2：Redis 命令分析工作流

```bash
# 1. 使用专用分析工具
redis-analyzer analyze set
# 输出: 找到 setCommand 引用和实现，显示关键调用

# 2. 批量分析多个命令
redis-analyzer batch set get incr decr
# 输出: 逐个分析每个命令的实现

# 3. 分析调用链
redis-analyzer chain dictAdd
# 输出: dictAdd 函数的定义、调用关系和被调用情况

# 4. 生成分析报告
redis-analyzer report set
# 输出: 生成详细的 Markdown 分析报告

# 5. 交互式分析
redis-analyzer interactive
# 进入交互模式，可以输入命令进行分析
```

### 示例 2：错误处理演示

```bash
# 错误符号 - 立即报错，不会虚假成功
doom-lsp find-def src/server.c "initServr"
# 输出: [ERROR] 符号 'initServr' 不存在
# 退出码: 1 (明确失败)

# 不存在的文件 - 立即报错
doom-lsp open-file src/nonexistent.c 1 1
# 输出: [ERROR] 文件不存在: src/nonexistent.c
# 退出码: 1
```

### 示例 3：Redis 开发最佳实践

```bash
# 1. 查看代码结构（最可靠）
doom-lsp list-functions src/server.c | grep -E "(init|main|process)" | head -10

# 2. 使用 grep 找到精确位置
LINE=$(grep -n "void initServer" src/server.c | cut -d: -f1)

# 3. 精确打开查看
if [ -n "$LINE" ]; then
    doom-lsp open-file src/server.c $LINE 1
    echo "已打开 initServer 函数"
fi

# 4. 结合使用 grep 和 doom-lsp
for func in initServer aeMain processCommand; do
    if grep -q "$func" src/server.c; then
        echo "找到函数: $func"
        # 可以进一步处理
    fi
done
```

## 安装步骤（给 OpenClaw 读的）

1. 把整个 doom-lsp 文件夹放到 `~/code/workspace/skills/doom-lsp`
2. 执行一次安装：
   ```bash
   cd ~/code/workspace/skills/doom-lsp
   chmod +x scripts/doom-lsp-bridge.sh
   sudo ln -s $(pwd)/scripts/doom-lsp-bridge.sh /usr/local/bin/doom-lsp
   ```
3. 测试：
   ```bash
   doom-lsp health-check
   ```

## 关键概念

### 1. compile_commands.json
对于 C/C++ 项目（如 Redis），LSP 需要 `compile_commands.json` 来：
1. **理解编译参数**：包含路径 (`-I`)、宏定义 (`-D`)、编译器标志
2. **正确解析代码**：知道头文件位置、类型定义、函数签名
3. **提供准确分析**：跳转、补全、错误检查都依赖编译信息

Redis 项目通常已有 `compile_commands.json`。如果没有，需要生成：
```bash
cd ~/code/redis
# 使用 bear（推荐）
bear -- make
# 或使用 compiledb
compiledb make
```

### 2. Redis 分析工具
`redis-analyzer` 是基于 `doom-lsp` 构建的高级分析工具，提供：
1. **命令分析**：自动查找 Redis 命令的实现和调用关系
2. **调用链分析**：追踪函数调用关系，理解数据流
3. **报告生成**：自动生成详细的分析报告
4. **批量处理**：一次性分析多个相关命令
5. **交互模式**：友好的命令行交互界面

### 3. 工作流集成
工具设计为与 OpenClaw 完美集成：
1. **自动化**：脚本化分析流程，减少手动操作
2. **可重复**：相同命令产生相同结果，便于分享和协作
3. **可扩展**：易于添加新的分析功能和命令
4. **实用导向**：解决实际的代码理解和分析需求

## 问题修复记录

### 已解决的关键问题
1. **编译数据库支持**: 自动查找和使用 `compile_commands.json`
2. **错误符号虚假成功**: `find-def` 对不存在的符号不再报告"成功"
3. **健康检查卡死**: 添加超时保护，避免无响应
4. **安全错误处理**: 添加符号存在性检查和文件验证
5. **极简稳定**: 移除复杂递归逻辑，避免死锁

### 当前限制
1. **LSP 初始化较慢**: Redis 等大型项目 LSP 启动需要时间
2. **简单符号匹配**: 使用 `grep` 进行基础符号搜索
3. **功能精简**: 只保留最稳定核心功能，避免复杂依赖

## Bridge 脚本实现（scripts/doom-lsp-bridge.sh）

极简稳定版脚本，专注于安全可靠的核心功能。

```bash
#!/bin/bash
# doom-lsp-bridge.sh - 极简 Doom LSP Bridge for OpenClaw

EMACSCLIENT="emacsclient -s doom"

case "$1" in
  help)
    echo "可用命令: health-check, open-file, diagnostics, find-def, find-ref, hover, rename"
    ;;
  health-check)
    $EMACSCLIENT -e "(if (and (boundp 'lsp-mode) lsp-mode) \"LSP ready\" \"LSP not active\")" 2>/dev/null || echo "Emacs daemon not running"
    ;;
  open-file)
    file="$2"
    line="${3:-1}"
    $EMACSCLIENT -n -e "(progn (find-file \"$file\") (goto-line $line) (lsp))" >/dev/null
    echo "Opened $file at line $line"
    ;;
  diagnostics)
    file="$2"
    $EMACSCLIENT -e "(progn (find-file \"$file\") (lsp) (lsp-ui-flycheck-list))" 2>&1 | cat
    ;;
  find-def)
    file="$2"; symbol="$3"
    $EMACSCLIENT -e "(progn (find-file \"$file\") (lsp-find-definition))" >/dev/null
    echo "Jumping to definition of $symbol"
    ;;
  find-ref)
    file="$2"; symbol="$3"
    $EMACSCLIENT -e "(progn (find-file \"$file\") (lsp-find-references))" >/dev/null
    echo "Finding references of $symbol"
    ;;
  hover)
    file="$2"; line="$3"; col="$4"
    $EMACSCLIENT -e "(progn (find-file \"$file\") (goto-line $line) (move-to-column $col) (lsp-ui-peek-find-custom 'documentation))" >/dev/null
    echo "Showing hover info at $file:$line:$col"
    ;;
  rename)
    file="$2"; line="$3"; col="$4"; new_name="$5"
    $EMACSCLIENT -e "(progn (find-file \"$file\") (goto-line $line) (move-to-column $col) (lsp-rename \"$new_name\"))" >/dev/null
    echo "Renaming to $new_name at $file:$line:$col"
    ;;
  *)
    echo "Unknown command. Use 'doom-lsp help'"
    ;;
esac
```

## 故障排除

1. **Emacs daemon 未运行**：
   ```bash
   emacs --daemon
   ```

2. **LSP 模块未启用**：
   ```bash
   doom install lsp
   ```

3. **找不到 emacsclient**：
   ```bash
   which emacsclient
   # 如果不在 PATH，修改脚本中的 EMACSCLIENT 路径
   ```

4. **权限问题**：
   ```bash
   chmod +x scripts/doom-lsp-bridge.sh
   ```

## 扩展计划（后续版本）

1. **v1.1**: 添加代码补全建议获取
2. **v1.2**: 集成 gptel 智能修复
3. **v1.3**: 添加 tmux 集成
4. **v2.0**: 完整 Doom Emacs 工作流

## 许可证

MIT