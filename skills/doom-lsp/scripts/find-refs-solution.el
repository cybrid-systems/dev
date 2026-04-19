;;; find-refs-solution.el - find-refs 问题解决方案

(defun doom-lsp-find-refs-sync (file symbol)
  "同步查找符号引用，返回引用列表"
  (interactive)
  (find-file file)
  (lsp)
  
  ;; 确保 LSP 服务器就绪
  (unless (lsp--ensure-server (lsp-find-workspace 'lsp-mode nil))
    (error "LSP server not ready"))
  
  ;; 查找符号位置
  (goto-char (point-min))
  (unless (re-search-forward (regexp-quote symbol) nil t)
    (error "Symbol %s not found" symbol))
  
  (let ((position (lsp--position))
        (result nil))
    
    ;; 同步调用 LSP 引用查找
    (condition-case err
        (progn
          (lsp-request-async
           "textDocument/references"
           (lsp--make-reference-params position)
           (lambda (references)
             (setq result references)
             (message "Found %d references" (length references)))
           :mode 'detach
           :cancel-token :textDocument/references)
          
          ;; 等待结果（有限时间）
          (let ((timeout 10)
                (start-time (float-time)))
            (while (and (null result) 
                       (< (- (float-time) start-time) timeout))
              (sleep-for 0.1)
              (redisplay)))
          
          (if result
              (progn
                (message "References: %S" result)
                result)
            (error "Timeout waiting for references")))
      
      (error (message "Error finding references: %s" (error-message-string err))
             nil))))

(defun doom-lsp-find-refs-simple (file symbol)
  "简单的引用查找，返回格式化结果"
  (interactive)
  (find-file file)
  (lsp)
  
  (goto-char (point-min))
  (unless (re-search-forward (regexp-quote symbol) nil t)
    (error "Symbol %s not found" symbol))
  
  ;; 使用 xref 系统
  (xref-find-references symbol)
  
  ;; 获取 xref buffer 内容
  (when (get-buffer "*xref*")
    (with-current-buffer "*xref*"
      (buffer-string))))

(defun doom-lsp-find-refs-cli (file symbol)
  "命令行友好的引用查找"
  (let ((result (doom-lsp-find-refs-simple file symbol)))
    (if result
        (progn
          (princ "=== REFERENCES ===\n")
          (princ result)
          (princ "\n=== END ===\n")
          t)
      (princ "No references found\n")
      nil)))

;; 测试函数
(defun test-find-refs ()
  "测试引用查找"
  (interactive)
  (let ((result (doom-lsp-find-refs-cli 
                 "/home/dev/code/workspace/test-lsp/src/main.c"
                 "hello")))
    (message "Test result: %S" result)))

(provide 'find-refs-solution)
