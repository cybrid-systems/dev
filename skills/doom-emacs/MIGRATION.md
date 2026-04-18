# 技能合并迁移指南

## 📋 概述

已将三个相关的Doom Emacs技能合并为一个统一的`doom-emacs`技能：

| 原技能 | 新位置 | 状态 |
|--------|--------|------|
| `doom-gptel` | `doom-emacs` 的 GPTel 部分 | ✅ 已合并 |
| `doom-lsp` | `doom-emacs` 的 LSP 部分 | ✅ 已合并 |
| `doom-emacs-bridge` | `doom-emacs` 的桥接部分 | ✅ 已合并 |

## 🚀 迁移步骤

### 1. 更新技能引用

在OpenClaw配置或工作流中，将原来的技能引用更新为：

```yaml
# 之前
skills:
  - doom-gptel
  - doom-lsp
  - doom-emacs-bridge

# 之后
skills:
  - doom-emacs
```

### 2. 更新安装命令

```bash
# 之前（分别安装）
cd ~/code/workspace/skills/doom-gptel
./scripts/install-tmux-integration.sh

cd ~/code/workspace/skills/doom-emacs-bridge
./scripts/install.sh

# 之后（一键安装）
cd ~/code/workspace/skills/doom-emacs
./scripts/install-all.sh
```

### 3. 更新配置文件路径

```elisp
;; 之前（分散的配置）
(load-file "~/code/workspace/skills/doom-gptel/references/tmux-integration.el")
(load-file "~/code/workspace/skills/doom-lsp/references/lsp-config.el")

;; 之后（统一的配置）
(load-file "~/code/workspace/skills/doom-emacs/references/doom-config.el")
;; 或分别加载
(load-file "~/code/workspace/skills/doom-emacs/references/gptel-config.el")
(load-file "~/code/workspace/skills/doom-emacs/references/lsp-config.el")
```

### 4. 命令别名更新

```bash
# 之前可能有的别名
alias t2g="tmux2gptel"
alias g2t="gptel2tmux"

# 之后建议的别名
alias de="doombridge"
alias tci="tmux-clipboard-integration.sh"
```

## 📁 文件对应关系

### 原 `doom-gptel` 文件：
- `SKILL.md` → 合并到 `doom-emacs/SKILL.md` 的 GPTel 部分
- `scripts/` → 复制到 `doom-emacs/scripts/`
- `references/tmux-integration.el` → `doom-emacs/references/tmux-integration.el`

### 原 `doom-lsp` 文件：
- `SKILL.md` → 合并到 `doom-emacs/SKILL.md` 的 LSP 部分
- 配置示例 → `doom-emacs/references/lsp-config.el`

### 原 `doom-emacs-bridge` 文件：
- `SKILL.md` → 合并到 `doom-emacs/SKILL.md` 的桥接部分
- `scripts/` → 复制到 `doom-emacs/scripts/`
- `openclaw-agent-config.md` → 集成到文档中

## 🔧 新功能

合并后的技能提供了以下新功能：

### 1. 一键安装
```bash
./scripts/install-all.sh
```

### 2. 统一配置
- 所有配置在同一个 `references/` 目录
- 完整的 `doom-config.el` 示例

### 3. 团队标准化
- `team-config/` 目录包含团队标准化模板
- 项目配置示例

### 4. 工作流示例
- `examples/` 目录包含实际工作流
- Redis、Racket、Python等示例

## 🧪 测试迁移

### 验证安装：
```bash
cd ~/code/workspace/skills/doom-emacs

# 运行完整安装测试
./scripts/install-all.sh

# 验证各个组件
doombridge health-check
tci help
tmux2gptel --help
```

### 验证功能：
```bash
# 1. 测试gptel
emacsclient -e "(gptel-request 'test')"

# 2. 测试LSP
emacsclient -e "(lsp-clangd-version)"

# 3. 测试桥接
doombridge help
```

## 📊 向后兼容性

### 完全兼容：
- 所有脚本命令保持相同（`tmux2gptel`, `gptel2tmux`, `dev-session`）
- 配置文件格式不变
- API密钥和环境变量要求不变

### 需要更新的：
- 技能引用（从三个技能变为一个）
- 安装流程（从分别安装变为一键安装）
- 文档链接

## 🗑️ 清理旧技能（可选）

如果确定不再需要独立的技能，可以：

```bash
# 备份旧技能
mkdir -p ~/backup/skills/
mv ~/code/workspace/skills/doom-gptel ~/backup/skills/
mv ~/code/workspace/skills/doom-lsp ~/backup/skills/
mv ~/code/workspace/skills/doom-emacs-bridge ~/backup/skills/

# 或直接删除
rm -rf ~/code/workspace/skills/doom-gptel
rm -rf ~/code/workspace/skills/doom-lsp
rm -rf ~/code/workspace/skills/doom-emacs-bridge
```

## 📚 新文档结构

```
doom-emacs/
├── SKILL.md                    # 主文档（完整指南）
├── MIGRATION.md               # 本迁移指南
├── scripts/
│   ├── install-all.sh         # 一键安装
│   ├── install-gptel.sh       # GPTel安装
│   ├── install-lsp.sh         # LSP安装
│   ├── install-bridge.sh      # 桥接安装
│   └── [其他工具脚本]
├── references/
│   ├── doom-config.el         # 完整配置
│   ├── gptel-config.el        # GPTel配置
│   ├── lsp-config.el          # LSP配置
│   └── tmux-integration.el    # tmux集成
├── team-config/               # 团队标准化
│   ├── install-team.sh
│   ├── .dir-locals.el
│   └── README.md
├── examples/                  # 工作流示例
│   ├── redis-workflow.sh
│   ├── racket-workflow.sh
│   └── python-workflow.sh
└── README.md                  # 快速开始
```

## 🆘 遇到问题？

### 常见问题：

1. **命令未找到**：
   ```bash
   export PATH="$PATH:$HOME/bin"
   source ~/.zshrc
   ```

2. **Emacs daemon未运行**：
   ```bash
   emacs --daemon
   ```

3. **API密钥未设置**：
   ```bash
   export DEEPSEEK_API_KEY="your-key"
   ```

4. **配置文件冲突**：
   ```bash
   # 备份旧配置
   cp ~/.config/doom/config.el ~/.config/doom/config.el.backup
   # 使用新配置
   cp doom-emacs/references/doom-config.el ~/.config/doom/config.el
   ```

### 获取帮助：
- 查看完整文档：`less SKILL.md`
- 运行健康检查：`doombridge health-check`
- 测试安装：`./scripts/install-all.sh --test`

## 🎉 迁移完成！

恭喜！你现在拥有一个统一的、功能完整的Doom Emacs开发环境技能。享受更简洁的配置和更强大的工作流吧！🚀

> **注意**：原技能目录可以保留作为备份，直到你确认新技能完全正常工作。