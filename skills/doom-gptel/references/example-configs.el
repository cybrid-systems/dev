;; Example gptel configurations for Doom Emacs
;; Copy relevant sections to ~/.config/doom/config.el

;; ============================================================================
;; BASIC DEEPSEEK SETUP (Recommended)
;; ============================================================================

(use-package! gptel
  :config
  (setq! gptel-api-key "your-deepseek-api-key-here"))

(setq gptel-model 'deepseek-chat
      gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :endpoint "/chat/completions"
        :stream t
        :key gptel-api-key
        :models '("deepseek-chat" "deepseek-coder")))

;; Optional: Post-processing for LaTeX math
(defun my/fix-latex-delimiters ()
  "Replace LaTeX delimiters with Markdown math."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "\\\\(" nil t) (replace-match "$"))
    (goto-char (point-min))
    (while (re-search-forward "\\\\)" nil t) (replace-match "$"))
    (goto-char (point-min))
    (while (re-search-forward "\\\\\\[" nil t) (replace-match "$$"))
    (goto-char (point-min))
    (while (re-search-forward "\\\\\\]" nil t) (replace-match "$$"))))

(add-hook 'gptel-post-response-functions 'my/fix-latex-delimiters)

;; ============================================================================
;; MULTI-PROVIDER SETUP
;; ============================================================================

(defvar my/deepseek-key "sk-deepseek-key")
(defvar my/openai-key "sk-openai-key")
(defvar my/anthropic-key (getenv "ANTHROPIC_API_KEY"))

(setq gptel-backends
      `(("DeepSeek" . ,(gptel-make-openai "DeepSeek"
                        :host "api.deepseek.com"
                        :key my/deepseek-key
                        :models '("deepseek-chat" "deepseek-coder")))
        ("OpenAI" . ,(gptel-make-openai "OpenAI"
                       :key my/openai-key
                       :models '("gpt-4o" "gpt-4-turbo" "gpt-3.5-turbo")))
        ("Claude" . ,(gptel-make-anthropic "Claude"
                        :key my/anthropic-key
                        :models '("claude-3-5-sonnet" "claude-3-opus")))))

(setq gptel-backend (alist-get "DeepSeek" gptel-backends nil nil 'equal))

(defun my/switch-gptel-backend ()
  "Interactively switch gptel backend."
  (interactive)
  (let ((backend-name (completing-read "Select AI provider: "
                                       (mapcar 'car gptel-backends))))
    (setq gptel-backend (alist-get backend-name gptel-backends nil nil 'equal))
    (message "Switched to %s" backend-name)))

;; Keybinding to switch backends
(map! :leader
      :desc "Switch AI provider" "o s" #'my/switch-gptel-backend)

;; ============================================================================
;; ENVIRONMENT VARIABLE SETUP (Secure)
;; ============================================================================

;; Set environment variables in shell:
;; export DEEPSEEK_API_KEY="sk-your-key"
;; export OPENAI_API_KEY="sk-your-key"

(setq gptel-api-key (getenv "DEEPSEEK_API_KEY"))

(setq gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :key (getenv "DEEPSEEK_API_KEY")
        :models '("deepseek-chat")))

;; ============================================================================
;; AUTH-SOURCE SETUP (Most Secure)
;; ============================================================================

;; Create ~/.authinfo.gpg with:
;; machine api.deepseek.com login api password sk-your-key

(setq gptel-api-key
      (lambda ()
        (auth-source-pick-first-password :host "api.deepseek.com")))

(setq gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :key gptel-api-key
        :models '("deepseek-chat")))

;; ============================================================================
;; CONTEXT-AWARE CONFIGURATION
;; ============================================================================

(defun my/smart-gptel-setup ()
  "Set up gptel based on context."
  (cond
   ;; Programming buffers use coder model
   ((derived-mode-p 'prog-mode)
    (setq-local gptel-model 'deepseek-coder))
   
   ;; Writing buffers use chat model
   ((derived-mode-p 'text-mode 'org-mode 'markdown-mode)
    (setq-local gptel-model 'deepseek-chat))
   
   ;; Default
   (t
    (setq-local gptel-model 'deepseek-chat))))

(add-hook 'gptel-mode-hook 'my/smart-gptel-setup)

;; ============================================================================
;; ADVANCED FEATURES
;; ============================================================================

;; 1. Custom keybindings
(map! :map gptel-mode-map
      "C-c C-s" #'gptel-send
      "C-c C-q" #'gptel-quit
      "C-c C-k" #'gptel-kill
      "C-c C-l" #'gptel-clear)

(map! :leader
      :prefix ("o" . "open")
      :desc "Start gptel" "a" #'gptel
      :desc "Quick gptel" "q" (lambda () (interactive) (gptel t)))

;; 2. Custom prompt templates
(setq gptel-prompt-alist
      '((code . "You are an expert programmer. Provide concise, correct code solutions.")
        (write . "You are a writing assistant. Help improve clarity and style.")
        (debug . "You are a debugging assistant. Analyze code and suggest fixes.")
        (learn . "You are a patient teacher. Explain concepts clearly with examples.")))

(defun my/gptel-with-prompt (prompt)
  "Start gptel with specific prompt."
  (interactive
   (list (completing-read "Select prompt: "
                          (mapcar 'car gptel-prompt-alist))))
  (let ((gptel-system-message (alist-get prompt gptel-prompt-alist)))
    (gptel)))

;; 3. Conversation management
(defun my/save-gptel-conversation ()
  "Save current gptel conversation to file."
  (interactive)
  (let ((filename (read-file-name "Save conversation to: ")))
    (with-current-buffer (gptel-buffer)
      (write-file filename))
    (message "Conversation saved to %s" filename)))

(defun my/load-gptel-conversation ()
  "Load gptel conversation from file."
  (interactive)
  (let ((filename (read-file-name "Load conversation from: ")))
    (gptel)
    (with-current-buffer (gptel-buffer)
      (erase-buffer)
      (insert-file-contents filename))
    (message "Conversation loaded from %s" filename)))

;; 4. Integration with other packages
(after! org
  (defun my/org-gptel-help ()
    "Get gptel help for current org heading."
    (interactive)
    (let ((heading (org-get-heading t t)))
      (gptel)
      (insert (format "Help me with this org-mode heading: %s\n\n" heading)))))

(after! magit
  (defun my/magit-gptel-commit ()
    "Use gptel to write commit message."
    (interactive)
    (let ((diff (shell-command-to-string "git diff --cached")))
      (gptel)
      (insert (format "Write a commit message for these changes:\n\n%s" diff)))))

;; ============================================================================
;; PERFORMANCE OPTIMIZATIONS
;; ============================================================================

;; Reduce memory usage
(setq gptel-max-entries 100      ; Keep last 100 messages
      gptel-max-tokens 4096      ; Limit context size
      gptel-temperature 0.7      ; Balance creativity/consistency
      gptel-log-level 'warn)     ; Reduce logging

;; Cache responses
(defvar my/gptel-cache (make-hash-table :test 'equal))

(defun my/gptel-cached-request (prompt callback)
  "Cache gptel responses."
  (let ((cached (gethash prompt my/gptel-cache)))
    (if cached
        (funcall callback cached)
      (gptel-request prompt
        (lambda (response)
          (puthash prompt response my/gptel-cache)
          (funcall callback response))))))

;; ============================================================================
;; MINIMAL WORKING EXAMPLE
;; ============================================================================

;; Absolute minimum config that should work:
;;
;; (setq gptel-api-key "sk-your-deepseek-key")
;; (setq gptel-backend
;;       (gptel-make-openai "DeepSeek"
;;         :host "api.deepseek.com"
;;         :key gptel-api-key))
;;
;; Then: M-x gptel

;; ============================================================================
;; TROUBLESHOOTING CONFIG
;; ============================================================================

;; Enable debug mode when having issues
(defun my/enable-gptel-debug ()
  "Enable gptel debug mode."
  (interactive)
  (setq gptel-log-level 'debug
        gptel-log-requests t
        gptel-log-responses t)
  (message "gptel debug mode enabled"))

(defun my/disable-gptel-debug ()
  "Disable gptel debug mode."
  (interactive)
  (setq gptel-log-level 'warn
        gptel-log-requests nil
        gptel-log-responses nil)
  (message "gptel debug mode disabled"))

;; Test configuration
(defun my/test-gptel-config ()
  "Test gptel configuration."
  (interactive)
  (message "=== gptel Configuration Test ===")
  (message "API Key: %s" (if (and (boundp 'gptel-api-key) gptel-api-key) "SET" "NOT SET"))
  (message "Backend: %s" (if (and (boundp 'gptel-backend) gptel-backend) "SET" "NOT SET"))
  (message "Model: %s" (if (boundp 'gptel-model) gptel-model "NOT SET"))
  (message "=== Test Complete ==="))

;; Quick test command
(map! :leader
      :desc "Test gptel config" "o t" #'my/test-gptel-config)