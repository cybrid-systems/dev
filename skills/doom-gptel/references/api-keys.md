# API Key Management for gptel

## Obtaining API Keys

### DeepSeek
1. Visit: https://platform.deepseek.com/api_keys
2. Sign up or log in
3. Create new API key
4. Copy the key (starts with `sk-`)

### OpenAI
1. Visit: https://platform.openai.com/api-keys
2. Create new secret key
3. Copy the key (starts with `sk-`)

### Anthropic (Claude)
1. Visit: https://console.anthropic.com/settings/keys
2. Create new API key
3. Copy the key (starts with `sk-ant-`)

### Google Gemini
1. Visit: https://makersuite.google.com/app/apikey
2. Create API key
3. Copy the key

## Security Best Practices

### Never Commit API Keys
```elisp
;; BAD - Hardcoded in config
(setq gptel-api-key "sk-abc123...")

;; GOOD - Environment variable
(setq gptel-api-key (getenv "DEEPSEEK_API_KEY"))

;; BETTER - auth-source
(setq gptel-api-key (lambda () 
  (auth-source-pick-first-password :host "api.deepseek.com")))
```

### Using auth-source

1. Create `~/.authinfo.gpg` (encrypted):
```
machine api.deepseek.com login api password sk-your-key
machine api.openai.com login api password sk-your-key
```

2. Or use `auth-source-pass` with password store

3. Configure in Emacs:
```elisp
(require 'auth-source)
(setq gptel-api-key 
      (lambda () 
        (auth-source-pick-first-password :host "api.deepseek.com")))
```

### Environment Variables

Add to `~/.bashrc` or `~/.zshrc`:
```bash
export DEEPSEEK_API_KEY="sk-your-key"
export OPENAI_API_KEY="sk-your-key"
export ANTHROPIC_API_KEY="sk-ant-your-key"
```

Then in Emacs:
```elisp
(setq gptel-api-key (getenv "DEEPSEEK_API_KEY"))
```

## Testing API Keys

### DeepSeek Test
```bash
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

### OpenAI Test
```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

## Rate Limits and Costs

### DeepSeek (as of 2026)
- Free tier: Limited requests
- Paid: $0.14 per 1M tokens input, $0.28 per 1M tokens output
- Rate limits: Check dashboard

### OpenAI
- Varies by model and account type
- gpt-4o: ~$5 per 1M tokens
- Check https://openai.com/pricing

### Monitoring Usage
```elisp
;; Enable usage tracking
(setq gptel-log-requests t)

;; Check *gptel-log* buffer for request details
```

## Troubleshooting API Issues

### Common Errors

1. **Invalid API Key**
   - Check key format
   - Verify key is active
   - Ensure no trailing whitespace

2. **Insufficient Quota**
   - Check billing/usage
   - Upgrade plan if needed

3. **Rate Limited**
   - Implement retry logic
   - Reduce request frequency

### Debug Commands

```elisp
;; Check current API key
M-x eval-expression RET gptel-api-key

;; Test connection
M-x gptel-test-connection

;; View logs
M-x view-gptel-log
```

## Multi-User Configuration

For shared configurations, use conditional setup:

```elisp
;; Detect user and set appropriate keys
(cond
 ((string-equal (user-login-name) "alice")
  (setq gptel-api-key "sk-alice-key"))
 ((string-equal (user-login-name) "bob")
  (setq gptel-api-key (getenv "BOB_DEEPSEEK_KEY")))
 (t
  (setq gptel-api-key nil
        gptel-backend nil)))
```

## Key Rotation

Regularly rotate API keys for security:

1. Generate new key in provider dashboard
2. Update configuration
3. Test new key works
4. Revoke old key after confirmation
