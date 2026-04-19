#!/bin/bash
# find-refs 工作解决方案
# 尝试解决引用查找问题

echo "🔧 find-refs 问题解决方案探索"
echo "=============================="

EMACSCLIENT="emacsclient -a ''"

# 方法1：使用 xref 并捕获 buffer 内容
echo "1. 🎯 方法1：捕获 xref buffer 内容"
cat > /tmp/find-refs-method1.el << 'EOF'
(defun find-refs-capture (file symbol)
  "查找引用并捕获结果"
  (interactive)
  (find-file file)
  (lsp)
  
  (goto-char (point-min))
  (unless (re-search-forward (regexp-quote symbol) nil t)
    (error "Symbol not found: %s" symbol))
  
  ;; 清除旧的 xref buffer
  (when (get-buffer "*xref*")
    (kill-buffer "*xref*"))
  
  ;; 执行引用查找
  (xref-find-references symbol)
  
  ;; 等待并获取结果
  (sit-for 1)
  
  (when (get-buffer "*xref*")
    (with-current-buffer "*xref*"
      (let ((content (buffer-string)))
        (kill-buffer "*xref*")
        content)))
  nil)

;; 执行测试
(let ((result (find-refs-capture 
               "/home/dev/code/workspace/test-lsp/src/main.c"
               "hello")))
  (if result
      (progn
        (princ "=== REFERENCES FOUND ===\n")
        (princ result)
        (princ "\n=== END ===\n"))
    (princ "No references captured\n")))
EOF

echo "执行方法1..."
$EMACSCLIENT --eval "(load-file \"/tmp/find-refs-method1.el\")" 2>&1 | \
  grep -v "^\"" | grep -v "^t$" | grep -v "^nil$" | head -20
echo ""

# 方法2：直接调用 LSP 接口
echo "2. 🔧 方法2：直接 LSP 接口调用"
cat > /tmp/find-refs-method2.el << 'EOF'
(defun lsp-get-references-sync (file symbol)
  "同步获取引用"
  (find-file file)
  (lsp)
  
  (goto-char (point-min))
  (unless (re-search-forward (regexp-quote symbol) nil t)
    (error "Symbol not found"))
  
  (let ((position (lsp--position))
        (workspace (lsp-find-workspace 'lsp-mode nil)))
    
    (when workspace
      (let ((response (lsp-request "textDocument/references"
                    (lsp--make-reference-params position))))
        (if response
            (progn
              (princ (format "Found %d references:\n" (length response)))
              (dolist (ref response)
                (let* ((uri (gethash "uri" ref))
                       (range (gethash "range" ref))
                       (start (gethash "start" range))
                       (line (1+ (gethash "line" start)))
                       (character (gethash "character" start)))
                  (princ (format "  %s:%d:%d\n" 
                                 (file-name-nondirectory uri)
                                 line character)))))
          (princ "No references found\n"))))))

;; 测试
(lsp-get-references-sync 
 "/home/dev/code/workspace/test-lsp/src/main.c"
 "hello")
EOF

echo "执行方法2..."
$EMACSCLIENT --eval "(load-file \"/tmp/find-refs-method2.el\")" 2>&1 | \
  grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"
echo ""

# 方法3：使用 lsp-ui 的 peek 功能
echo "3. 👁️ 方法3：lsp-ui peek 方法"
cat > /tmp/find-refs-method3.el << 'EOF'
(require 'lsp-ui)

(defun lsp-ui-peek-references-capture (file symbol)
  "使用 lsp-ui-peek 查看引用"
  (find-file file)
  (lsp)
  
  (goto-char (point-min))
  (unless (re-search-forward (regexp-quote symbol) nil t)
    (error "Symbol not found"))
  
  (lsp-ui-peek-find-references)
  
  ;; 检查 peek buffer
  (sit-for 0.5)
  (let ((peek-buffer (get-buffer "*lsp-peek*")))
    (if peek-buffer
        (with-current-buffer peek-buffer
          (princ "=== PEEK REFERENCES ===\n")
          (princ (buffer-string))
          (princ "\n=== END ===\n"))
      (princ "No peek buffer found\n"))))

;; 测试
(lsp-ui-peek-references-capture 
 "/home/dev/code/workspace/test-lsp/src/main.c"
 "hello")
EOF

echo "执行方法3..."
$EMACSCLIENT --eval "(load-file \"/tmp/find-refs-method3.el\")" 2>&1 | \
  grep -v "^\"" | grep -v "^t$" | grep -v "^nil$" | head -30
echo ""

echo "4. 📊 问题分析总结"
echo ""
echo "🔍 技术挑战："
echo "  1. lsp-find-references 是异步操作"
echo "  2. 结果展示在 buffer，不直接返回"
echo "  3. 需要同步等待 LSP 服务器响应"
echo "  4. 结果提取需要 buffer 操作"
echo ""
echo "💡 可能的解决方案："
echo "  1. 使用 lsp-request 同步调用"
echo "  2. 捕获 xref buffer 内容"
echo "  3. 使用 lsp-ui-peek 并提取内容"
echo "  4. 实现自定义的结果收集器"
echo ""
echo "🎯 下一步："
echo "  需要深入调试 LSP 请求/响应机制"
echo "  或者接受 find-refs 的交互式特性"
