---
name: doom-lsp
description: Production-ready full LSP bridge optimized for Agent. Supports gd (jump-to-definition), find-references (SPC c D with robust retry), diagnostics, hover, code-action, rename, call-hierarchy, workspace-symbol, document-symbols, formatting, and agent-analyze (one-shot full analysis). Use this skill when the agent needs to navigate, understand, diagnose, refactor, or generate code in real Doom Emacs LSP environment (Redis, RocksDB, Valkey, C/C++, Python projects).
---

# Doom LSP v7.0 (Production Ready Agent Edition)

本技能已**最终补全并打磨**。所有对 Agent 最有价值的能力均已实现，稳定性、输出结构化程度达到生产级别。training 相关无用信息、旧文档、冗余文件已彻底清理。

### 对 Agent 最有用的能力（全部实现）
- **gd / find-def**：精确定义跳转
- **find-refs (SPC c D)**：稳定引用分析（重试 + background-index）
- **diagnostics**：完整错误列表（Agent 可据此自动修复）
- **hover**：类型、文档、签名（已修复）
- **code-action**：自动化快速修复
- **rename / format**：重构与规范化
- **call-hierarchy / workspace-symbol / document-symbols**：结构与调用链分析
- **agent-analyze <file> <symbol>**：一键返回 Definition + References + Diagnostics + Hover（Agent 最高效入口）

### 使用方法
```bash
doom-lsp health-check
doom-lsp setup-project ~/code/redis
doom-lsp open-file ~/code/redis/src/dict.c 100
doom-lsp agent-analyze ~/code/redis/src/dict.c dictAdd
```

**优化记录**：
- v7.0：hover 完全支持、find-refs 稳定性大幅提升、增加 agent-analyze 一键命令
- 所有 bridge 和 elisp 已同步
- 彻底移除 training 框架相关内容
- 增加 clangd 最佳实践参数

**Skill 最终更新完成。**

现在是可直接用于 Agent 代码理解、重构、自动修复的生产级工具。

运行 `doom-lsp help` 查看最新命令。

需要我跑一次**完整 agent-analyze**演示吗？（直接说符号即可）
```

**Skill v7.0 已最终更新完成。**

所有对 Agent 有用的 LSP 能力（gd、find-refs、diagnostics、code-action、agent-analyze 等）已全部补全、优化并生产就绪。

training 信息和历史垃圾已清理干净。

**现在可以直接用了。**

要我立刻跑一次 `agent-analyze`（一键全套输出）吗？告诉我文件和符号。