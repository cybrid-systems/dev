# Language Server Configuration Guide

## C/C++ - clangd

### Installation
```bash
# Ubuntu/Debian
sudo apt-get install clangd-15 clang-tidy

# macOS
brew install llvm
ln -s "$(brew --prefix llvm)/bin/clangd" /usr/local/bin/clangd

# From source
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
cmake -S llvm -B build -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra"
cmake --build build --target clangd
```

### Configuration Files

#### .clangd (project-specific)
```yaml
CompileFlags:
  Add: [-std=c++20, -I./include, -I../shared/include]
  Remove: [-Wold-style-cast]
Diagnostics:
  UnusedIncludes: Strict
  MisleadingIndentation: false
Index:
  Background: Build
  TrackDependencies: true
```

#### compile_commands.json generation
```bash
# CMake
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -B build

# Make + bear
bear -- make -j$(nproc)

# Meson
meson setup build
meson compile -C build compile_commands.json

# Bazel
bazel build --experimental_action_listener=//tools/actions:generate_compile_commands //...

# Custom script
python scripts/generate_compile_commands.py
```

### Advanced clangd Settings
```elisp
;; Extended clangd configuration
(setq lsp-clients-clangd-args
      '("--background-index"
        "--clang-tidy"
        "--completion-style=detailed"
        "--header-insertion=never"
        "--header-insertion-decorators=0"
        "--pch-storage=memory"
        "--log=error"
        "--pretty"
        "--query-driver=**"
        "--all-scopes-completion"
        "--cross-file-rename"))

;; Project-specific settings
(defun my/cpp-project-setup ()
  (when (string-match-p "my-cpp-project" (projectile-project-root))
    (setq-local lsp-clients-clangd-args
                '("--background-index"
                  "--clang-tidy"
                  "--completion-style=detailed"
                  "-std=c++20"
                  "-I/usr/local/include"
                  "-I./third_party"))
    (setq-local lsp-cpp-compilation-database-directory "build/")))

(add-hook 'c++-mode-hook 'my/cpp-project-setup)
```

## Python - Multiple Servers

### pyright (Microsoft)
```bash
# Installation
pip install pyright
# or
npm install -g pyright
```

```elisp
;; pyright configuration
(setq lsp-pyright-venv-path "~/.virtualenvs/"
      lsp-pyright-extra-paths '()
      lsp-pyright-use-library-code-for-types t
      lsp-pyright-auto-import-completions t
      lsp-pyright-type-checking-mode "basic"
      lsp-pyright-analysis-type-checking-mode "basic"
      lsp-pyright-auto-search-paths t
      lsp-pyright-exclude '("**/node_modules" "**/__pycache__"))

;; pyproject.toml support
(setq lsp-pyright-python-executable-cmd "python"
      lsp-pyright-python-executable-args '())
```

### pylsp (Python Language Server)
```bash
pip install python-lsp-server
pip install python-lsp-server[all]  # All plugins
```

```elisp
;; pylsp configuration
(setq lsp-pylsp-plugins-pydocstyle-enabled nil
      lsp-pylsp-plugins-pyflakes-enabled t
      lsp-pylsp-plugins-mccabe-enabled nil
      lsp-pylsp-plugins-pycodestyle-enabled t
      lsp-pylsp-plugins-autopep8-enabled t
      lsp-pylsp-plugins-yapf-enabled nil
      lsp-pylsp-plugins-black-enabled t
      lsp-pylsp-plugins-pylint-enabled nil
      lsp-pylsp-plugins-flake8-enabled t
      lsp-pylsp-plugins-pylsp-mypy-enabled t)

;; Formatting configuration
(setq lsp-pylsp-plugins-autopep8-args '("--max-line-length=88")
      lsp-pylsp-plugins-black-args '("--line-length=88")
      lsp-pylsp-plugins-yapf-args '("--style={based_on_style: google, column_limit: 88}"))
```

### Jedi (alternative)
```elisp
(setq lsp-python-ms-auto-install-server t
      lsp-python-ms-executable "~/.emacs.d/.cache/lsp/python-ms/jedi-language-server"
      lsp-python-ms-extra-paths '()
      lsp-python-ms-completion-enabled t
      lsp-python-ms-rename-enabled t
      lsp-python-ms-signature-help-enabled t)
```

## Rust - rust-analyzer

### Installation
```bash
# Via rustup (recommended)
rustup component add rust-analyzer

# Manual installation
git clone https://github.com/rust-lang/rust-analyzer.git
cd rust-analyzer
cargo xtask install --server
```

### Configuration
```elisp
;; rust-analyzer settings
(setq lsp-rust-analyzer-server-display-inlay-hints t
      lsp-rust-analyzer-inlay-hints-mode t
      lsp-rust-analyzer-cargo-watch-command "clippy"
      lsp-rust-analyzer-proc-macro-enable t
      lsp-rust-analyzer-cargo-load-out-dirs-from-check t
      lsp-rust-analyzer-cargo-autoreload t
      lsp-rust-analyzer-lru-capacity 128
      lsp-rust-analyzer-diagnostics-disabled ["unresolved-proc-macro"]
      lsp-rust-analyzer-cargo-target-dir "target")

;; Inlay hints customization
(setq lsp-rust-analyzer-inlay-hints-chaining-hints t
      lsp-rust-analyzer-inlay-hints-parameter-hints t
      lsp-rust-analyzer-inlay-hints-type-hints t
      lsp-rust-analyzer-inlay-hints-closing-brace-hints t
      lsp-rust-analyzer-inlay-hints-lifetime-elision-hints "skip_trivial")

;; Cargo.toml support
(add-hook 'toml-mode-hook #'lsp!)
```

### Cargo.toml settings
```toml
[package.metadata.rust-analyzer]
# Enable proc macro support
procMacro.enable = true

# Configure diagnostics
diagnostics.disabled = ["unresolved-import"]

# Configure inlay hints
inlayHints.typeHints = true
inlayHints.parameterHints = true
inlayHints.chainingHints = true

# Configure cargo
cargo.loadOutDirsFromCheck = true
cargo.allFeatures = true
```

## JavaScript/TypeScript

### TypeScript Language Server
```bash
npm install -g typescript typescript-language-server
```

```elisp
;; TypeScript configuration
(setq lsp-typescript-preferences
      '(:includeCompletionsForModuleExports t
        :includeCompletionsWithInsertText t
        :allowTextChangesInNewFiles t
        :importModuleSpecifierPreference "relative"
        :quoteStyle "single"
        :preferConst true
        :allowSyntheticDefaultImports true
        :experimentalDecorators true
        :emitDecoratorMetadata true)
      lsp-typescript-format-enable t
      lsp-typescript-format-insert-space-after-opening-and-before-closing-jsx-expression-braces t
      lsp-typescript-suggest-auto-imports t
      lsp-typescript-suggest-complete-jSDocs t
      lsp-typescript-implementations-code-lens-enabled t
      lsp-typescript-references-code-lens-enabled t)

;; tsconfig.json detection
(setq lsp-typescript-tsdk (concat (projectile-project-root) "node_modules/typescript/lib")
      lsp-typescript-npm "~/.nvm/versions/node/*/bin/npm")

;; React support
(setq lsp-typescript-jsx "react"
      lsp-typescript-jsx-factory "React.createElement"
      lsp-typescript-jsx-fragment "React.Fragment")
```

### JavaScript configuration
```elisp
;; JavaScript settings
(setq lsp-javascript-preferences
      '(:quoteStyle "single"
        :importModuleSpecifier "relative"
        :allowSyntheticDefaultImports true)
      lsp-javascript-format-enable t
      lsp-javascript-suggest-auto-imports t
      lsp-javascript-suggest-complete-jSDocs t
      lsp-javascript-implementations-code-lens-enabled t)

;; Node.js version
(setq lsp-clients-typescript-node-executable "node"
      lsp-clients-typescript-server-args '("--stdio")
      lsp-clients-typescript-tls-server "~/.nvm/versions/node/*/bin/node")
```

## Go - gopls

### Installation
```bash
go install golang.org/x/tools/gopls@latest
```

### Configuration
```elisp
;; gopls configuration
(setq lsp-go-analyses
      '((staticcheck . t)
        (unusedparams . t)
        (unusedwrite . t)
        (useany . t)
        (unusedvariable . t)
        (fillreturns . t)
        (nonewvars . t)
        (noresultvalues . t))
      lsp-go-gofumpt t
      lsp-go-build-flags '()
      lsp-go-alternate-tools '()
      lsp-go-codelens '((gc-details . t)
                        (test . t)
                        (upgrade-dependency . t))
      lsp-go-hover-kind "FullDocumentation"
      lsp-go-link-target "pkg.go.dev"
      lsp-go-local "en")

;; Go modules
(setq lsp-go-modules-supported t
      lsp-go-modules-workspace-folder (projectile-project-root)
      lsp-go-modules-cache "~/.cache/go-modules")

;; Formatting
(setq lsp-go-format-tool "gofmt"
      lsp-go-format-on-save t
      lsp-go-imports-local "github.com/your-org")
```

## Java - eclipse.jdt.ls

### Installation
```bash
# Download from Eclipse
wget https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz
tar -xzf jdt-language-server-latest.tar.gz -C ~/.emacs.d/.cache/lsp/
```

### Configuration
```elisp
;; Java Language Server
(setq lsp-java-vmargs
      '("-Xmx4G"
        "-XX:+UseG1GC"
        "-XX:+UseStringDeduplication"
        "-javaagent:/path/to/lombok.jar"
        "-Xbootclasspath/a:/path/to/lombok.jar")
      lsp-java-workspace-dir "~/.cache/jdtls-workspace/"
      lsp-java-import-gradle-enabled t
      lsp-java-import-maven-enabled t
      lsp-java-autobuild-enabled t
      lsp-java-save-actions-organize-imports t
      lsp-java-completion-guess-method-arguments t
      lsp-java-completion-enabled t
      lsp-java-format-enabled t
      lsp-java-format-settings-url "https://raw.githubusercontent.com/google/styleguide/gh-pages/eclipse-java-google-style.xml"
      lsp-java-format-settings-profile "GoogleStyle"
      lsp-java-signature-help-enabled t
      lsp-java-content-provider-preferred "fernflower")

;; Maven/Gradle
(setq lsp-java-configuration-maven-user-settings "~/.m2/settings.xml"
      lsp-java-configuration-gradle-user-home "~/.gradle"
      lsp-java-import-exclusions '("**/node_modules/**" "**/.metadata/**" "**/archetype-resources/**")
      lsp-java-imports-gradle-wrapper-enabled t
      lsp-java-imports-gradle-wrapper-checksum-algorithm "SHA-256")
```

## Other Languages

### HTML/CSS
```elisp
;; HTML/CSS/JSON Language Server
(setq lsp-html-format-enabled t
      lsp-html-format-wrap-line-length 120
      lsp-html-format-unformatted "wbr"
      lsp-html-format-content-unformatted "pre,code,textarea"
      lsp-html-format-indent-inner-html t
      lsp-html-format-preserve-new-lines t
      lsp-html-format-max-preserve-new-lines 2
      lsp-html-format-indent-handlebars t
      lsp-html-format-end-with-newline t
      lsp-html-format-extra-liners "head, body, /html")

;; CSS
(setq lsp-css-format-enabled t
      lsp-css-format-newline-between-rules t
      lsp-css-format-newline-between-selectors t
      lsp-css-format-space-around-selector-separator t
      lsp-css-format-brace-style "collapse"
      lsp-css-format-preserve-new-lines t
      lsp-css-format-max-empty-lines 2)

;; JSON
(setq lsp-json-format-enabled t
      lsp-json-schemas '()
      lsp-json-keep-lines 0)
```

### Dockerfile
```elisp
;; Dockerfile Language Server
(setq lsp-dockerfile-language-server-server-command
      '("docker-langserver" "--stdio")
      lsp-dockerfile-language-server-trace-server "verbose")
```

### YAML
```elisp
;; YAML Language Server
(setq lsp-yaml-format-enabled t
      lsp-yaml-format-print-width 120
      lsp-yaml-format-bracket-spacing t
      lsp-yaml-format-prose-wrap "preserve"
      lsp-yaml-format-single-quote nil
      lsp-yaml-schemas '()
      lsp-yaml-custom-tags '()
      lsp-yaml-max-items-computed 5000)
```

### Bash
```elisp
;; Bash Language Server
(setq lsp-bash-language-server-server-command
      '("bash-language-server" "start")
      lsp-bash-language-server-highlight-parsing-errors "none")
```

## Server Management

### Multiple Server Selection
```elisp
;; Configure server priorities
(setq lsp-enabled-clients '(clangd pyright rust-analyzer)
      lsp-disabled-clients '(ccls cquery)
      lsp-server-install-dir "~/.emacs.d/.cache/lsp/")

;; Auto-install servers
(setq lsp-auto-configure t
      lsp-auto-require-clients nil
      lsp-restart 'auto-restart
      lsp-enable-indentation t
      lsp-enable-on-type-formatting t
      lsp-enable-symbol-highlighting t)

;; Server health check
(defun my/lsp-health-check ()
  "Check LSP server health."
  (interactive)
  (dolist (workspace (lsp-workspaces))
    (let ((server (lsp--workspace-server workspace)))
      (message "Server: %s, Status: %s"
               (lsp--workspace-print workspace)
               (if (lsp--workspace-live-p workspace) "ALIVE" "DEAD")))))
```

### Server Logs & Debugging
```elisp
;; Enable server logging
(setq lsp-log-io t
      lsp-print-performance t
      lsp-trace t
      lsp-print-io t)

;; View server logs
(defun my/view-lsp-logs ()
  "View LSP server logs."
  (interactive)
  (let ((buffer (get-buffer-create "*LSP Logs*")))
    (switch-to-buffer buffer)
    (erase-buffer)
    (dolist (workspace (lsp-workspaces))
      (insert (format "=== %s ===\n" (lsp--workspace-print workspace)))
      (insert (lsp--workspace-log workspace) "\n\n"))))
```

### Server Performance Monitoring
```elisp
;; Monitor server performance
(defvar my/lsp-performance-stats nil
  "LSP performance statistics.")

(defun my/lsp-track-performance ()
  "Track LSP request performance."
  (interactive)
  (setq my/lsp-performance-stats (make-hash-table :test 'equal))
  (advice-add 'lsp--send-request :around
              (lambda (orig-fun method params &rest args)
                (let ((start-time (float-time))
                      result)
                  (setq result (apply orig-fun method params args))
                  (let ((duration (- (float-time) start-time)))
                    (puthash method
                             (cons duration (gethash method my/lsp-performance-stats))
                             my/lsp-performance-stats))
                  result))))

(defun my/lsp-show-performance ()
  "Show LSP performance statistics."
  (interactive)
  (let ((buffer (get-buffer-create "*LSP Performance*")))
    (switch-to-buffer buffer)
    (erase-buffer)
    (maphash (lambda (method times)
               (let ((avg (/ (apply '+ times) (length times))))
                 (insert (format "%s: %.3f ms avg (%d requests)\n"
