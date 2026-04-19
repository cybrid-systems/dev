#!/bin/bash
# 简单验证脚本

echo "🧪 简单验证 LSP 功能"
echo "==================="

echo "1. 测试 Emacs daemon 状态..."
if emacsclient -a '' -e "(+ 1 1)" >/dev/null 2>&1; then
    echo "✅ Emacs daemon 正在运行"
else
    echo "❌ Emacs daemon 未运行"
    exit 1
fi

echo ""
echo "2. 测试 LSP 模块加载..."
if emacsclient -a '' -e "(boundp 'lsp-mode)" >/dev/null 2>&1; then
    echo "✅ LSP 模块已加载"
else
    echo "❌ LSP 模块未加载"
    exit 1
fi

echo ""
echo "3. 测试文件打开..."
emacsclient -a '' -e "(progn (find-file \"/home/dev/code/workspace/test-lsp/src/main.c\") (message \"File opened\"))" >/dev/null 2>&1
echo "✅ 文件打开测试完成"

echo ""
echo "4. 测试 find-def (应该能工作)..."
emacsclient -a '' -e "(progn 
  (find-file \"/home/dev/code/workspace/test-lsp/src/main.c\")
  (lsp)
  (goto-char (point-min))
  (re-search-forward \"hello\" nil t)
  (lsp-find-definition)
  (message \"find-def executed\"))" >/dev/null 2>&1
echo "✅ find-def 测试完成"

echo ""
echo "5. 测试直接 LSP 请求..."
# 创建一个简单的测试文件
cat > /tmp/test-lsp-request.el << 'EOF'
(progn
  (require 'lsp-mode)
  (find-file "/home/dev/code/workspace/test-lsp/src/main.c")
  (lsp)
  (sit-for 1)
  (goto-char (point-min))
  (when (re-search-forward "hello" nil t)
    (let* ((line (line-number-at-pos))
           (col (current-column))
           (params `(:textDocument ,(lsp--text-document-identifier)
                     :position (:line ,(1- line) :character ,col)
                     :context (:includeDeclaration t)))
           (workspace (lsp-find-workspace 'lsp-mode nil)))
      (if workspace
          (progn
            (message "Making LSP request...")
            (let ((response (lsp-request "textDocument/references" params)))
              (message "Got response: %S" (if response "non-null" "null"))
              (if (and response (not (eq response :json-false)))
                  (progn
                    (princ "SUCCESS: Got references\n")
                    (princ (format "Count: %d\n" (length response))))
                (princ "INFO: No references found\n"))))
        (princ "ERROR: No workspace\n")))))
EOF

timeout 20 emacsclient -a '' --eval "(load-file \"/tmp/test-lsp-request.el\")" 2>&1 | \
  grep -v "^\"" | grep -v "^t$" | grep -v "^nil$" | head -20

echo ""
echo "6. 总结状态..."
echo "如果看到 'SUCCESS: Got references'，则 find-refs 问题已解决"
echo "如果看到 'INFO: No references found'，则功能正常但无引用"
echo "如果看到错误或超时，则需要进一步调试"
