---
name: doom-gptel
description: Configure, manage, and use gptel (AI chat) in Doom Emacs with DeepSeek and other LLM providers. Use when setting up gptel in Doom Emacs, troubleshooting API connections, configuring different LLM backends (DeepSeek, OpenAI, Anthropic, etc.), creating custom workflows, or debugging gptel issues. Also use for advanced gptel features like post-processing hooks, model selection, and integration with other Emacs packages.
---

# Doom Emacs GPTel Skill

This skill provides comprehensive guidance for configuring and using gptel (AI chat) in Doom Emacs, with a focus on DeepSeek integration.

## Quick Start

### 1. Basic gptel Configuration

Add to `~/.config/doom/config.el`:

```elisp
;; Basic gptel setup with DeepSeek
(use-package! gptel
  :config
  (setq! gptel-api-key "your-deepseek-api-key"))

(setq gptel-model 'deepseek-chat
      gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :endpoint "/chat/completions"
        :stream t
        :key gptel-api-key
        :models '("deepseek-chat" "deepseek-coder")))
```

### 2. tmux Integration Setup

Install the tmux-gptel integration tools:

```bash
# From the doom-gptel skill directory
cd ~/code/workspace/skills/doom-gptel
./scripts/install-tmux-integration.sh

# Add ~/bin to PATH (if not already)
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.zshrc
source ~/.zshrc
```

### 3. Add tmux Functions to Doom Emacs

Add the tmux integration functions to your config:

```elisp
;; tmux-gptel integration (from doom-gptel skill)
(load-file "~/code/workspace/skills/doom-gptel/references/tmux-integration.el")
```

Or copy the functions directly from the `tmux-integration.el` file.

### 4. Test the Workflow

```bash
# Create a development session
dev-session

# In tmux, compile some code and get errors
cd ~/code/redis-src
make

# Copy errors to gptel
tmux2gptel

# In Doom Emacs: M-x gptel, paste with C-y, ask for help

# Get AI response, then apply to tmux
gptel2tmux
```

### Usage

1. **Start gptel**: `M-x gptel`
2. **Send message**: Type your message and press `C-c C-c`
3. **Exit**: `C-c C-q`
4. **Cancel request**: `C-c C-k`
5. **Open menu**: `M-x gptel-menu`

## Configuration Options

### API Keys

gptel supports multiple ways to provide API keys:

```elisp
;; Method 1: Direct string
(setq gptel-api-key "sk-your-api-key")

;; Method 2: Function (from auth-source)
(setq gptel-api-key (lambda () (auth-source-pick-first-password :host "api.deepseek.com")))

;; Method 3: Environment variable
(setq gptel-api-key (getenv "DEEPSEEK_API_KEY"))
```

### Supported Backends

#### DeepSeek (OpenAI-compatible)

```elisp
(setq gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :endpoint "/chat/completions"
        :stream t
        :key gptel-api-key
        :models '("deepseek-chat" "deepseek-coder" "deepseek-reasoner")))
```

#### OpenAI

```elisp
(setq gptel-backend
      (gptel-make-openai "OpenAI"
        :host "api.openai.com"
        :key openai-api-key
        :models '("gpt-4o" "gpt-4-turbo" "gpt-3.5-turbo")))
```

#### Anthropic (Claude)

```elisp
(setq gptel-backend
      (gptel-make-anthropic "Claude"
        :key anthropic-api-key
        :models '("claude-3-5-sonnet" "claude-3-opus" "claude-3-haiku")))
```

#### Google Gemini

```elisp
(setq gptel-backend
      (gptel-make-google "Gemini"
        :key google-api-key
        :models '("gemini-1.5-pro" "gemini-1.5-flash")))
```

### Model Selection

```elisp
;; Set default model
(setq gptel-model 'deepseek-chat)

;; Or use different models for different contexts
(defun my/gptel-set-model ()
  "Set gptel model based on buffer type."
  (cond
   ((derived-mode-p 'prog-mode) 'deepseek-coder)
   ((derived-mode-p 'org-mode) 'deepseek-chat)
   (t 'deepseek-chat)))

(add-hook 'gptel-mode-hook 'my/gptel-set-model)
```

## Advanced Features

### Post-Processing Hooks

gptel supports post-processing of AI responses:

```elisp
;; Example: Fix LaTeX delimiters in responses
(defun my/fix-latex-delimiters ()
  "Replace LaTeX delimiters with Markdown math syntax."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "\\\\(" nil t)
      (replace-match "$" nil nil))
    (goto-char (point-min))
    (while (re-search-forward "\\\\)" nil t)
      (replace-match "$" nil nil))
    (goto-char (point-min))
    (while (re-search-forward "\\\\\\[" nil t)
      (replace-match "$$" nil nil))
    (goto-char (point-min))
    (while (re-search-forward "\\\\\\]" nil t)
      (replace-match "$$" nil nil))))

(add-hook 'gptel-post-response-functions 'my/fix-latex-delimiters)
```

### Multiple Backends

Switch between different AI providers:

```elisp
(defvar my/gptel-backends
  `(("deepseek" . ,(gptel-make-openai "DeepSeek"
                    :host "api.deepseek.com"
                    :key deepseek-api-key
                    :models '("deepseek-chat" "deepseek-coder")))
    ("openai" . ,(gptel-make-openai "OpenAI"
                   :key openai-api-key
                   :models '("gpt-4o" "gpt-4-turbo")))
    ("claude" . ,(gptel-make-anthropic "Claude"
                    :key anthropic-api-key
                    :models '("claude-3-5-sonnet"))))
  "Available gptel backends.")

(defun my/switch-gptel-backend (backend-name)
  "Switch gptel backend by name."
  (interactive
   (list (completing-read "Select backend: "
                          (mapcar 'car my/gptel-backends))))
  (setq gptel-backend (alist-get backend-name my/gptel-backends nil nil 'equal))
  (message "Switched to %s backend" backend-name))
```

### Integration with Other Packages

#### Org Mode Integration

```elisp
;; Use gptel in org-mode buffers
(add-hook 'org-mode-hook
          (lambda ()
            (setq-local gptel-default-mode 'org-mode)))

;; Quick gptel commands in org
(map! :map org-mode-map
      :localleader
      "g" #'gptel
      "s" #'gptel-send)
```

#### Magit Integration

```elisp
;; Use gptel-magit for commit messages
(use-package! gptel-magit
  :when (modulep! :tools magit)
  :hook (magit-mode . gptel-magit-install))
```

#### ob-gptel (Org Babel)

```elisp
;; Execute gptel code blocks in org
(use-package! ob-gptel
  :when (modulep! :lang org)
  :hook (org-mode . ob-gptel-install))
```

## Troubleshooting

### Common Issues

#### 1. API Key Not Found

**Symptoms**: "No `gptel-api-key' found in the auth source"

**Solutions**:
- Check if `gptel-api-key` is set in config.el
- Verify API key format (should start with "sk-")
- Test API key directly: `curl -X POST https://api.deepseek.com/v1/chat/completions -H "Authorization: Bearer YOUR_KEY" -H "Content-Type: application/json" -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"Hello"}]}'`

#### 2. Connection Errors

**Symptoms**: "Failed to connect" or timeout errors

**Solutions**:
- Check network connectivity: `ping api.deepseek.com`
- Verify firewall/proxy settings
- Try different endpoint (some regions may be blocked)

#### 3. Model Not Available

**Symptoms**: "Model not found" errors

**Solutions**:
- Check available models in backend configuration
- Verify model name spelling
- Ensure API key has access to requested model

#### 4. Slow Responses

**Solutions**:
- Enable streaming: `:stream t`
- Reduce response length with `gptel-max-tokens`
- Switch to faster model (e.g., `deepseek-chat` instead of `deepseek-reasoner`)

### Debugging

Enable debug logging:

```elisp
(setq gptel-log-level 'debug)
```

Check gptel logs in `*Messages*` buffer or `*gptel-log*`.

## Performance Tips

1. **Use streaming**: `:stream t` for faster initial response
2. **Cache API keys**: Use auth-source or environment variables
3. **Limit context**: Set `gptel-max-tokens` to control response length
4. **Batch requests**: Use `gptel-send` for single messages, `gptel-request` for batches

## Example Configurations

### Complete DeepSeek Setup

```elisp
;; ~/.config/doom/config.el
(use-package! gptel
  :config
  (setq! gptel-api-key "sk-your-deepseek-key"))

;; DeepSeek configuration
(setq gptel-model 'deepseek-chat
      gptel-backend
      (gptel-make-openai "DeepSeek"
        :host "api.deepseek.com"
        :endpoint "/chat/completions"
        :stream t
        :key gptel-api-key
        :models '("deepseek-chat" "deepseek-coder")))

;; Post-processing for better math rendering
(defun my/clean-gptel-response ()
  "Clean up gptel responses."
  (save-excursion
    (goto-char (point-min))
    ;; Fix LaTeX delimiters
    (while (re-search-forward "\\\\(" nil t) (replace-match "$"))
    (goto-char (point-min))
    (while (re-search-forward "\\\\)" nil t) (replace-match "$"))
    (goto-char (point-min))
    (while (re-search-forward "\\\\\\[" nil t) (replace-match "$$"))
    (goto-char (point-min))
    (while (re-search-forward "\\\\\\]" nil t) (replace-match "$$"))))

(add-hook 'gptel-post-response-functions 'my/clean-gptel-response)

;; Keybindings
(map! :leader
      :desc "Start gptel" "o a" #'gptel)
```

### Multi-Provider Setup

```elisp
;; Multiple AI providers
(defvar my/deepseek-key "sk-deepseek-key")
(defvar my/openai-key "sk-openai-key")

(setq gptel-backends
      `(("DeepSeek" . ,(gptel-make-openai "DeepSeek"
                        :host "api.deepseek.com"
                        :key my/deepseek-key
                        :models '("deepseek-chat")))
        ("OpenAI" . ,(gptel-make-openai "OpenAI"
                       :key my/openai-key
                       :models '("gpt-4o" "gpt-4-turbo")))
        ("Claude" . ,(gptel-make-anthropic "Claude"
                        :key (getenv "ANTHROPIC_API_KEY")
                        :models '("claude-3-5-sonnet")))))

(defun my/select-gptel-backend ()
  "Select gptel backend interactively."
  (interactive)
  (let ((backend-name (completing-read "Select AI provider: "
                                       (mapcar 'car gptel-backends))))
    (setq gptel-backend (alist-get backend-name gptel-backends nil nil 'equal))
    (message "Switched to %s" backend-name)))
```

## References

For more information, see:
- [gptel GitHub](https://github.com/karthink/gptel) - Official documentation
- [DeepSeek API Docs](https://platform.deepseek.com/api-docs) - API reference
- [Doom Emacs Modules](https://github.com/doomemacs/doomemacs/tree/master/modules/tools/llm) - Doom's LLM module

## Quick Verification

To verify your gptel setup is working:

```elisp
;; Quick test in Emacs
M-x eval-expression RET (require 'gptel)
M-x eval-expression RET (fboundp 'gptel)  ; Should return t
M-x gptel  ; Should open *gptel* buffer
```

If `M-x gptel` says "No match", run:
```bash
doom sync
doom upgrade
```

## tmux Integration Workflow

For developers using tmux with Doom Emacs, here's a complete workflow for integrating tmux terminal output with gptel AI assistance.

### Prerequisites

- tmux installed and configured (Oh My Tmux recommended)
- System clipboard tool (xclip, xsel, pbcopy, or clip.exe)
- Doom Emacs with gptel configured

### tmux Configuration

Ensure your `~/.tmux.conf.local` has:

```tmux
# Enable system clipboard integration
tmux_conf_copy_to_os_clipboard=true

# Or manually set clipboard
set -g set-clipboard on

# Vi-style copy mode (recommended)
set -g mode-keys vi
bind-key -T copy-mode-vi 'v' send -X begin-selection
bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel
```

### Workflow Scripts

Create these scripts in `~/bin/` for the complete workflow:

#### 1. tmux2gptel - Copy tmux content to gptel

```bash
#!/bin/bash
# ~/bin/tmux2gptel
# Copy current tmux pane content to system clipboard for gptel

# Capture pane content (last 1000 lines)
tmux capture-pane -p -S -1000 | \
  sed '/^[[:space:]]*$/d' | \
  xclip -selection clipboard

echo "Content copied to clipboard ($(tmux capture-pane -p -S -1000 | wc -l) lines)"
echo "Switch to Doom Emacs and paste into gptel with C-y"
```

#### 2. gptel2tmux - Apply gptel suggestions to tmux

```bash
#!/bin/bash
# ~/bin/gptel2tmux
# Send gptel AI response to tmux for execution

read -p "Paste gptel response (Ctrl+D when done): " response

echo "$response" | while IFS= read -r line; do
    tmux send-keys "$line" C-m
    sleep 0.1
done

echo "Response sent to tmux"
```

### Emacs Configuration for tmux Integration

Add to `~/.config/doom/config.el`:

```elisp
;; tmux-gptel integration functions
(defun my/tmux-capture-to-gptel ()
  "Capture tmux pane content and insert into gptel."
  (interactive)
  (let ((cmd "tmux capture-pane -p -S -1000 | sed '/^[[:space:]]*$/d'"))
    (with-temp-buffer
      (call-process-shell-command cmd nil t)
      (when (derived-mode-p 'gptel-mode)
        (insert (buffer-string))
        (message "Tmux content inserted into gptel")))))

(defun my/gptel-to-tmux ()
  "Send gptel response to tmux for execution."
  (interactive)
  (let ((response (buffer-substring-no-properties
                   (point-min) (point-max))))
    (with-temp-buffer
      (insert response)
      (call-process-region (point-min) (point-max)
                           "bash" nil nil nil
                           "-c" "while IFS= read -r line; do tmux send-keys \"$line\" C-m; sleep 0.1; done")
      (message "Gptel response sent to tmux"))))

;; Keybindings for tmux-gptel workflow
(map! :map gptel-mode-map
      :localleader
      "t" #'my/tmux-capture-to-gptel
      "T" #'my/gptel-to-tmux)
```

### Complete Development Workflow

#### Scenario: Debugging Compilation Errors

1. **In tmux**: Compile your code
   ```bash
   cd ~/projects/myapp
   make
   ```

2. **Copy error to gptel**:
   ```bash
   # Method 1: Use script
   tmux2gptel
   
   # Method 2: Manual tmux copy
   # Prefix + [ → v select → y copy
   ```

3. **In Doom Emacs**:
   ```elisp
   M-x gptel           ; Open gptel
   C-y                ; Paste error
   C-c C-c            ; Send to AI
   ```

4. **Get AI analysis** and copy the response

5. **Apply fix to tmux**:
   ```bash
   # Method 1: Use script
   gptel2tmux
   
   # Method 2: Manual paste in tmux
   # Prefix + ]
   ```

6. **Edit code and recompile** in tmux

#### Scenario: Learning New Codebase

1. **In tmux**: Explore code
   ```bash
   grep -r "function_name" .
   find . -name "*.c" -exec wc -l {} \;
   ```

2. **Copy output to gptel** for explanation

3. **Ask questions** about architecture, patterns, etc.

4. **Apply insights** to your understanding

### Advanced Integration

#### Auto-capture Compilation Errors

```elisp
(defun my/compile-with-gptel-capture ()
  "Run make and auto-capture errors to gptel."
  (interactive)
  (let ((default-directory (project-root (project-current))))
    (compile "make")
    (run-at-time "2 sec" nil
                 (lambda ()
                   (when (get-buffer "*compilation*")
                     (with-current-buffer "*compilation*"
                       (when (search-forward "error:" nil t)
                         (my/tmux-capture-to-gptel))))))))
```

#### tmux Window Management for Development

```bash
#!/bin/bash
# ~/bin/dev-session
# Create standardized development session

SESSION="dev-$(basename $(pwd))"

tmux has-session -t $SESSION 2>/dev/null
if [ $? != 0 ]; then
    tmux new-session -d -s $SESSION -n "editor"
    tmux send-keys -t $SESSION:editor "emacsclient -c" C-m
    tmux new-window -t $SESSION -n "shell"
    tmux new-window -t $SESSION -n "logs"
    tmux new-window -t $SESSION -n "git"
    tmux select-window -t $SESSION:editor
fi

tmux attach -t $SESSION
```

### Troubleshooting tmux Integration

#### Clipboard Not Working

```bash
# Test clipboard
echo "test" | xclip -selection clipboard
xclip -selection clipboard -o  # Should output "test"

# If xclip not available, install:
sudo apt install xclip  # Debian/Ubuntu
brew install xclip      # macOS
```

#### tmux Copy Mode Issues

```bash
# Check tmux copy mode bindings
tmux list-keys -T copy-mode-vi | grep "begin-selection\|copy-selection"

# Expected output:
# bind-key -T copy-mode-vi v send -X begin-selection
# bind-key -T copy-mode-vi y send -X copy-selection-and-cancel
```

#### Emacs Functions Not Loading

```elisp
;; Test if functions are defined
M-x eval-expression RET (fboundp 'my/tmux-capture-to-gptel)
M-x eval-expression RET (fboundp 'my/gptel-to-tmux)

;; Reload config
doom sync
doom reload
```

### Benefits of tmux-gptel Integration

1. **Seamless workflow**: Terminal ↔ Editor ↔ AI
2. **Faster debugging**: AI analyzes errors instantly
3. **Learning acceleration**: Get explanations for complex output
4. **Code quality**: AI suggests improvements and best practices
5. **Productivity**: Reduce context switching between tools

## Quick Commands Reference

| Command | Keybinding | Description |
|---------|------------|-------------|
| `gptel` | `M-x gptel` | Start gptel chat |
| `gptel-send` | `C-c C-c` | Send current message |
| `gptel-menu` | `M-x gptel-menu` | Open gptel menu |
| Exit | `C-c C-q` | Exit gptel mode |
| Cancel | `C-c C-k` | Cancel current request |
| Clear | `C-c C-l` | Clear conversation |
| `my/tmux-capture-to-gptel` | `, t` (in gptel) | Capture tmux to gptel |
| `my/gptel-to-tmux` | `, T` (in gptel) | Send gptel to tmux |
