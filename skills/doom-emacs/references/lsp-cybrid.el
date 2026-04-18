;; lsp-cybrid.el - Cybrid LSP 配置示例
;; 针对 Cybrid 开发环境的优化配置

;; ==================== 基础 LSP 配置 ====================

;; 启用 LSP 模式
(use-package! lsp-mode
  :commands lsp
  :custom
  (lsp-keymap-prefix "C-c l")
  :hook
  ((c-mode . lsp)
   (c++-mode . lsp)
   (python-mode . lsp)
   (rust-mode . lsp)
   (go-mode . lsp)
   (js-mode . lsp)
   (typescript-mode . lsp)
   (java-mode . lsp))
  :config
  ;; 性能优化
  (setq lsp-auto-configure t
        lsp-auto-guess-root t
        lsp-log-io nil
        lsp-keep-workspace-alive nil
        lsp-enable-symbol-highlighting t
        lsp-enable-xref t
        lsp-enable-indentation t
        lsp-enable-on-type-formatting t))

;; ==================== 语言服务器配置 ====================

;; C/C++ - clangd
(after! lsp-clangd
  (setq lsp-clients-clangd-args
        '("--background-index"
          "--clang-tidy"
          "--completion-style=detailed"
          "--header-insertion=never"
          "--query-driver=/usr/bin/g++"
          "--query-driver=/usr/bin/clang"
          "--all-scopes-completion"
          "--cross-file-rename"))
  
  ;; 编译命令数据库
  (setq lsp-clients-clangd-compilation-commands-dir "build"
        lsp-clients-clangd-use-default-compilation-commands t))

;; Python - pyright
(after! lsp-pyright
  (setq lsp-pyright-auto-import-completions t
        lsp-pyright-type-checking-mode "basic"
        lsp-pyright-use-library-code-for-types t
        lsp-pyright-venv-path "venv"
        lsp-pyright-python-executable-cmd "python3"))

;; Rust - rust-analyzer
(after! rustic
  (setq rustic-lsp-server 'rust-analyzer
        rustic-format-on-save t
        rustic-analyzer-command '("rust-analyzer")))

;; JavaScript/TypeScript
(after! lsp-mode
  (add-to-list 'lsp-language-id-configuration '(web-mode . "javascript"))
  (add-to-list 'lsp-language-id-configuration '(typescript-mode . "typescript"))
  
  (setq lsp-clients-typescript-server-args '("--stdio")
        lsp-clients-typescript-tls-server nil))

;; Go - gopls
(after! lsp-mode
  (setq lsp-gopls-staticcheck t
        lsp-gopls-complete-unimported t
        lsp-gopls-deep-completion t))

;; Java - eclipse.jdt.ls
(after! lsp-java
  (setq lsp-java-vmargs '("-Xmx4G" "-XX:+UseG1GC")
        lsp-java-import-gradle-enabled t
        lsp-java-import-maven-enabled t))

;; ==================== 编译命令数据库 ====================

(use-package! compile-commands
  :config
  (setq compile-commands-generate-commands
        '((cmake . "cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -B build .")
          (meson . "meson setup build --buildtype=debug")
          (make . "bear -- make -j$(nproc)")
          (cargo . "cargo build --message-format=json")
          (bazel . "bazel build --experimental_action_listener=//tools/actions:generate_compile_commands")))
  
  ;; 自动检测项目类型
  (add-hook 'project-find-functions #'compile-commands-project-find))

;; ==================== 性能优化 ====================

;; 内存限制
(setq lsp-clients-clangd-memory-limit 4096  ; 4GB
      lsp-pyright-memory-limit 2048         ; 2GB
      lsp-rust-analyzer-server-command '("rust-analyzer")
      lsp-rust-analyzer-cargo-watch-command "clippy")

;; 文件监视限制
(setq lsp-file-watch-threshold 1000
      lsp-enable-file-watchers t
      lsp-restart 'auto-restart)

;; 延迟加载
(setq lsp-idle-delay 0.5
      lsp-completion-provider :capf
      lsp-signature-auto-activate t
      lsp-signature-render-documentation t)

;; ==================== UI 配置 ====================

(use-package! lsp-ui
  :commands lsp-ui-mode
  :custom
  (lsp-ui-peek-always-show t)
  (lsp-ui-sideline-show-code-actions t)
  (lsp-ui-sideline-show-hover t)
  (lsp-ui-doc-enable t)
  (lsp-ui-doc-header t)
  (lsp-ui-doc-include-signature t)
  (lsp-ui-doc-position 'top)
  (lsp-ui-doc-max-width 80)
  (lsp-ui-doc-max-height 30)
  (lsp-ui-sideline-update-mode 'point)
  :config
  ;; 主题适配
  (setq lsp-ui-doc-use-webkit nil))

;; ==================== 调试配置 ====================

;; DAP 调试适配器协议
(use-package! dap-mode
  :commands dap-debug
  :custom
  (dap-auto-configure-features '(sessions locals breakpoints expressions))
  :config
  ;; C/C++ 调试
  (require 'dap-cpptools)
  ;; Python 调试
  (require 'dap-python)
  ;; Go 调试
  (require 'dap-go))

;; ==================== 项目特定配置 ====================

(defun my/lsp-project-setup ()
  "Setup LSP based on project type."
  (when-let ((project (project-current)))
    (let ((root (project-root project)))
      (cond
       ;; Redis 项目
       ((string-match-p "redis" root)
        (setq-local lsp-clients-clangd-args
                    '("--background-index"
                      "--query-driver=/usr/bin/gcc"
                      "--query-driver=/usr/bin/clang"))
        (setq-local compile-commands-file "compile_commands.json"))
       
       ;; Python 项目
       ((file-exists-p (expand-file-name "setup.py" root))
        (setq-local lsp-pyright-venv-path "venv")
        (setq-local python-shell-interpreter "python3"))
       
       ;; Rust 项目
       ((file-exists-p (expand-file-name "Cargo.toml" root))
        (setq-local rustic-format-on-save t)
        (setq-local lsp-rust-analyzer-cargo-watch-command "clippy"))
       
       ;; Web 项目
       ((or (file-exists-p (expand-file-name "package.json" root))
            (file-exists-p (expand-file-name "yarn.lock" root)))
        (setq-local js-indent-level 2)
        (setq-local typescript-indent-level 2))))))

(add-hook 'project-switch-hook #'my/lsp-project-setup)

;; ==================== 快捷键配置 ====================

;; LSP 专属快捷键
(map! :leader
      :prefix ("l" . "lsp")
      :desc "LSP execute code action" "a" #'lsp-execute-code-action
      :desc "LSP find references" "r" #'lsp-find-references
      :desc "LSP find definitions" "d" #'lsp-find-definition
      :desc "LSP rename" "n" #'lsp-rename
      :desc "LSP format buffer" "f" #'lsp-format-buffer
      :desc "LSP organize imports" "o" #'lsp-organize-imports
      :desc "LSP workspace symbols" "s" #'lsp-workspace-symbol
      :desc "LSP restart workspace" "R" #'lsp-workspace-restart
      :desc "LSP describe session" "i" #'lsp-describe-session)

;; 代码操作快捷键
(map! :map lsp-mode-map
      :localleader
      "ca" #'lsp-execute-code-action
      "cr" #'lsp-rename
      "cf" #'lsp-format-buffer
      "co" #'lsp-organize-imports
      "cd" #'lsp-find-definition
      "cD" #'lsp-find-references)

;; ==================== 集成功能 ====================

;; 与 flycheck 集成
(setq lsp-diagnostics-provider :flycheck
      flycheck-check-syntax-automatically '(save mode-enabled))

;; 与 company 集成
(setq company-lsp-async t
      company-lsp-cache-candidates t
      company-lsp-enable-snippet t)

;; 与 yasnippet 集成
(setq lsp-enable-snippet t
      yas-minor-mode t)

;; ==================== 性能监控 ====================

(defun my/lsp-performance-monitor ()
  "Monitor LSP performance."
  (interactive)
  (let ((stats (lsp--session-workspaces (lsp-session))))
    (message "LSP Workspaces: %d" (length stats))
    (dolist (ws stats)
      (message "  %s: %s" (lsp--workspace-root ws)
               (lsp--workspace-status ws)))))

;; 定期检查性能
(run-with-timer 300 300 #'my/lsp-performance-monitor)

;; ==================== 故障排除 ====================

;; 调试日志
(setq lsp-log-io nil  ; 生产环境关闭
      lsp-print-performance nil)

;; 重启功能
(defun my/lsp-restart-all ()
  "Restart all LSP workspaces."
  (interactive)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when lsp-mode
        (lsp-workspace-restart (lsp-find-workspace (lsp--buffer-workspace))))))
  (message "All LSP workspaces restarted"))

;; ==================== 团队配置 ====================

;; 团队共享配置
(defvar my/team-lsp-config
  '((c-mode . ((lsp-clients-clangd-args . ("--background-index"
                                           "--query-driver=/usr/local/bin/gcc-12"))
               (compile-commands-file . "build/compile_commands.json")))
    (python-mode . ((lsp-pyright-venv-path . ".venv")
                    (python-shell-interpreter . "python3.11")))
    (rust-mode . ((rustic-lsp-server . "rust-analyzer")
                  (rustic-format-on-save . t))))
  "Team shared LSP configuration.")

;; 加载团队配置
(when (getenv "TEAM_MODE")
  (dolist (config my/team-lsp-config)
    (add-to-list 'dir-locals-class-alist config)))

;; ==================== 使用示例 ====================

;; 示例：快速修复所有错误
(defun my/lsp-fix-all-errors ()
  "Apply all available code actions in buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when (lsp--get-code-actions)
        (lsp-execute-code-action))
      (forward-line))))

;; 示例：批量重命名
(defun my/lsp-rename-in-project (old-name new-name)
  "Rename symbol across entire project."
  (interactive "sOld name: \nsNew name: ")
  (let ((refs (lsp-find-references old-name)))
    (dolist (ref refs)
      (find-file (lsp--location-file ref))
      (goto-char (lsp--location-line ref))
      (lsp-rename new-name))))

;; 绑定到快捷键
(map! :leader
      :prefix ("l" . "lsp")
      :desc "Fix all errors" "F" #'my/lsp-fix-all-errors
      :desc "Rename in project" "P" #'my/lsp-rename-in-project)