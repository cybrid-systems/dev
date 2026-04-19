;;; lsp-xref.el --- Final Robust Xref for Doom LSP v4.3

(defvar my-lsp-xref-output-file "/tmp/lsp-refs.txt")

(defun my-lsp-xref-find-references (file symbol)
  "最终加强版：更长等待 + 自动重定位 symbol"
  (let ((output-file my-lsp-xref-output-file))
    (with-temp-file output-file
      (insert (format "=== Xref References to '%s' (SPC c D) ===\nFile: %s\nTime: %s\n\n"
                      symbol file (current-time-string)))
      (with-current-buffer (find-file-noselect file)
        (lsp)
        (lsp--ensure-server)
        (sit-for 4)                    ; 加强等待
        ;; 更智能定位 symbol
        (goto-char (point-min))
        (if (re-search-forward (regexp-quote symbol) nil t)
            (let ((bounds (bounds-of-thing-at-point 'symbol)))
              (when bounds (goto-char (car bounds))))
          (insert "WARNING: Symbol not found in file!\n"))
        ;; 尝试获取引用（最多 retry 4 次）
        (let ((success nil))
          (dotimes (i 4)
            (sit-for 2)
            (let ((refs (ignore-errors (lsp-find-references))))
              (when (and refs (listp refs) (> (length refs) 0))
                (insert (format "Found %d reference(s):\n\n" (length refs)))
                (dolist (ref refs)
                  (let* ((uri (lsp-get ref :uri))
                         (path (if uri (file-relative-name (lsp--uri-to-path uri) default-directory) file))
                         (range (lsp-get ref :range))
                         (start (lsp-get range :start))
                         (line (1+ (lsp-get start :line)))
                         (col (1+ (lsp-get start :character))))
                    (insert (format "%s:%d:%d\n" path line col))))
                (setq success t)
                (return))))
          (unless success
            (insert "No references found (or still indexing). Try Redis project.\n"))))
      (insert "\n--- LSP xref completed ---\n"))
    (message "my-lsp-xref-find-references completed")
    output-file))

(provide 'lsp-xref)
;;; lsp-xref.el ends here
