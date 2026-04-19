;;; minimal-test.el - 最小化测试

;; 最简单的测试：直接调用 LSP 请求
(defun test-minimal ()
  "最小化测试 LSP references"
  (interactive)
  
  ;; 1. 打开文件
  (find-file "/home/dev/code/workspace/test-lsp/src/main.c")
  
  ;; 2. 启动 LSP
  (lsp)
  
  ;; 3. 等待 LSP 就绪
  (sit-for 2)
  
  ;; 4. 查找符号
  (goto-char (point-min))
  (if (re-search-forward "hello" nil t)
      (progn
        (message "Found symbol 'hello' at position %d" (point))
        
        ;; 5. 直接调用 LSP 请求
        (let* ((line (line-number-at-pos))
               (col (current-column))
               (params `(:textDocument ,(lsp--text-document-identifier)
                         :position (:line ,(1- line) :character ,col)
                         :context (:includeDeclaration t)))
               (workspace (lsp-find-workspace 'lsp-mode nil)))
          
          (if workspace
              (progn
                (message "Workspace found, making request...")
                (let ((response (lsp-request "textDocument/references" params)))
                  (message "Response type: %S" (type-of response))
                  (if response
                      (progn
                        (message "Response length: %d" (length response))
                        (princ (format "=== Found %d references ===\n" (length response)))
                        (dolist (ref response)
                          (let* ((uri (gethash "uri" ref))
                                 (range (gethash "range" ref))
                                 (start (gethash "start" range))
                                 (line (1+ (gethash "line" start)))
                                 (col (1+ (gethash "character" start)))
                                 (filename (file-name-nondirectory uri)))
                            (princ (format "%s:%d:%d\n" filename line col)))))
                    (princ "No references found (null response)\n"))))
            (princ "No workspace found\n"))))
    (princ "Symbol 'hello' not found\n")))

;; 执行测试
(test-minimal)
