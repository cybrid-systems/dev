;;; debug-xref.el - 调试 xref 系统

;; 1. 查看 xref-find-references 的实现
(defun show-xref-find-references-code ()
  "显示 xref-find-references 的代码"
  (interactive)
  (find-function 'xref-find-references)
  (message "查看 xref-find-references 实现"))

;; 2. 查看 lsp-find-references 的实现
(defun show-lsp-find-references-code ()
  "显示 lsp-find-references 的代码"
  (interactive)
  (find-function 'lsp-find-references)
  (message "查看 lsp-find-references 实现"))

;; 3. 尝试直接调用底层函数
(defun get-references-direct (file symbol)
  "直接获取引用，绕过异步限制"
  (interactive)
  (find-file file)
  (lsp)
  
  (goto-char (point-min))
  (unless (re-search-forward (regexp-quote symbol) nil t)
    (error "Symbol not found"))
  
  ;; 尝试直接调用 LSP 请求
  (let* ((position (lsp--position (point)))
         (params (lsp--make-reference-params position))
         (response (lsp-request "textDocument/references" params)))
    
    (message "Direct LSP response: %S" response)
    response))

;; 4. 测试函数
(defun test-direct-references ()
  "测试直接获取引用"
  (interactive)
  (let ((refs (get-references-direct 
               "/home/dev/code/workspace/test-lsp/src/main.c"
               "hello")))
    (if refs
        (progn
          (message "Found %d references" (length refs))
          (dolist (ref refs)
            (message "Ref: %S" ref)))
      (message "No references found"))))

;; 5. 同步版本
(defun lsp-find-references-sync ()
  "同步版本的引用查找"
  (interactive)
  (let* ((position (lsp--position (point)))
         (params (lsp--make-reference-params position))
         (response (lsp-request "textDocument/references" params)))
    
    (when response
      ;; 创建 xref buffer
      (xref--show-xref-buffer
       (lambda ()
         (xref--insert-xrefs response))
       nil))))

;; 执行测试
(require 'lsp-mode)
(test-direct-references)
