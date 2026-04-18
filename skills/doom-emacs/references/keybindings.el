;; keybindings.el - Cybrid Doom Emacs 快捷键配置
;; 针对 OpenClaw + Doom Emacs 工作流的优化快捷键

;; ==================== 核心 Leader 键配置 ====================

;; 设置 Leader 键
(setq doom-leader-key "SPC"
      doom-localleader-key ",")

;; ==================== OpenClaw 集成快捷键 ====================

;; doombridge 命令快捷键
(map! :leader
      :prefix ("o" . "openclaw")
      :desc "doombridge health-check" "h" (lambda () (interactive) (shell-command "doombridge health-check"))
      :desc "doombridge open-file" "f" (lambda () (interactive)
                                         (let ((file (read-file-name "File: ")))
                                           (shell-command (format "doombridge open-file %s" file))))
      :desc "doombridge save-all" "s" (lambda () (interactive) (shell-command "doombridge save-all"))
      :desc "doombridge analyze-error" "e" (lambda () (interactive)
                                             (let ((error (read-string "Error: ")))
                                               (shell-command (format "doombridge analyze-error \"%s\"" error))))
      :desc "doombridge create-dev-session" "d" (lambda () (interactive)
                                                  (let ((dir (read-directory-name "Directory: ")))
                                                    (shell-command (format "doombridge create-dev-session %s" dir))))
      :desc "doombridge tmux-to-gptel" "t" (lambda () (interactive) (shell-command "doombridge tmux-to-gptel"))
      :desc "doombridge gptel-to-tmux" "T" (lambda () (interactive) (shell-command "doombridge gptel-to-tmux"))
      :desc "doombridge restart-daemon" "r" (lambda () (interactive) (shell-command "doombridge restart-daemon"))
      :desc "doombridge help" "?" #'help-command)

;; tci (tmux clipboard integration) 快捷键
(map! :leader
      :prefix ("t" . "tmux")
      :desc "tci copy" "c" (lambda () (interactive)
                             (let ((lines (read-number "Lines: " 50)))
                               (shell-command (format "tci copy -%d" lines))))
      :desc "tci to-gptel" "g" (lambda () (interactive)
                                 (let ((lines (read-number "Lines: " 30)))
                                   (shell-command (format "tci to-gptel -%d" lines))))
      :desc "tci paste" "p" (lambda () (interactive)
                              (let ((file (read-file-name "File: ")))
                                (shell-command (format "tci paste %s" file))))
      :desc "tci workflow" "w" (lambda () (interactive)
                                 (let ((dir (read-directory-name "Directory: ")))
                                   (shell-command (format "tci workflow %s" dir))))
      :desc "tci monitor" "m" (lambda () (interactive)
                                (let ((interval (read-number "Interval (seconds): " 5)))
                                  (shell-command (format "tci monitor %d" interval))))
      :desc "tci help" "h" (lambda () (interactive) (shell-command "tci help")))

;; ==================== 开发工作流快捷键 ====================

;; 编译和测试工作流
(map! :leader
      :prefix ("c" . "compile")
      :desc "Compile project" "c" #'compile
      :desc "Recompile" "r" #'recompile
      :desc "Run tests" "t" #'projectile-test-project
      :desc "Clean build" "C" (lambda () (interactive) (compile "make clean"))
      :desc "Build with bear" "b" (lambda () (interactive) (compile "bear -- make -j$(nproc)"))
      :desc "Capture errors to GPTel" "e" (lambda () (interactive)
                                            (compile "make 2>&1 | tee /tmp/build.log")
                                            (run-at-time "2 sec" nil
                                                         (lambda ()
                                                           (when (get-buffer "*compilation*")
                                                             (with-current-buffer "*compilation*"
                                                               (when (search-forward "error:" nil t)
                                                                 (shell-command "tci to-gptel -50"))))))))

;; 代码分析工作流
(map! :leader
      :prefix ("a" . "analyze")
      :desc "Analyze current function" "f" (lambda () (interactive)
                                             (let ((func (thing-at-point 'defun t)))
                                               (gptel)
                                               (insert "Please analyze this function:\n\n" func)))
      :desc "Analyze current file" "F" (lambda () (interactive)
                                         (gptel)
                                         (insert "Please analyze this file:\n\n"
                                                 (buffer-string)))
      :desc "Find TODOs" "t" #'hl-todo-occur
      :desc "Code metrics" "m" #'code-metrics
      :desc "Cyclomatic complexity" "c" #'cyclomatic-complexity)

;; ==================== 项目导航快捷键 ====================

;; 增强的项目导航
(map! :leader
      :prefix ("p" . "project")
      :desc "Switch project" "p" #'projectile-switch-project
      :desc "Find file in project" "f" #'projectile-find-file
      :desc "Find file in project (all)" "F" #'projectile-find-file-in-known-projects
      :desc "Recent project files" "r" #'projectile-recentf
      :desc "Project grep" "s" #'projectile-grep
      :desc "Project ag" "a" #'projectile-ag
      :desc "Project rg" "g" #'projectile-ripgrep
      :desc "Toggle project type" "t" #'projectile-toggle-between-implementation-and-test
      :desc "Project shell" "e" #'projectile-run-shell
      :desc "Project eshell" "E" #'projectile-run-eshell
      :desc "Project vterm" "v" #'projectile-run-vterm
      :desc "Project info" "i" #'projectile-project-info)

;; ==================== 文件操作快捷键 ====================

;; 增强的文件操作
(map! :leader
      :prefix ("f" . "file")
      :desc "Find file" "f" #'find-file
      :desc "Find file (other window)" "F" #'find-file-other-window
      :desc "Recent files" "r" #'recentf-open-files
      :desc "Save buffer" "s" #'save-buffer
      :desc "Save all buffers" "S" #'save-some-buffers
      :desc "Delete file" "d" #'delete-file
      :desc "Rename file" "R" #'rename-file
      :desc "Copy file" "c" #'copy-file
      :desc "Create directory" "D" #'make-directory
      :desc "Open directory" "o" #'dired
      :desc "Open directory (other window)" "O" #'dired-other-window
      :desc "Insert file" "i" #'insert-file
      :desc "Write region to file" "w" #'write-region)

;; ==================== 缓冲区管理快捷键 ====================

;; 增强的缓冲区管理
(map! :leader
      :prefix ("b" . "buffer")
      :desc "Switch buffer" "b" #'switch-to-buffer
      :desc "Switch buffer (other window)" "B" #'switch-to-buffer-other-window
      :desc "Next buffer" "n" #'next-buffer
      :desc "Previous buffer" "p" #'previous-buffer
      :desc "Kill buffer" "k" #'kill-this-buffer
      :desc "Kill other buffers" "K" #'kill-other-buffers
      :desc "Rename buffer" "r" #'rename-buffer
      :desc "Save buffer" "s" #'save-buffer
      :desc "Revert buffer" "R" #'revert-buffer
      :desc "Clone buffer" "c" #'clone-buffer
      :desc "Ibuffer" "i" #'ibuffer
      :desc "List buffers" "l" #'list-buffers
      :desc "Buffer menu" "m" #'buffer-menu)

;; ==================== 窗口管理快捷键 ====================

;; 增强的窗口管理
(map! :leader
      :prefix ("w" . "window")
      :desc "Delete window" "d" #'delete-window
      :desc "Delete other windows" "D" #'delete-other-windows
      :desc "Split window right" "v" #'split-window-right
      :desc "Split window below" "s" #'split-window-below
      :desc "Undo window config" "u" #'winner-undo
      :desc "Redo window config" "U" #'winner-redo
      :desc "Balance windows" "=" #'balance-windows
      :desc "Maximize window" "m" #'maximize-window
      :desc "Minimize window" "M" #'minimize-window
      :desc "Rotate windows" "r" #'rotate-windows
      :desc "Flip windows" "f" #'flip-windows
      :desc "Move window left" "h" #'windmove-left
      :desc "Move window down" "j" #'windmove-down
      :desc "Move window up" "k" #'windmove-up
      :desc "Move window right" "l" #'windmove-right)

;; ==================== 搜索和跳转快捷键 ====================

;; 增强的搜索和跳转
(map! :leader
      :prefix ("s" . "search")
      :desc "Search project" "s" #'projectile-ripgrep
      :desc "Search buffer" "b" #'swiper
      :desc "Search all buffers" "B" #'multi-swiper-all
      :desc "Search files" "f" #'counsel-find-file
      :desc "Search recent files" "r" #'counsel-recentf
      :desc "Search bookmarks" "m" #'counsel-bookmark
      :desc "Search imenu" "i" #'counsel-imenu
      :desc "Search outline" "o" #'counsel-outline
      :desc "Search line" "l" #'consult-line
      :desc "Jump to line" "j" #'goto-line
      :desc "Jump to char" "c" #'avy-goto-char
      :desc "Jump to word" "w" #'avy-goto-word-1
      :desc "Jump to line" "L" #'avy-goto-line)

;; ==================== Git 集成快捷键 ====================

;; magit 增强
(map! :leader
      :prefix ("g" . "git")
      :desc "Magit status" "s" #'magit-status
      :desc "Magit diff" "d" #'magit-diff
      :desc "Magit log" "l" #'magit-log
      :desc "Magit blame" "b" #'magit-blame
      :desc "Magit commit" "c" #'magit-commit
      :desc "Magit push" "p" #'magit-push
      :desc "Magit pull" "P" #'magit-pull
      :desc "Magit fetch" "f" #'magit-fetch
      :desc "Magit merge" "m" #'magit-merge
      :desc "Magit rebase" "r" #'magit-rebase
      :desc "Git gutter next hunk" "n" #'git-gutter:next-hunk
      :desc "Git gutter previous hunk" "p" #'git-gutter:previous-hunk
      :desc "Git gutter stage hunk" "s" #'git-gutter:stage-hunk
      :desc "Git gutter revert hunk" "R" #'git-gutter:revert-hunk)

;; ==================== 调试和测试快捷键 ====================

;; 调试和测试
(map! :leader
      :prefix ("d" . "debug")
      :desc "Start debugging" "d" #'dap-debug
      :desc "Toggle breakpoint" "b" #'dap-breakpoint-toggle
      :desc "Continue" "c" #'dap-continue
      :desc "Step over" "n" #'dap-next
      :desc "Step into" "i" #'dap-step-in
      :desc "Step out" "o" #'dap-step-out
      :desc "Restart frame" "r" #'dap-restart-frame
      :desc "Evaluate expression" "e" #'dap-eval
      :desc "Evaluate region" "E" #'dap-eval-region
      :desc "Hydra debug" "h" #'dap-hydra
      :desc "Run test" "t" #'ert-run-tests-interactively
      :desc "Run test suite" "T" #'ert-run-tests-batch)

;; ==================== 帮助和文档快捷键 ====================

;; 帮助系统
(map! :leader
      :prefix ("h" . "help")
      :desc "Describe key" "k" #'describe-key
      :desc "Describe function" "f" #'describe-function
      :desc "Describe variable" "v" #'describe-variable
      :desc "Describe mode" "m" #'describe-mode
      :desc "Describe face" "F" #'describe-face
      :desc "Describe package" "p" #'describe-package
      :desc "Find manual" "M" #'info
      :desc "Apropos" "a" #'apropos
      :desc "Emacs tutorial" "t" #'help-with-tutorial
      :desc "Emacs manual" "e" #'info-emacs-manual
      :desc "Doom help" "d" #'doom/help
      :desc "Doom doctor" "D" #'doom/doctor)

;; ==================== 自定义功能快捷键 ====================

;; 自定义功能
(map! :leader
      :prefix ("x" . "custom")
      :desc "Reload Doom config" "r" #'doom/reload
      :desc "Sync Doom packages" "s" #'doom/sync
      :desc "Upgrade Doom" "u" #'doom/upgrade
      :desc "Toggle theme" "t" #'doom/toggle-theme
      :desc "Toggle line numbers" "l" #'doom/toggle-line-numbers
      :desc "Toggle indent guides" "i" #'highlight-indent-guides-mode
      :desc "Toggle whitespace" "w" #'whitespace-mode
      :desc "Toggle flycheck" "f" #'flycheck-mode
      :desc "Toggle company" "c" #'company-mode
      :desc "Toggle yasnippet" "y" #'yas-minor-mode)

;; ==================== 模式特定快捷键 ====================

;; org-mode 增强
(map! :map org-mode-map
      :localleader
      :prefix ("o" . "org")
      :desc "Org agenda" "a" #'org-agenda
      :desc "Org capture" "c" #'org-capture
      :desc "Org store link" "l" #'org-store-link
      :desc "Org insert link" "L" #'org-insert-link
      :desc "Org todo" "t" #'org-todo
      :desc "Org deadline" "d" #'org-deadline
      :desc "Org schedule" "s" #'org-schedule
      :desc "Org timestamp" "T" #'org-time-stamp
      :desc "Org export" "e" #'org-export-dispatch
      :desc "Org babel tangle" "b" #'org-babel-tangle
      :desc "Org babel execute" "B" #'org-babel-execute-buffer)

;; markdown-mode 增强
(map! :map markdown-mode-map
      :localleader
      :prefix ("m" . "markdown")
      :desc "Markdown preview" "p" #'markdown-preview
      :desc "Markdown export" "e" #'markdown-export
      :desc "Markdown toggle code" "c" #'markdown-toggle-code
      :desc "Markdown toggle gfm" "g" #'markdown-toggle-gfm
      :desc "Markdown insert link" "l" #'markdown-insert-link
      :desc "Markdown insert image" "i" #'markdown-insert-image
      :desc "Markdown move up" "k" #'markdown-move-up
      :desc "Markdown move down" "j" #'markdown-move-down)

;; ==================== 快速访问快捷键 ====================

;; 快速访问常用功能
(map! :leader
      :desc "Quick open config" "e c" (lambda () (interactive) (find-file "~/.config/doom/config.el"))
      :desc "Quick open