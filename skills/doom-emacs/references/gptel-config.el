;; gptel-config.el - GPTel AI 聊天配置示例
;; 保存到 ~/.config/doom/config.el 或添加到现有配置

(use-package! gptel
  :config
  ;; API 密钥配置（推荐使用环境变量）
  (setq! gptel-api-key (lambda () (getenv "DEEPSEEK_API_KEY")))
  
  ;; 模型配置
  (setq gptel-model 'deepseek-chat
        gptel-backend
        (gptel-make-openai "DeepSeek"
          :host "api.deepseek.com"
          :endpoint "/chat/completions"
          :stream t
          :key gptel-api-key
          :models '("deepseek-chat" "deepseek-coder"))))

;; ==================== 多提供商支持 ====================

(setq gptel-providers
      `((:name "DeepSeek"
         :key ,(lambda () (getenv "DEEPSEEK_API_KEY"))
         :host "api.deepseek.com"
         :models ("deepseek-chat" "deepseek-coder"))
        (:name "OpenAI"
         :key ,(lambda () (getenv "OPENAI_API_KEY"))
         :host "api.openai.com"
         :models ("gpt-4" "gpt-3.5-turbo"))
        (:name "Anthropic"
         :key ,(lambda () (getenv "ANTHROPIC_API_KEY"))
         :host "api.anthropic.com"
         :models ("claude-3-opus" "claude-3-sonnet"))
        (:name "Ollama"
         :key ,(lambda () "")
         :host "http://localhost:11434"
         :models ("llama2" "codellama" "mistral"))))

;; ==================== 自定义提示模板 ====================

(setq gptel-default-prompt
      "You are an expert programmer. Provide concise, accurate answers with code examples when relevant.")

;; 项目特定提示
(defun my/gptel-project-context ()
  "Add project context to gptel queries."
  (when-let ((project (project-current)))
    (concat "Project Context:\n"
            "• Root: " (project-root project) "\n"
            "• Language: " (or (projectile-project-type) "unknown") "\n"
            "• Files: " (mapconcat 'identity
                                  (mapcar 'file-relative-name
                                          (project-files project))
                                  ", "))))

(add-hook 'gptel-pre-send-hook #'my/gptel-project-context)

;; ==================== 快捷键配置 ====================

;; 全局 GPTel 快捷键
(map! :leader
      :prefix ("g" . "gptel")
      :desc "Open GPTel" "g" #'gptel
      :desc "Send region" "r" #'gptel-send-region
      :desc "Insert response" "i" #'gptel-insert-response
      :desc "Switch provider" "p" #'gptel-switch-provider
      :desc "Menu" "m" #'gptel-menu)

;; GPTel 模式内快捷键
(map! :map gptel-mode-map
      :localleader
      "s" #'gptel-send
      "k" #'gptel-kill-session
      "c" #'gptel-clear-context
      "t" #'my/tmux-capture-to-gptel
      "T" #'my/gptel-to-tmux)

;; ==================== 高级功能 ====================

;; 自动上下文管理
(defun my/gptel-auto-context ()
  "Automatically add relevant context to gptel queries."
  (let ((context ""))
    ;; 添加当前文件信息
    (when buffer-file-name
      (setq context (concat context "Current file: " buffer-file-name "\n")))
    
    ;; 添加错误信息（如果存在）
    (when (and (boundp 'flycheck-current-errors)
               flycheck-current-errors)
      (setq context (concat context "Errors:\n"
                           (mapconcat (lambda (err)
                                        (format "• %s" (flycheck-error-message err)))
                                      flycheck-current-errors "\n"))))
    
    ;; 添加编译输出（如果存在）
    (when (get-buffer "*compilation*")
      (with-current-buffer "*compilation*"
        (when (> (point-max) (point-min))
          (setq context (concat context "Compilation output (last 10 lines):\n"
                               (buffer-substring
                                (max (point-min) (- (point-max) 1000))
                                (point-max)))))))
    
    context))

(add-hook 'gptel-pre-send-hook #'my/gptel-auto-context)

;; ==================== 集成配置 ====================

;; 与 org-mode 集成
(defun my/org-to-gptel ()
  "Send org-mode content to gptel."
  (interactive)
  (when (derived-mode-p 'org-mode)
    (let ((content (buffer-substring-no-properties
                    (org-element-property :begin (org-element-at-point))
                    (org-element-property :end (org-element-at-point)))))
      (gptel)
      (insert content))))

;; 与 magit 集成
(defun my/git-diff-to-gptel ()
  "Send git diff to gptel for review."
  (interactive)
  (let ((diff (shell-command-to-string "git diff HEAD~1 HEAD")))
    (gptel)
    (insert "Please review this git diff:\n\n" diff)))

;; ==================== 性能优化 ====================

;; 限制上下文长度
(setq gptel-max-tokens 4000
      gptel-context-length 2000)

;; 缓存配置
(setq gptel-use-cache t
      gptel-cache-directory (expand-file-name "gptel-cache" doom-cache-dir))

;; ==================== 主题和外观 ====================

;; 自定义 GPTel 缓冲区外观
(setq gptel-header-line-format " 🤖 GPTel AI Assistant"
      gptel-model-display-name "DeepSeek Chat")

;; 语法高亮
(add-hook 'gptel-mode-hook #'rainbow-delimiters-mode)

;; ==================== 调试配置 ====================

;; 启用调试日志
(setq gptel-log-level 'debug)

;; 查看连接状态
(defun my/gptel-status ()
  "Check gptel connection status."
  (interactive)
  (message "GPTel providers: %s" (mapcar 'car gptel-providers)))

;; ==================== 团队配置 ====================

;; 团队共享配置
(defvar my/team-gptel-config
  '((:name "Team DeepSeek"
     :key ,(lambda () (getenv "TEAM_DEEPSEEK_API_KEY"))
     :host "api.deepseek.com"
     :models ("deepseek-chat" "deepseek-coder"))
    (:name "Team OpenAI"
     :key ,(lambda () (getenv "TEAM_OPENAI_API_KEY"))
     :host "api.openai.com"
     :models ("gpt-4-turbo")))
  "Team shared GPTel configuration.")

;; 加载团队配置
(when (getenv "TEAM_MODE")
  (setq gptel-providers my/team-gptel-config))

;; ==================== 使用示例 ====================

;; 示例：代码审查
(defun my/code-review-with-gptel ()
  "Send current function for code review."
  (interactive)
  (let ((func (thing-at-point 'defun t)))
    (gptel)
    (insert "Please review this code for style, performance, and potential bugs:\n\n"
            func
            "\n\nFocus on:\n1. Code style and conventions\n2. Performance optimizations\n3. Potential bugs or edge cases\n4. Security considerations")))

;; 示例：错误分析
(defun my/analyze-error-with-gptel ()
  "Send compilation error to gptel for analysis."
  (interactive)
  (let ((error (thing-at-point 'line t)))
    (gptel)
    (insert "I'm getting this compilation error. Can you help me understand and fix it?\n\n"
            error
            "\n\nThe code context is a " (symbol-name major-mode) " file.")))

;; 绑定到快捷键
(map! :leader
      :prefix ("g" . "gptel")
      :desc "Code review" "c" #'my/code-review-with-gptel
      :desc "Analyze error" "e" #'my/analyze-error-with-gptel)