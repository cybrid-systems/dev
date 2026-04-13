# LSP Troubleshooting Guide

## Quick Diagnosis Commands

### Check LSP Status
```elisp
;; Basic status checks
M-x lsp-describe-session           ; Show current LSP session
M-x lsp-workspace-folders          ; List workspace folders
M-x lsp-workspace-show-log         ; View server logs
M-x lsp-installed-servers          ; List available servers
M-x lsp-check-health               ; Run health checks
```

### Debug Information
```elisp
;; Get debug info
M-x lsp-debug-info                 ; Comprehensive debug info
M-x lsp-log-io-mode                ; Toggle IO logging
M-x profiler-start                 ; Start performance profiling
M-x profiler-report                ; Show profiling results
```

## Common Issues & Solutions

### 1. "No LSP server for this buffer"

**Symptoms**: Buffer shows no LSP features, `lsp-describe-session` shows no server

**Diagnosis**:
```elisp
;; Check major mode
M-x describe-mode

;; Check lsp-mode
M-x describe-variable RET lsp-mode

;; Check enabled clients
M-x describe-variable RET lsp-enabled-clients

;; Check server registration
M-x lsp-registered-clients
```

**Solutions**:

**A. Language module not enabled**:
```elisp
;; In init.el, ensure language has +lsp flag
:lang (cc +lsp)        ; C/C++
:lang (python +lsp)    ; Python
:lang (rust +lsp)      ; Rust
```

**B. Server not installed**:
```bash
# C/C++ - clangd
sudo apt install clangd-15

# Python - pyright
pip install pyright

# Rust - rust-analyzer
rustup component add rust-analyzer

# TypeScript
npm install -g typescript-language-server
```

**C. Server not in PATH**:
```elisp
;; Add to PATH in config.el
(setenv "PATH" (concat (getenv "PATH") ":/usr/local/bin"))
(setq exec-path (append exec-path '("/usr/local/bin")))

;; Or specify server path directly
(setq lsp-clients-clangd-executable "/usr/bin/clangd")
```

**D. Wrong major mode**:
```elisp
;; Force lsp-mode
(add-hook 'c-mode-hook #'lsp)
(add-hook 'c++-mode-hook #'lsp)
(add-hook 'python-mode-hook #'lsp)
```

### 2. Slow Performance / High CPU

**Symptoms**: Laggy completion, Emacs freezes, high CPU usage

**Diagnosis**:
```elisp
;; Check CPU usage
M-x list-processes

;; Check memory
M-x memory-report

;; Profile LSP
M-x lsp-log-io-mode
M-x profiler-start
```

**Optimizations**:

**A. Reduce logging**:
```elisp
(setq lsp-log-io nil
      lsp-print-performance nil
      lsp-trace nil
      lsp-print-io nil
      lsp-inhibit-message t
      lsp-signature-auto-activate nil)
```

**B. Increase timeouts**:
```elisp
(setq lsp-idle-delay 1.0          ; Default 0.5
      lsp-response-timeout 15     ; Default 10
      lsp-completion-timeout 0.5  ; Default 0.2
      lsp-diagnostics-delay 1.0)  ; Default 0.5
```

**C. Disable heavy features**:
```elisp
(setq lsp-enable-file-watchers nil
      lsp-enable-symbol-highlighting nil
      lsp-enable-on-type-formatting nil
      lsp-enable-text-document-color nil
      lsp-lens-enable nil
      lsp-headerline-breadcrumb-enable nil
      lsp-modeline-code-actions-enable nil)
```

**D. Limit workspace size**:
```elisp
(setq lsp-file-watch-threshold 1000)  ; Default 2000
```

**E. Project-specific exclusions**:
```elisp
(setq lsp-file-watch-ignored-directories
      '("[/\\\\]\\.git$"
        "[/\\\\]\\.hg$"
        "[/\\\\]\\.svn$"
        "[/\\\\]\\.idea$"
        "[/\\\\]\\.vscode$"
        "[/\\\\]build$"
        "[/\\\\]node_modules$"
        "[/\\\\]__pycache__$"))
```

### 3. No Code Completion

**Symptoms**: TAB does nothing, no suggestions appear

**Diagnosis**:
```elisp
;; Check completion backend
M-x describe-variable RET completion-at-point-functions

;; Test company-mode
M-x company-complete

;; Check LSP capabilities
M-x lsp-describe-session
M-x lsp-capabilities
```

**Solutions**:

**A. Enable completion backend**:
```elisp
;; Company-mode (default)
:completion company

;; Or corfu
:completion corfu

;; Ensure completion is configured
(setq company-idle-delay 0.5
      company-minimum-prefix-length 2
      company-tooltip-limit 20)
```

**B. Check LSP completion provider**:
```elisp
(setq lsp-completion-provider :capf)  ; Default
;; or
(setq lsp-completion-provider :company)
```

**C. Server-specific issues**:
```elisp
;; For clangd
(setq lsp-clients-clangd-args '("--completion-style=detailed"))

;; For rust-analyzer
(setq lsp-rust-analyzer-completion-add-call-parenthesis t
      lsp-rust-analyzer-completion-add-call-argument-snippets t)
```

**D. Clear completion cache**:
```elisp
M-x company-diag
M-x company-cleanup
```

### 4. Jump-to-Definition Not Working

**Symptoms**: `g d` or `M-.` does nothing or goes to wrong place

**Diagnosis**:
```elisp
;; Check xref backend
M-x describe-variable RET xref-backend-functions

;; Test xref directly
M-x xref-find-definitions

;; Check LSP capabilities
M-x lsp-capabilities
```

**Solutions**:

**A. C/C++: Missing compile_commands.json**:
```bash
# Generate compile commands
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -B build
# or
bear -- make

# Set path in Emacs
(setq lsp-cpp-compilation-database-directory "build/")
```

**B. Python: Virtual environment**:
```elisp
;; Set Python path
(setq lsp-pyright-venv-path "~/.virtualenvs/"
      lsp-pyright-extra-paths '("./src"))
```

**C. Project root detection**:
```elisp
(setq lsp-auto-guess-root t
      lsp-project-roots '(".git" "CMakeLists.txt" "setup.py" "Cargo.toml"))

;; Manual root setting
(setq lsp-session-file (expand-file-name ".lsp-session-v1" (projectile-project-root)))
```

**D. Clear LSP cache**:
```elisp
M-x lsp-workspace-restart
M-x lsp-workspace-shutdown
```

### 5. Diagnostics Not Showing

**Symptoms**: No error highlighting, no flycheck messages

**Diagnosis**:
```elisp
;; Check diagnostics provider
M-x describe-variable RET lsp-diagnostics-provider

;; Check flycheck
M-x flycheck-list-errors
M-x flycheck-verify-setup

;; Test LSP diagnostics
M-x lsp-treemacs-errors-list
```

**Solutions**:

**A. Enable diagnostics provider**:
```elisp
;; Use flycheck (default)
(setq lsp-diagnostics-provider :flycheck)

;; Or lsp-ui
(setq lsp-diagnostics-provider :lsp-ui)

;; Ensure flycheck is enabled
:checkers syntax
```

**B. Configure diagnostics**:
```elisp
(setq lsp-diagnostics-enable t
      lsp-diagnostics-delay 1.0
      lsp-diagnostics-flycheck-default-level 'warning
      lsp-diagnostics-update-on-change t
      lsp-diagnostics-update-on-idle t)
```

**C. Server-specific diagnostics**:
```elisp
;; clangd
(setq lsp-clients-clangd-args '("--clang-tidy"))

;; pyright
(setq lsp-pyright-type-checking-mode "basic")

;; rust-analyzer
(setq lsp-rust-analyzer-diagnostics-disabled [])
```

**D. Check server capabilities**:
```elisp
M-x lsp-capabilities
;; Look for "diagnosticsProvider" or "publishDiagnostics"
```

### 6. Formatting Not Working

**Symptoms**: `SPC c f` does nothing, code not formatted

**Diagnosis**:
```elisp
;; Check formatting provider
M-x describe-variable RET lsp-format-on-type-enabled

;; Test formatting manually
M-x lsp-format-buffer
M-x lsp-format-region
```

**Solutions**:

**A. Enable formatting**:
```elisp
(setq lsp-enable-on-type-formatting t
      lsp-enable-indentation t
      lsp-format-on-type-enabled t
      lsp-format-on-save t)
```

**B. Server-specific formatting**:
```elisp
;; clangd
(setq lsp-clients-clangd-args '("--format-style=file"))

;; Python
(setq lsp-pylsp-plugins-autopep8-enabled t
      lsp-pylsp-plugins-black-enabled t)

;; JavaScript/TypeScript
(setq lsp-typescript-format-enable t
      lsp-javascript-format-enable t)
```

**C. Formatting tools**:
```bash
# Install formatters
pip install black autopep8
npm install -g prettier
rustup component add rustfmt
go install golang.org/x/tools/cmd/goimports@latest
```

### 7. High Memory Usage

**Symptoms**: Emacs uses excessive RAM, slows down over time

**Diagnosis**:
```elisp
M-x memory-report
M-x list-processes
```

**Solutions**:

**A. Reduce GC thresholds**:
```elisp
(setq gc-cons-threshold (* 100 1024 1024)   ; 100MB
      read-process-output-max (* 1024 1024) ; 1MB
      lsp-idle-delay 1.0)
```

**B. Limit LSP features**:
```elisp
(setq lsp-enable-file-watchers nil
      lsp-enable-symbol-highlighting nil
      lsp-enable-text-document-color nil
      lsp-lens-enable nil
      lsp-headerline-breadcrumb-enable nil)
```

**C. Clean up workspaces**:
```elisp
(defun my/lsp-cleanup ()
  "Clean up unused LSP workspaces."
  (interactive)
  (dolist (workspace (lsp-workspaces))
    (unless (lsp--workspace-buffers workspace)
      (lsp-workspace-shutdown workspace))))

;; Run periodically
(run-with-timer 3600 3600 'my/lsp-cleanup)  ; Every hour
```

**D. Project size limits**:
```elisp
(setq lsp-file-watch-threshold 500
      lsp-max-num-files-watched 100)
```

## Server-Specific Issues

### clangd Issues

**"Cannot find compile_commands.json"**:
```bash
# Generate compile commands
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -B build
# or
bear -- make

# Create .clangd config
echo "CompileFlags:
  Add: [-std=c++20, -I./include]
  CompilationDatabase: build/" > .clangd
```

**"Header not found"**:
```elisp
;; Add include paths
(setq lsp-clients-clangd-args
      '("--background-index"
        "-I/usr/local/include"
        "-I./third_party"
        "--query-driver=**"))
```

**Slow indexing**:
```elisp
(setq lsp-clients-clangd-args
      '("--background-index"
        "--pch-storage=memory"
        "--clang-tidy"
        "--completion-style=detailed"))
```

### pyright Issues

**"Import could not be resolved"**:
```elisp
;; Set Python path
(setq lsp-pyright-extra-paths
      '("./src" "../shared" "~/projects/common"))

;; Set virtual environment
(setq lsp-pyright-venv-path "~/.virtualenvs/")
```

**Slow type checking**:
```elisp
(setq lsp-pyright-type-checking-mode "off"  ; or "basic"
      lsp-pyright-analysis-type-checking-mode "basic"
      lsp-pyright-auto-search-paths nil)
```

### rust-analyzer Issues

**"Proc macro not expanded"**:
```elisp
(setq lsp-rust-analyzer-proc-macro-enable t
      lsp-rust-analyzer-cargo-load-out-dirs-from-check t)
```

**Slow completions**:
```elisp
(setq lsp-rust-analyzer-completion-auto-import-enable t
      lsp-rust-analyzer-lru-capacity 64
      lsp-rust-analyzer-cargo-watch-command "check")
```

### TypeScript Issues

**"Cannot find module"**:
```elisp
;; Set TypeScript SDK
(setq lsp-typescript-tsdk
      (concat (projectile-project-root) "node_modules/typescript/lib"))

;; Configure npm
(setq lsp-typescript-npm "~/.nvm/versions/node/*/bin/npm")
```

**Slow server**:
```elisp
(setq lsp-typescript-max-ts-server-memory 4096  ; 4GB
      lsp-typescript-format-enable nil
      lsp-typescript-suggest-complete-jSDocs nil)
```

## Debug Mode

### Enable Full Debugging
```elisp
;; Comprehensive debug settings
(setq lsp-log-io t
      lsp-print-performance t
      lsp-trace t
      lsp-print-io t
      lsp-inhibit-message nil
      lsp-echo-performance t
      debug-on-error t
      debug-on-quit t)

;; View debug info
M-x lsp-debug-info
M-x lsp-workspace-show-log
M-x lsp-log-io-mode
```

### Create Debug Report
```elisp
(defun my/lsp-debug-report ()
  "Generate comprehensive LSP debug report."
  (interactive)
  (let ((buffer (get-buffer-create "*LSP Debug Report*")))
    (with-current-buffer buffer
      (erase-buffer)
      (insert "=== LSP Debug Report ===\n\n")
      
      ;; System info
      (insert "## System Information\n")
      (insert (format "Emacs: %s\n" emacs-version))
      (insert (format "Doom: %s\n" (doom-version)))
      (insert (format "System: %s\n\n" system-type))
      
      ;; LSP configuration
      (insert "## LSP Configuration\n")
      (dolist (var '(lsp-mode
                     lsp-log-io
                     lsp-print-performance
                     lsp-diagnostics-provider
                     lsp-completion-provider
                     lsp-idle-delay))
        (insert (format "%s: %s\n" var (symbol-value var))))
      (insert "\n")
      
      ;; Workspace info
      (insert "## Workspaces\n")
      (dolist (workspace (lsp-workspaces))
        (insert (format "- %s: %s\n"
                        (lsp--workspace-print workspace)
                        (if (lsp--workspace-live-p workspace) "ALIVE" "DEAD"))))
      (insert "\n")
      
      ;; Server logs
      (insert "## Server Logs\n")
      (dolist (workspace (lsp-workspaces))
        (insert (format "=== %s ===\n" (lsp--workspace-print workspace)))
        (insert (lsp--workspace-log workspace) "\n\n"))
      
      (switch-to-buffer buffer))))
```

### Performance Profiling
```elisp
;; Profile LSP performance
(defun my/profile-lsp ()
  "Profile LSP performance."
  (interactive)
  (profiler-start 'cpu+mem)
  (message "Profiling started...")
  (run-with-timer 10 nil
                  (lambda ()
                    (profiler-stop)
                    (profiler-report)
                    (message "Profiling complete."))))
```

## Recovery Procedures

### Reset LSP Configuration
```elisp
(defun my/reset-lsp ()
  "Reset LSP configuration."
  (interactive)
  ;; Shutdown all workspaces
  (dolist (workspace (lsp-workspaces))
    (lsp-workspace-shutdown workspace))
  
  ;; Clear cache
  (when (file-exists-p lsp-session-file)
    (delete-file lsp-session-file))
  
  ;; Reset variables
  (setq lsp-mode nil
        lsp--cur-workspace nil
        lsp--managed-mode nil)
  
  (message "LSP reset complete. Restart Emacs for changes to take effect."))
```

### Clean LSP Cache
```bash
# Remove LSP cache directories
rm -rf ~/.emacs.d/.cache/lsp/
rm -rf ~/.cache/clangd/
rm -rf ~/.cache/jdtls-workspace/
rm -rf ~/.cache/pyright/
```

### Reinstall Servers
```elisp
(defun my/reinstall-lsp