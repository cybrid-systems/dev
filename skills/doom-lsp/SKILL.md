---
name: doom-lsp
description: Configure, use, and troubleshoot Language Server Protocol (LSP) in Doom Emacs. Use when setting up LSP for programming languages (C/C++, Python, Rust, JavaScript, etc.), debugging LSP issues, optimizing performance, configuring language servers (clangd, pyright, rust-analyzer), or working with LSP features like code completion, navigation, refactoring, and diagnostics. Also use for tree-sitter integration, compile commands, and multi-language project setup.
---

# Doom Emacs LSP Skill

Complete guide to Language Server Protocol in Doom Emacs. Transform Emacs into a modern IDE with intelligent code completion, navigation, refactoring, and diagnostics.

## Quick Start

### Enable LSP in Doom

In `~/.config/emacs/init.el` or via doom CLI:

```elisp
;; Enable LSP module
:tools lsp

;; Enable LSP for specific languages
:lang (cc +lsp)        ; C/C++ with LSP
:lang (python +lsp)    ; Python with LSP  
:lang (rust +lsp)      ; Rust with LSP
:lang (javascript +lsp) ; JavaScript/TypeScript with LSP
:lang (go +lsp)        ; Go with LSP
:lang (java +lsp)      ; Java with LSP
```

Sync Doom after changes:
```bash
doom sync
doom upgrade
```

### Basic Configuration

Add to `~/.config/doom/config.el`:

```elisp
;; Global LSP settings
(setq lsp-auto-guess-root t      ; Auto-detect project root
      lsp-log-io nil             ; Disable verbose logging
      lsp-enable-symbol-highlighting t
      lsp-enable-on-type-formatting t
      lsp-enable-indentation t
      lsp-enable-snippet t
      lsp-enable-file-watchers t
      lsp-enable-text-document-color t)

;; Performance optimizations
(setq lsp-idle-delay 0.5
      lsp-response-timeout 10
      lsp-restart 'auto-restart
      lsp-completion-provider :capf)
```

## Language-Specific Configuration

### C/C++ (clangd)

```elisp
;; clangd configuration
(setq lsp-clients-clangd-args '("--background-index"
                                "--clang-tidy"
                                "--completion-style=detailed"
                                "--header-insertion=never"
                                "--header-insertion-decorators=0"
                                "--pch-storage=memory"
                                "--log=error"))

;; Set clangd priority
(after! lsp-clangd
  (set-lsp-priority! 'clangd 2))

;; Compilation database
(setq lsp-cpp-compilation-database-directory "build/"
      lsp-cpp-cache-directory ".cache/clangd/")

;; C++ standards
(setq lsp-clients-clangd-args '("-std=c++20"  ; or c++17, c++14
                                ...))
```

### Python (pyright/pylsp)

```elisp
;; pyright (Microsoft)
(setq lsp-pyright-venv-path "~/.virtualenvs/"
      lsp-pyright-extra-paths '()
      lsp-pyright-use-library-code-for-types t
      lsp-pyright-auto-import-completions t)

;; pylsp (Python Language Server)
(setq lsp-pylsp-plugins-pydocstyle-enabled nil
      lsp-pylsp-plugins-pyflakes-enabled t
      lsp-pylsp-plugins-mccabe-enabled nil
      lsp-pylsp-plugins-pycodestyle-enabled t
      lsp-pylsp-plugins-autopep8-enabled t)

;; Jedi (alternative)
(setq lsp-python-ms-auto-install-server t)
```

### Rust (rust-analyzer)

```elisp
;; rust-analyzer
(setq lsp-rust-analyzer-server-display-inlay-hints t
      lsp-rust-analyzer-inlay-hints-mode t
      lsp-rust-analyzer-cargo-watch-command "clippy"
      lsp-rust-analyzer-proc-macro-enable t
      lsp-rust-analyzer-cargo-load-out-dirs-from-check t
      lsp-rust-analyzer-cargo-autoreload t)

;; Cargo.toml support
(add-hook 'toml-mode-hook #'lsp!)
```

### JavaScript/TypeScript

```elisp
;; TypeScript/JavaScript
(setq lsp-typescript-preferences '(:includeCompletionsForModuleExports t
                                   :includeCompletionsWithInsertText t
                                   :allowTextChangesInNewFiles t
                                   :importModuleSpecifierPreference "relative"
                                   :quoteStyle "single")
      lsp-typescript-format-enable t
      lsp-typescript-format-insert-space-after-opening-and-before-closing-jsx-expression-braces t
      lsp-typescript-suggest-auto-imports t
      lsp-typescript-suggest-complete-jSDocs t)

;; Node.js
(setq lsp-clients-typescript-node-executable "node"
      lsp-clients-typescript-server-args '("--stdio"))
```

### Go (gopls)

```elisp
;; gopls configuration
(setq lsp-go-analyses '((staticcheck . t)
                        (unusedparams . t)
                        (unusedwrite . t)
                        (useany . t))
      lsp-go-gofumpt t
      lsp-go-build-flags '()
      lsp-go-alternate-tools '()
      lsp-go-codelens '((gc-details . t)
                        (test . t)))
```

### Java (eclipse.jdt.ls)

```elisp
;; Java Language Server
(setq lsp-java-vmargs '("-Xmx4G" "-XX:+UseG1GC" "-XX:+UseStringDeduplication")
      lsp-java-workspace-dir "~/.cache/jdtls-workspace/"
      lsp-java-import-gradle-enabled t
      lsp-java-import-maven-enabled t
      lsp-java-autobuild-enabled t
      lsp-java-save-actions-organize-imports t
      lsp-java-completion-guess-method-arguments t)
```

## Keybindings Reference

### Global LSP Keybindings

| Keybinding | Command | Description |
|------------|---------|-------------|
| `SPC m` | `lsp` | Open LSP menu |
| `SPC c a` | `lsp-execute-code-action` | Execute code action |
| `SPC c f` | `lsp-format-buffer` | Format buffer |
| `SPC c r` | `lsp-rename` | Rename symbol |
| `SPC c o` | `lsp-organize-imports` | Organize imports |
| `SPC c d` | `lsp-find-definition` | Go to definition |
| `SPC c r` | `lsp-find-references` | Find references |
| `SPC c i` | `lsp-find-implementation` | Find implementations |
| `SPC c t` | `lsp-find-type-definition` | Find type definition |
| `SPC c h` | `lsp-describe-thing-at-point` | Describe symbol |
| `SPC c s` | `lsp-signature-help` | Signature help |
| `SPC c e` | `lsp-treemacs-errors-list` | Show errors |

### Evil Mode Keybindings (Vim-style)

| Keybinding | Command | Description |
|------------|---------|-------------|
| `g d` | `lsp-find-definition` | Go to definition |
| `g r` | `lsp-find-references` | Find references |
| `g i` | `lsp-find-implementation` | Find implementations |
| `g t` | `lsp-find-type-definition` | Find type definition |
| `K` | `lsp-describe-thing-at-point` | Documentation |
| `[ d` | `lsp-goto-prev-diagnostic` | Previous diagnostic |
| `] d` | `lsp-goto-next-diagnostic` | Next diagnostic |
| `[ e` | `lsp-treemacs-errors-list` | Error list |

### Completion & Navigation

| Keybinding | Command | Description |
|------------|---------|-------------|
| `TAB` | `company-complete` | Code completion |
| `M-.` | `xref-find-definitions` | Find definition |
| `M-,` | `xref-pop-marker-stack` | Go back |
| `M-?` | `xref-find-references` | Find references |
| `C-c C-d` | `lsp-describe-thing-at-point` | Documentation |

## Advanced Features

### Tree-sitter Integration

```elisp
;; Enable tree-sitter for better syntax highlighting
(setq treesit-language-source-alist
      '((c . ("https://github.com/tree-sitter/tree-sitter-c" "v0.23.6"))
        (cpp . ("https://github.com/tree-sitter/tree-sitter-cpp" "v0.23.4"))
        (python . ("https://github.com/tree-sitter/tree-sitter-python" "v0.23.1"))
        (rust . ("https://github.com/tree-sitter/tree-sitter-rust" "v0.23.1"))
        (javascript . ("https://github.com/tree-sitter/tree-sitter-javascript" "v0.23.1"))
        (typescript . ("https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.1"))
        (go . ("https://github.com/tree-sitter/tree-sitter-go" "v0.23.1"))
        (java . ("https://github.com/tree-sitter/tree-sitter-java" "v0.23.1"))))

;; Install tree-sitter grammars
(mapc #'treesit-install-language-grammar (mapcar #'car treesit-language-source-alist))
```

### Compilation Database

For C/C++ projects, LSP needs `compile_commands.json`:

```elisp
;; Auto-generate compile commands
(defun my/generate-compile-commands ()
  "Generate compile_commands.json for current project."
  (interactive)
  (cond
   ((file-exists-p "CMakeLists.txt")
    (shell-command "cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -B build"))
   ((file-exists-p "Makefile")
    (shell-command "bear -- make"))
   ((file-exists-p "meson.build")
    (shell-command "meson compile_commands.json"))
   (t
    (message "No build system detected"))))

;; Set compile commands directory
(setq lsp-cpp-compilation-database-directory "build/")
```

### Multi-root Workspaces

```elisp
;; Configure multi-root projects
(setq lsp-multi-root-settings nil)  ; Auto-detect

;; Manual workspace configuration
(lsp-workspace-folders-add "~/projects/frontend")
(lsp-workspace-folders-add "~/projects/backend")
(lsp-workspace-folders-add "~/projects/shared")

;; Project-specific settings
(defun my/project-lsp-setup ()
  "Project-specific LSP configuration."
  (when (string-match-p "my-project" (projectile-project-root))
    (setq-local lsp-clients-clangd-args '("--background-index"
                                          "--clang-tidy"
                                          "-std=c++20"))
    (setq-local lsp-cpp-compilation-database-directory "build/")))

(add-hook 'lsp-mode-hook 'my/project-lsp-setup)
```

### Inlay Hints & UI Enhancements

```elisp
;; Enable inlay hints
(setq lsp-inlay-hint-enable t
      lsp-inlay-hint-mode t
      lsp-inlay-hint-font-face 'font-lock-comment-face
      lsp-inlay-hint-padding t)

;; UI enhancements
(setq lsp-headerline-breadcrumb-enable t
      lsp-headerline-breadcrumb-segments '(path-up-to-project file symbols)
      lsp-modeline-code-actions-enable t
      lsp-modeline-diagnostics-enable t
      lsp-signature-auto-activate t
      lsp-signature-render-documentation t)

;; Code lens
(setq lsp-lens-enable t
      lsp-lens-debounce-interval 0.5)
```

## Troubleshooting

### Common Issues & Solutions

#### 1. LSP Server Not Starting

**Symptoms**: No completion, no diagnostics, "No LSP server" message

**Diagnosis**:
```elisp
;; Check if LSP is enabled
M-x lsp-describe-session

;; Check server status
M-x lsp-workspace-show-log

;; List available servers
M-x lsp-installed-servers
```

**Solutions**:
- Install language server: `npm install -g typescript-language-server`
- Check PATH: `M-x getenv RET PATH`
- Enable language module: `:lang (python +lsp)`
- Run `doom sync`

#### 2. Slow Performance

**Symptoms**: Laggy completion, high CPU usage

**Optimizations**:
```elisp
;; Reduce logging
(setq lsp-log-io nil
      lsp-print-performance nil
      lsp-completion-no-filter t)

;; Increase timeouts
(setq lsp-idle-delay 1.0
      lsp-response-timeout 15
      lsp-completion-timeout 0.5)

;; Disable heavy features
(setq lsp-enable-file-watchers nil
      lsp-enable-symbol-highlighting nil
      lsp-enable-on-type-formatting nil)

;; Limit workspace size
(setq lsp-file-watch-threshold 1000)
```

#### 3. No Code Completion

**Symptoms**: TAB does nothing, no suggestions

**Check**:
```elisp
;; Verify completion backend
M-x describe-variable RET completion-at-point-functions

;; Test company-mode
M-x company-complete

;; Check LSP capabilities
M-x lsp-describe-session
```

**Solutions**:
- Enable company-mode: `:completion company`
- Or enable corfu: `:completion corfu`
- Check LSP server capabilities
- Ensure project is properly indexed

#### 4. Jump-to-Definition Not Working

**Symptoms**: `g d` does nothing or goes to wrong place

**Diagnosis**:
```elisp
;; Check xref backend
M-x describe-variable RET xref-backend-functions

;; Test xref directly
M-x xref-find-definitions
```

**Solutions**:
- Generate compile_commands.json for C/C++
- Ensure project has proper build setup
- Check LSP server supports definition provider
- Clear LSP cache: `M-x lsp-workspace-restart`

#### 5. Diagnostics Not Showing

**Symptoms**: No error highlighting, no flycheck messages

**Check**:
```elisp
;; Verify diagnostics provider
M-x describe-variable RET lsp-diagnostics-provider

;; Check flycheck
M-x flycheck-list-errors

;; Test LSP diagnostics
M-x lsp-treemacs-errors-list
```

**Solutions**:
- Enable diagnostics: `(setq lsp-diagnostics-provider :flycheck)`
- Or use lsp-ui: `(setq lsp-diagnostics-provider :lsp-ui)`
- Check server supports diagnostics
- Increase diagnostic delay: `(setq lsp-diagnostics-delay 1.0)`

### Debug Mode

Enable detailed debugging:

```elisp
;; Full debug logging
(setq lsp-log-io t
      lsp-print-performance t
      lsp-trace t
      lsp-print-io t
      lsp-inhibit-message t)

;; View logs
M-x lsp-workspace-show-log
M-x lsp-log-io-mode

;; Profile performance
M-x profiler-start
M-x profiler-report
```

### Server-Specific Issues

#### clangd Issues
```bash
# Check clangd installation
which clangd
clangd --version

# Generate compile_commands.json
bear -- make
# or
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 .

# Test clangd manually
clangd --check=/path/to/file.cpp
```

#### pyright Issues
```bash
# Install pyright
pip install pyright
# or
npm install -g pyright

# Check Python environment
python --version
which python
```

#### rust-analyzer Issues
```bash
# Update rust-analyzer
rustup update
rustup component add rust-analyzer

# Check cargo
cargo --version
cargo check
```

## Performance Tuning

### Memory Optimization

```elisp
;; Reduce memory usage
(setq gc-cons-threshold (* 100 1024 1024)  ; 100MB
      read-process-output-max (* 1024 1024) ; 1MB
      lsp-idle-delay 1.0
      lsp-response-timeout 10
      lsp-completion-no-filter t
      lsp-enable-symbol-highlighting nil
      lsp-enable-file-watchers nil
      lsp-enable-on-type-formatting nil)

;; Clean up old workspaces
(defun my/lsp-cleanup ()
  "Clean up unused LSP workspaces."
  (interactive)
  (dolist (workspace (lsp-workspaces))
    (unless (lsp--workspace-buffers workspace)
      (lsp-workspace-shutdown workspace))))
```

### Startup Optimization

```elisp
;; Defer LSP startup
(setq lsp-auto-configure t
      lsp-auto-require-clients nil
      lsp-restart 'auto-restart
      lsp-start-plaintext t)

;;