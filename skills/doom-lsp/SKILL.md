---
name: doom-lsp
description: Production-ready LSP bridge optimized for Agent. Supports gd (jump-to-definition), find-references (SPC c D), health-check, setup-project, open-file, and hover. Use this skill when the agent needs to navigate, understand, or analyze code in real Doom Emacs LSP environment (Redis, RocksDB, Valkey, C/C++ projects).
---

# Doom LSP v8.1 (Production Ready Agent Edition)

本技能已**最终优化并稳定**。所有对 Agent 最有价值的核心能力均已实现，稳定性达到生产级别。training 相关无用信息、旧文档、冗余文件已彻底清理。

### 核心修复与优化
1. **路径硬编码问题**：彻底解决，使用动态 SCRIPT_DIR 检测，确保技能可移植
2. **引号解析错误**：修复了 "Wrong number of arguments: find-file, 3" 等 elisp 引号解析问题
3. **纯 CLI 模式**：按照用户选择 B，保持为纯 CLI 工具，不修改用户 Doom Emacs 配置
4. **索引等待机制**：增加了智能的 LSP 索引等待逻辑，确保在大项目上稳定工作

### 对 Agent 最有用的核心能力（全部实现）
- **health-check**：检查 Emacs daemon 和 LSP 模块状态
- **setup-project**：设置项目并查找 compile_commands.json
- **open-file**：打开文件并触发 LSP
- **gd / find-def**：精确定义跳转
- **find-refs (SPC c D)**：稳定引用分析
- **hover**：类型、文档、签名信息

### 使用方法
```bash
# 基本检查
doom-lsp health-check

# 设置项目
doom-lsp setup-project ~/code/redis

# 打开文件
doom-lsp open-file ~/code/redis/src/dict.c 100

# 查找定义
doom-lsp find-def ~/code/redis/src/dict.c dictAdd

# 查找引用
doom-lsp find-refs ~/code/redis/src/dict.c dictAdd
```

### 测试脚本
已提供完整的测试脚本：
```bash
cd skills/doom-lsp/scripts
./test-lsp-full.sh                    # 测试小项目（快速）
./test-lsp-full.sh /home/dev/code/redis  # 测试 Redis（完整）
```

**优化记录**：
- v8.0：移除不稳定的 diagnostics 和 list-functions，专注于核心能力
- v8.1：使用 raw lsp-mode 函数，避免 Doom 特定依赖，确保最大兼容性
- 彻底移除 training 框架相关内容
- 增加智能项目检测和索引等待机制

**Skill v8.1 已生产就绪。**

现在是可直接用于 Agent 代码理解、导航和分析的生产级工具。

**现在可以直接用了。**

要我演示如何使用这个技能分析特定代码吗？告诉我文件和符号。