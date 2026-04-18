---
name: doom-lsp
description: 让 OpenClaw 直接使用 Doom Emacs 的 LSP 能力（定义跳转、诊断、补全、hover、rename 等）
version: 2.0.0
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

所有命令都通过优化的 bridge 脚本实现：

```bash
# 安装后可用命令（放在 PATH 或用完整路径）
doom-lsp help                           # 查看帮助
doom-lsp version                        # 显示版本信息
doom-lsp health-check                   # 检查环境状态
doom-lsp open-file <文件> [行] [列]     # 打开文件到指定位置
doom-lsp find-symbol <文件> <符号>      # 查找符号位置（输出: 行:列）
doom-lsp find-def <文件> <符号>         # 跳转到符号定义
doom-lsp find-ref <文件> <符号>         # 查找符号引用
doom-lsp hover <文件> <行> <列>         # 显示悬停信息
doom-lsp rename <文件> <行> <列> <新名> # 重命名符号
doom-lsp diagnostics <文件>             # 查看简单诊断
doom-lsp list-functions <文件>          # 列出文件中的函数
```

### 新功能亮点
- **彩色输出**: 更好的可读性
- **错误检查**: 自动检查文件和 daemon 状态
- **智能搜索**: 改进的符号查找
- **实用工具**: `list-functions` 快速查看文件结构

## OpenClaw 工作流示例

### 示例 1：精确位置导航

```bash
# 找到符号的精确位置
doom-lsp find-symbol src/server.c "initServer"
# 输出: "1882:15" (第1882行第15列)

# 打开文件到该位置
doom-lsp open-file src/server.c 1882 15

# 跳转到定义
doom-lsp find-def src/server.c "initServer"
```

### 示例 2：智能重构工作流

```bash
# 1. 找到要重命名的变量
doom-lsp find-symbol src/dict.c "dictType"
# 输出: "86:8"

# 2. 重命名变量
doom-lsp rename src/dict.c 86 8 "new_dict_type"

# 3. 验证所有引用已更新
doom-lsp find-ref src/dict.c "new_dict_type"
```

### 示例 3：Redis 开发工作流

```bash
# 1. 查看文件结构
doom-lsp list-functions src/server.c | head -10

# 2. 打开关键函数
doom-lsp open-file src/server.c 1882 1  # initServer

# 3. 跳转到相关定义
doom-lsp find-def src/server.c "aeCreateEventLoop"

# 4. 检查诊断
doom-lsp diagnostics src/server.c

# 5. 理解调用关系
doom-lsp find-ref src/server.c "redisServer"
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

## Bridge 脚本实现（scripts/doom-lsp-bridge.sh）

优化版脚本，包含彩色输出、错误检查和实用功能。

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