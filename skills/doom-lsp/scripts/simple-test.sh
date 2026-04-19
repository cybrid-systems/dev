#!/bin/bash
# 绝对简单的测试

echo "🧪 绝对简单测试"
echo "=============="

echo "1. 测试 Emacs 连接..."
if emacsclient -a '' -e "(message \"Hello from Emacs\")" >/dev/null 2>&1; then
    echo "✅ Emacs 连接正常"
else
    echo "❌ Emacs 连接失败"
    exit 1
fi

echo ""
echo "2. 测试文件操作..."
emacsclient -a '' -e "
(progn
  (find-file \"/home/dev/code/workspace/test-lsp/src/main.c\")
  (let ((content (buffer-string)))
    (if (string-match \"hello\" content)
        (princ \"✅ 文件包含 'hello'\\n\")
      (princ \"❌ 文件不包含 'hello'\\n\"))))" 2>&1 | grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"

echo ""
echo "3. 测试 LSP 基础..."
cat > /tmp/simple-lsp-test.el << 'EOF'
(progn
  ;; 先检查 LSP 是否可用
  (if (featurep 'lsp-mode)
      (princ "✅ lsp-mode 已加载\n")
    (princ "❌ lsp-mode 未加载\n"))
  
  ;; 尝试加载 lsp-mode
  (require 'lsp-mode)
  (princ "✅ lsp-mode require 成功\n")
  
  ;; 测试基本函数
  (if (fboundp 'lsp)
      (princ "✅ lsp 函数存在\n")
    (princ "❌ lsp 函数不存在\n")))
EOF

emacsclient -a '' --eval "(load-file \"/tmp/simple-lsp-test.el\")" 2>&1 | \
  grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"

echo ""
echo "4. 创建最简单的 find-refs 测试..."
cat > /tmp/minimal-find-refs.sh << 'EOF'
#!/bin/bash
# 最小化的 find-refs 测试

echo "测试最小化 find-refs..."
timeout 15 emacsclient -a '' --eval "
(progn
  (require 'lsp-mode)
  
  ;; 1. 打开文件
  (find-file \"/home/dev/code/workspace/test-lsp/src/main.c\")
  (princ \"1. 文件已打开\\n\")
  
  ;; 2. 启动 LSP
  (lsp)
  (princ \"2. LSP 已启动\\n\")
  
  ;; 3. 等待一下
  (sit-for 2)
  (princ \"3. 等待完成\\n\")
  
  ;; 4. 查找符号
  (goto-char (point-min))
  (if (re-search-forward \"hello\" nil t)
      (progn
        (princ \"4. 找到符号 'hello'\\n\")
        
        ;; 5. 尝试最简单的 LSP 请求
        (let ((workspace (lsp-find-workspace 'lsp-mode nil)))
          (if workspace
              (progn
                (princ \"5. 找到 workspace\\n\")
                ;; 先测试一个简单的请求
                (condition-case err
                    (let ((response (lsp-request \"textDocument/hover\" 
                                  (list :textDocument (lsp--text-document-identifier)
                                        :position (list :line 0 :character 0)))))
                      (princ \"6. Hover 请求完成\\n\")
                      (if response
                          (princ \"✅ Hover 有响应\\n\")
                        (princ \"⚠️  Hover 无响应\\n\")))
                  (error (princ (format \"❌ Hover 错误: %s\\n\" (error-message-string err))))))
            (princ \"❌ 未找到 workspace\\n\"))))
    (princ \"❌ 未找到符号\\n\")))" 2>&1 | \
  grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"
EOF

chmod +x /tmp/minimal-find-refs.sh
/tmp/minimal-find-refs.sh
