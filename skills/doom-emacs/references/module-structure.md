# Doom Emacs +cybrid 模块结构参考

## 概述

虽然当前技能主要依靠脚本覆盖配置，但这里提供一个模块化的参考结构，供未来升级使用。

## 模块结构

```
~/.config/doom/
├── init.el                    # 主配置文件
├── config.el                  # 自定义配置
├── packages.el                # 包管理
└── modules/
    └── +cybrid/               # Cybrid 模块
        ├── README.org         # 模块文档
        ├── config.el          # 模块配置
        ├── packages.el        # 模块包声明
        └── autoload/          # 自动加载函数
            ├── gptel.el       # GPTel 集成
            ├── lsp.el         # LSP 配置
            ├── tmux.el        # tmux 集成
            └── openclaw.el    # OpenClaw 桥接
```

## 模块配置文件示例

### config.el

```elisp
;;; +cybrid/config.el -*- lexical-binding: t; -*-

;; GPTel 配置
(use-package! gptel
  :config
  (setq! gptel-api-key (lambda () (getenv "DEEPSEEK_API_KEY")))
  (setq gptel-model 'deepseek-chat
        gptel-backend (gptel-make-openai "DeepSeek"
                        :host "api.deepseek.com"
                        :endpoint "/chat/completions")))

;; LSP 配置
(after! lsp-mode
  (setq lsp-auto-configure t
        lsp-log-io nil))

;; 自定义快捷键
(map! :leader
      :prefix ("o" . "openclaw")
      :desc "doombridge health-check" "h" (lambda () (interactive)
                                            (shell-command "doombridge health-check")))
```

### packages.el

```elisp
;;; +cybrid/packages.el -*- lexical-binding: t; -*-

(package! gptel)
(package! lsp-mode)
(package! lsp-ui)
(package! dap-mode)
(package! magit)
```

### autoload/gptel.el

```elisp
;;; +cybrid/autoload/gptel.el -*- lexical-binding: t; -*-

;;;###autoload
(defun +cybrid/gptel-setup ()
  "Setup GPTel for Cybrid workflow."
  (setq gptel-providers
        `((:name "DeepSeek"
           :key ,(lambda () (getenv "DEEPSEEK_API_KEY"))
           :host "api.deepseek.com"
           :models ("deepseek-chat" "deepseek-coder")))))

;;;###autoload
(defun +cybrid/gptel-send-region-to-tmux ()
  "Send selected region to tmux via GPTel."
  (interactive)
  (let ((text (buffer-substring-no-properties (region-beginning) (region-end))))
    (shell-command (format "echo '%s' | tmux load-buffer -" text))))
```

## 安装脚本适配

如果采用模块化结构，安装脚本需要调整为：

```bash
#!/bin/bash
# install-module.sh

set -e

# 创建模块目录
MODULE_DIR="$HOME/.config/doom/modules/+cybrid"
mkdir -p "$MODULE_DIR"/{autoload,lib}

# 复制配置文件
cp references/gptel-config.el "$MODULE_DIR/autoload/gptel.el"
cp references/lsp-cybrid.el "$MODULE_DIR/autoload/lsp.el"
cp references/keybindings.el "$MODULE_DIR/config.el"

# 创建 packages.el
cat > "$MODULE_DIR/packages.el" << 'EOF'
(package! gptel)
(package! lsp-mode)
(package! lsp-ui)
EOF

# 更新 Doom 配置
echo "(doom! :config +cybrid)" >> "$HOME/.config/doom/init.el"

# 同步 Doom
~/.config/emacs/bin/doom sync
```

## 迁移路径

### 阶段1：脚本覆盖（当前）
- 使用 `install-all.sh` 脚本
- 直接修改用户配置文件
- 简单直接，适合快速部署

### 阶段2：混合模式
- 保留脚本安装
- 同时提供模块选项
- 用户可以选择安装方式

### 阶段3：完整模块化
- 完全采用 Doom 模块系统
- 更好的集成和可维护性
- 支持版本管理和更新

## 优势对比

| 特性 | 脚本覆盖 | 模块化 |
|------|----------|--------|
| 安装速度 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 可维护性 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| 集成度 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 升级便利 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| 用户友好 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

## 推荐策略

### 短期（1-3个月）
- 保持当前脚本覆盖方式
- 完善配置文件和文档
- 收集用户反馈

### 中期（3-6个月）
- 开发模块化版本
- 提供两种安装方式
- 逐步迁移用户

### 长期（6个月+）
- 全面转向模块化
- 建立版本发布流程
- 集成到 Doom Emacs 生态

## 注意事项

1. **向后兼容**：确保新版本不影响现有用户
2. **配置迁移**：提供从脚本到模块的迁移工具
3. **文档更新**：同步更新所有文档
4. **测试覆盖**：确保两种方式都能正常工作

## 快速开始（模块化）

```bash
# 1. 安装模块
git clone https://github.com/cybrid-systems/doom-cybrid.git ~/.config/doom/modules/+cybrid

# 2. 启用模块
echo '(doom! :config +cybrid)' >> ~/.config/doom/init.el

# 3. 同步配置
~/.config/emacs/bin/doom sync

# 4. 重启 Emacs
doombridge restart-daemon
```

## 故障排除

### 常见问题

1. **模块未加载**
   ```elisp
   ;; 检查模块是否启用
   M-x doom/info
   ```

2. **配置冲突**
   ```bash
   # 备份现有配置
   cp ~/.config/doom/config.el ~/.config/doom/config.el.backup
   ```

3. **包安装失败**
   ```bash
   # 手动安装包
   ~/.config/emacs/bin/doom sync -u
   ```

## 贡献指南

1. Fork 仓库
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request
5. 等待代码审查

## 联系方式

- GitHub: [cybrid-systems/dev](https://github.com/cybrid-systems/dev)
- Discord: [OpenClaw Community](https://discord.com/invite/clawd)
- Email: dev@cybrid.systems