# Doom Emacs 完整开发环境技能

## 🚀 快速开始

```bash
# 1. 进入技能目录
cd ~/code/workspace/skills/doom-emacs

# 2. 一键安装所有组件
./scripts/install-all.sh

# 3. 验证安装
doombridge health-check
tci help
```

## 📋 包含功能

这个技能整合了三个相关的技能：

1. **🤖 GPTel AI集成** - AI辅助编程
2. **🔧 LSP语言服务器** - 代码智能提示
3. **🌉 OpenClaw桥接** - 自动化工作流
4. **🔗 tmux集成** - 终端工作流

## 📁 目录结构

```
doom-emacs/
├── SKILL.md                    # 完整文档
├── MIGRATION.md               # 迁移指南
├── scripts/                   # 安装和工具脚本
├── references/                # 配置示例
├── team-config/               # 团队标准化
├── examples/                  # 工作流示例
└── README.md                  # 本文件
```

## 🔧 主要命令

安装后可用命令：

```bash
# OpenClaw桥接
doombridge help                # 查看所有命令
doombridge health-check        # 健康检查
doombridge open-file <文件>    # 打开文件

# tmux集成
tmux2gptel                     # tmux内容到gptel
gptel2tmux                     # gptel响应到tmux
tci help                       # 高级tmux集成

# 开发工作流
dev-session <目录>             # 创建开发会话
```

## 📚 文档

- **完整指南**: `less SKILL.md`
- **迁移指南**: `less MIGRATION.md`
- **配置示例**: `ls references/`
- **工作流示例**: `ls examples/`

## 🎯 使用场景

### 1. Redis开发
```bash
cd ~/code/redis-src
dev-session .
make
# 发现错误时: tci to-gptel -50
```

### 2. AI语言设计
```bash
cd ~/code/ai-programming-language-design
racket experiments/day-03-typed-contracts.rkt
# 分析结果: tmux2gptel
```

### 3. Python项目
```bash
cd ~/code/python-project
dev-session . -l python
# 使用LSP和gptel开发
```

## 🔄 从旧技能迁移

如果你之前使用过以下技能：
- `doom-gptel`
- `doom-lsp` 
- `doom-emacs-bridge`

请查看迁移指南：`less MIGRATION.md`

## 🆘 获取帮助

```bash
# 查看完整文档
less SKILL.md

# 运行健康检查
doombridge health-check

# 测试安装
./scripts/install-all.sh --test
```

## 🎉 开始使用

现在你拥有了完整的Doom Emacs开发环境，集成了AI辅助编程、语言服务器和自动化工具链！

**提示**: 确保Emacs daemon正在运行：`emacs --daemon`

---

*这个技能合并了原来的doom-gptel、doom-lsp和doom-emacs-bridge技能，提供统一的工作流体验。*