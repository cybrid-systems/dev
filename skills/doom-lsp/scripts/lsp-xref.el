;;; lsp-xref.el --- Optimized Xref bridge for Doom LSP v4.2

(defvar my-lsp-xref-output-file "/tmp/lsp-refs.txt")

(defun my-lsp-xref-find-references (file symbol)
  "Robust LSP references (完全兼容当前 lsp-mode)"
  (let ((output-file my-lsp-xref-output-file))
    (with-temp-file output-file
      (insert (format "=== Xref References to '%s' ===\nFile: %s\nTime: %s\n\n"
                      symbol file (current-time-string)))
      (with-current-buffer (find-file-noselect file)
        (lsp)
        (lsp--ensure-server)
        (sit-for 2)
        ;; 定位 symbol
        (goto-char (point-min))
        (re-search-forward (regexp-quote symbol) nil t)
        (let ((bounds (bounds-of-thing-at-point 'symbol)))
          (when bounds (goto-char (car bounds))))
        ;; 关键修复：去掉错误的 t 参数
        (let ((refs (ignore-errors (lsp-find-references))))
          (if (and refs (listp refs) (> (length refs) 0))
              (progn
                (insert (format "Found %d reference(s):\n\n" (length refs)))
                (dolist (ref refs)
                  (let* ((uri (lsp-get ref :uri))
                         (path (if uri (file-relative-name (lsp--uri-to-path uri) default-directory) file))
                         (range (lsp-get ref :range))
                         (start (lsp-get range :start))
                         (line (1+ (lsp-get start :line)))
                         (col (1+ (lsp-get start :character))))
                    (insert (format "%s:%d:%d\n" path line col)))))
            (insert "No references found (or still indexing).\n")))))
    (message "my-lsp-xref-find-references completed")
    output-file))

(provide 'lsp-xref)
;;; lsp-xref.el ends here
