;; Doom Emacs LSP 配置参考
;; 放在 ~/.doom.d/config.el 中

;; 启用 LSP 模块
;; 在 ~/.doom.d/init.el 中添加：
;; (doom! :tools lsp)

;; 常用 LSP 配置
(use-package! lsp-mode
  :commands (lsp lsp-deferred)
  :init
  ;; 自动启动 LSP
  (setq lsp-auto-guess-root t
        lsp-restart 'auto-restart
        lsp-enable-symbol-highlighting t
        lsp-enable-on-type-formatting t
        lsp-enable-text-document-color t
        lsp-enable-folding t
        lsp-enable-snippet t
        lsp-enable-file-watchers t
        lsp-enable-indentation t
        lsp-enable-completion-at-point t
        lsp-enable-xref t
        lsp-enable-imenu t
        lsp-enable-dap-auto-configure t)
  
  ;; 性能优化
  (setq lsp-idle-delay 0.5
        lsp-log-io nil
        lsp-keep-workspace-alive nil
        lsp-signature-auto-activate t
        lsp-signature-render-documentation t)
  
  ;; 语言特定配置
  (setq lsp-clients-clangd-args '("--background-index"
                                  "--clang-tidy"
                                  "--completion-style=detailed"
                                  "--header-insertion=never"
                                  "--header-insertion-decorators=0")
        lsp-pyright-extra-paths []
        lsp-rust-analyzer-cargo-watch-command "clippy"
        lsp-eslint-package-manager "npm"
        lsp-tsserver-log-verbosity "off"
        lsp-tsserver-trace-server "off"))

;; LSP UI 增强
(use-package! lsp-ui
  :commands lsp-ui-mode
  :config
  (setq lsp-ui-doc-enable t
        lsp-ui-doc-header t
        lsp-ui-doc-include-signature t
        lsp-ui-doc-position 'at-point
        lsp-ui-doc-max-width 80
        lsp-ui-doc-max-height 30
        lsp-ui-doc-use-childframe t
        lsp-ui-doc-use-webkit nil
        lsp-ui-sideline-enable t
        lsp-ui-sideline-show-code-actions t
        lsp-ui-sideline-show-hover t
        lsp-ui-sideline-show-diagnostics t
        lsp-ui-sideline-ignore-duplicate t
        lsp-ui-peek-enable t
        lsp-ui-peek-list-width 60
        lsp-ui-peek-peek-height 25
        lsp-ui-imenu-enable t
        lsp-ui-imenu-kind-position 'top))

;; 代码补全
(use-package! company
  :config
  (setq company-idle-delay 0.5
        company-minimum-prefix-length 2
        company-tooltip-limit 10
        company-show-numbers t
        company-selection-wrap-around t
        company-transformers '(company-sort-by-backend-importance)
        company-dabbrev-ignore-case nil
        company-dabbrev-downcase nil)
  (global-company-mode t))

;; 代码检查
(use-package! flycheck
  :config
  (setq flycheck-check-syntax-automatically '(save mode-enabled)
        flycheck-idle-change-delay 2.0
        flycheck-display-errors-delay 0.9
        flycheck-indication-mode 'right-fringe
        flycheck-highlighting-mode 'symbols)
  (global-flycheck-mode t))

;; 调试配置
(use-package! dap-mode
  :config
  (require 'dap-gdb-lldb)
  (require 'dap-python)
  (require 'dap-node)
  (require 'dap-go)
  (require 'dap-rust)
  (setq dap-auto-configure-features '(sessions locals controls tooltip)))

;; 快捷键绑定（推荐）
(map! :leader
      (:prefix ("l" . "lsp")
       :desc "跳转到定义" "d" #'lsp-find-definition
       :desc "查找引用" "r" #'lsp-find-references
       :desc "重命名" "R" #'lsp-rename
       :desc "代码操作" "a" #'lsp-execute-code-action
       :desc "格式化" "f" #'lsp-format-buffer
       :desc "格式化区域" "F" #'lsp-format-region
       :desc "组织导入" "o" #'lsp-organize-imports
       :desc "悬停信息" "h" #'lsp-ui-doc-glance
       :desc "显示诊断" "l" #'lsp-ui-flycheck-list
       :desc "重启 LSP" "s" #'lsp-restart-workspace
       :desc "切换侧边栏" "S" #'lsp-ui-sideline-mode))

;; 自动配置
(add-hook 'prog-mode-hook #'lsp-deferred)
(add-hook 'lsp-mode-hook #'lsp-ui-mode)
(add-hook 'lsp-mode-hook #'lsp-enable-which-key-integration)

;; 语言特定钩子
(add-hook 'c-mode-hook #'lsp-deferred)
(add-hook 'c++-mode-hook #'lsp-deferred)
(add-hook 'python-mode-hook #'lsp-deferred)
(add-hook 'rust-mode-hook #'lsp-deferred)
(add-hook 'go-mode-hook #'lsp-deferred)
(add-hook 'js-mode-hook #'lsp-deferred)
(add-hook 'typescript-mode-hook #'lsp-deferred)
(add-hook 'java-mode-hook #'lsp-deferred)

;; 故障排除函数
(defun doom-lsp-check-health ()
  "检查 LSP 健康状态"
  (interactive)
  (message "LSP mode: %s" (if (bound-and-true-p lsp-mode) "enabled" "disabled"))
  (message "LSP UI mode: %s" (if (bound-and-true-p lsp-ui-mode) "enabled" "disabled"))
  (message "Flycheck mode: %s" (if (bound-and-true-p flycheck-mode) "enabled" "disabled"))
  (message "Company mode: %s" (if (bound-and-true-p company-mode) "enabled" "disabled"))
  (when (bound-and-true-p lsp-mode)
    (message "Connected servers: %s" (mapcar #'lsp--workspace-print lsp--buffer-workspaces))))