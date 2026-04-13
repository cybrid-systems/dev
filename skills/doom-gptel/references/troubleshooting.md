# gptel Troubleshooting Guide

## Common Issues and Solutions

### 1. gptel Command Not Found

**Symptoms**: `M-x gptel` returns "No match"

**Causes**:
- gptel package not installed
- Doom Emacs not synced
- Package loading issue

**Solutions**:

```bash
# In terminal
cd ~/.config/emacs
doom sync
doom upgrade
```

```elisp
;; In Emacs
M-x doom/reload
M-x doom/sync
```

Check if gptel is in packages.el:
```elisp
;; ~/.config/emacs/init.el or packages.el
(package! gptel)
```

### 2. API Connection Errors

**Symptoms**: "Failed to connect", "Connection refused", timeouts

**Diagnosis**:
```elisp
;; Test network connectivity
M-x eval-expression RET (url-retrieve-synchronously "https://api.deepseek.com")

;; Check DNS
M-x shell RET
ping api.deepseek.com
```

**Solutions**:
- Check internet connection
- Verify firewall/proxy settings
- Try different network
- Check if API endpoint is accessible

### 3. "No gptel-api-key found"

**Symptoms**: Error when trying to send message

**Check**:
```elisp
;; Verify key is set
M-x eval-expression RET gptel-api-key

;; Check auth-source
M-x eval-expression RET (auth-source-search :host "api.deepseek.com")
```

**Solutions**:
- Set `gptel-api-key` in config.el
- Configure auth-source
- Set environment variable

### 4. Slow Response Times

**Causes**:
- Network latency
- API rate limiting
- Large context windows
- Model overload

**Optimizations**:
```elisp
;; Reduce context size
(setq gptel-max-tokens 4096)

;; Enable streaming for faster initial response
(setq gptel-backend (gptel-make-openai "DeepSeek" :stream t))

;; Use faster model
(setq gptel-model 'deepseek-chat)  ; instead of deepseek-reasoner
```

### 5. Model Not Available

**Symptoms**: "Model XYZ not found" or "Invalid model"

**Check available models**:
```elisp
;; List models for current backend
M-x eval-expression RET (gptel-backend-models gptel-backend)

;; Test model directly
curl -X POST https://api.deepseek.com/v1/models \
  -H "Authorization: Bearer $API_KEY"
```

**Solutions**:
- Verify model name spelling
- Check if API key has access to model
- Update to supported model list

### 6. Buffer/UI Issues

**Symptoms**: gptel buffer not opening, formatting issues

**Debug UI**:
```elisp
;; Check buffer creation
M-x gptel  ; Should open *gptel* buffer

;; Check display rules
M-x eval-expression RET gptel-display-buffer-action

;; Test in clean Emacs
emacs -Q -l ~/.config/doom/config.el
```

**Solutions**:
- Check popup rules in config
- Verify window management settings
- Reset gptel mode: `M-x gptel-mode-restart`

### 7. Post-Processing Hook Errors

**Symptoms**: Errors after receiving response, malformed output

**Debug hooks**:
```elisp
;; List active hooks
M-x eval-expression RET gptel-post-response-functions

;; Test hook function
M-x eval-expression RET (my-fix-latex-delimiters)
```

**Solutions**:
- Check hook function for errors
- Disable hooks temporarily
- Test with minimal configuration

### 8. Memory/Performance Issues

**Symptoms**: Emacs slowing down, high memory usage

**Monitor**:
```elisp
;; Check memory
M-x memory-report

;; Monitor process
M-x list-processes
```

**Optimizations**:
```elisp
;; Limit conversation history
(setq gptel-max-entries 50)

;; Clean old buffers
(defun my/gptel-cleanup ()
  "Clean up old gptel buffers."
  (interactive)
  (dolist (buf (buffer-list))
    (when (string-match "\\*gptel" (buffer-name buf))
      (kill-buffer buf))))

;; Reduce logging
(setq gptel-log-level 'warn)
```

## Debug Mode

Enable comprehensive debugging:

```elisp
;; Full debug logging
(setq gptel-log-level 'debug
      gptel-log-requests t
      gptel-log-responses t)

;; Check logs
M-x switch-to-buffer RET *gptel-log*

;; View network requests
M-x switch-to-buffer RET *url*
```

## Testing Step by Step

### 1. Basic Function Test
```elisp
;; Test 1: Package loading
(require 'gptel)
(message "gptel loaded: %s" (featurep 'gptel))

;; Test 2: Command availability
(message "gptel command: %s" (fboundp 'gptel))
(message "gptel-send command: %s" (fboundp 'gptel-send))

;; Test 3: Backend creation
(condition-case err
    (progn
      (setq test-backend (gptel-make-openai "Test" :host "api.deepseek.com"))
      (message "Backend created: %s" (gptel-backend-name test-backend)))
  (error (message "Backend error: %s" err)))
```

### 2. Network Test
```elisp
;; Test API endpoint
(url-retrieve "https://api.deepseek.com"
  (lambda (status)
    (message "Connection test: %s" (if (plist-get status :error) "FAILED" "OK"))))
```

### 3. Configuration Test
Create test file `~/.config/doom/test-gptel.el`:
```elisp
;; Minimal test config
(setq gptel-api-key "TEST-KEY")
(setq gptel-backend (gptel-make-openai "Test" :host "api.deepseek.com"))

;; Test
(gptel)
```

Run test:
```bash
emacs -Q -l ~/.config/doom/test-gptel.el
```

## Common Error Messages

| Error Message | Cause | Solution |
|--------------|-------|----------|
| "No match" | Command not found | Doom sync, check packages.el |
| "Failed to connect" | Network issue | Check connectivity, firewall |
| "Invalid API key" | Wrong/expired key | Regenerate key, update config |
| "Model not found" | Unsupported model | Check model list, update config |
| "Rate limited" | Too many requests | Wait, upgrade plan, reduce frequency |
| "Context too long" | Token limit exceeded | Reduce message length, clear history |

## Getting Help

### 1. Check Documentation
- `M-x describe-function RET gptel`
- `M-x describe-variable RET gptel-api-key`
- `M-x info RET (gptel)` if available

### 2. Enable Backtraces
```elisp
(setq debug-on-error t)
(setq debug-on-quit t)
```

### 3. Community Resources
- [gptel GitHub Issues](https://github.com/karthink/gptel/issues)
- [Doom Emacs Discord](https://discord.gg/doomemacs)
- [r/emacs on Reddit](https://reddit.com/r/emacs)

### 4. Create Minimal Reproduction
When reporting issues:
1. Create minimal config that reproduces issue
2. Note Emacs and Doom versions
3. Include error backtrace
4. Describe steps to reproduce

```elisp
;; Example minimal config for bug report
(setq gptel-api-key "test-key")
(setq gptel-backend (gptel-make-openai "Test" :host "api.deepseek.com"))
(gptel)  ; This causes the error
```

## Prevention Tips

1. **Regular Updates**: Keep Doom Emacs and packages updated
2. **Backup Config**: Version control your config.el
3. **Test Changes**: Test new config in separate file first
4. **Monitor Logs**: Check *Messages* buffer regularly
5. **Use Version Pinning**: In packages.el: `(package! gptel :pin "abc123")`
