;;; sync-xref-solution.el - 同步 xref 解决方案

(require 'xref)
(require 'lsp-mode)

(defun xref--collect-references-sync (symbol)
  "同步收集符号引用"
  (let ((backend (xref-backend-identifier-at-point (xref-find-backend))))
    (when backend
      (xref-backend-references backend symbol))))

(defun lsp-find-references-sync-at-point ()
  "在当前位置同步查找引用"
  (interactive)
  (let* ((backend (xref-find-backend))
         (identifier (xref-backend-identifier-at-point backend))
         (references (xref-backend-references backend identifier)))
    
    (message "Found %d references synchronously" (length references))
    references))

;; 直接调用 LSP 的底层函数
(defun lsp-get-references-sync (file symbol)
  "同步获取文件中的符号引用"
  (find-file file)
  (lsp)
  
  (goto-char (point-min))
  (unless (re-search-forward (regexp-quote symbol) nil t)
    (error "Symbol '%s' not found" symbol))
  
  (let* ((position (lsp--position (point)))
         (params (lsp--make-reference-params position))
         (workspace (lsp-find-workspace 'lsp-mode nil))
         (response (when workspace
                     (lsp-request "textDocument/references" params))))
    
    (if (and response (not (eq response :json-false)))
        (progn
          (princ (format "=== Found %d references ===\n" (length response)))
          response)
      (princ "No references found\n")
      nil)))

;; 测试：直接调用 LSP
(defun test-lsp-sync ()
  "测试同步 LSP 调用"
  (let ((refs (lsp-get-references-sync 
               "/home/dev/code/workspace/test-lsp/src/main.c"
               "hello")))
    (when refs
      (dolist (ref refs)
        (let* ((uri (gethash "uri" ref))
               (range (gethash "range" ref))
               (start (gethash "start" range))
               (line (1+ (gethash "line" start)))
               (col (1+ (gethash "character" start)))
               (filename (file-name-nondirectory uri)))
          (princ (format "%s:%d:%d\n" filename line col)))))))

;; 执行测试
(test-lsp-sync)
