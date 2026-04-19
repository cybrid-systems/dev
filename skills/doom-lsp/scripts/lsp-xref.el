;;; lsp-xref.el --- Optimized Xref bridge for Doom LSP (matches SPC c D) - v4.1

(defvar my-lsp-xref-output-file "/tmp/lsp-refs.txt")
(defvar my-lsp-xref-timeout 8)

(defun my-lsp-xref-find-references (file symbol)
  "Robust xref-find-references with retry and readiness wait (matches SPC c D)."
  (let ((output-file my-lsp-xref-output-file)
        (retries 3)
        (success nil))
    (with-temp-file output-file
      (insert (format "=== Xref References to '%s' (SPC c D) ===\nFile: %s\nTime: %s\n\n" symbol file (current-time-string)))
      (let ((buf (find-file-noselect file)))
        (with-current-buffer buf
          (lsp)
          (lsp--ensure-server)
          (sit-for 2)
          (goto-char (point-min))
          (re-search-forward (regexp-quote symbol) nil t)
          (let ((bounds (bounds-of-thing-at-point 'symbol)))
            (when bounds (goto-char (car bounds))))
          ;; Retry loop for heavy projects
          (while (and (> retries 0) (not success))
            (sit-for 2.5)
            (let ((refs (ignore-errors (lsp-find-references nil t))))
              (if (and refs (listp refs) (> (length refs) 0))
                  (progn
                    (insert (format "Found %d reference(s):\n\n" (length refs)))
                    (dolist (ref refs)
                      (let* ((uri (lsp-get ref :uri))
                             (path (if uri (file-relative-name (lsp--uri-to-path uri) default-directory) file))
                             (range (lsp-get ref :range))
                             (start (lsp-get range :start))
                             (line (1+ (lsp-get start :line)))
                             (col (1+ (lsp-get start :character)))
                             (summary (or (lsp-get ref :summary) "")))
                        (insert (format "%s:%d:%d | %s\n" path line col summary))))
                    (setq success t))
                (insert (format "Retry %d... LSP not ready yet.\n" (- 4 retries)))
                (setq retries (1- retries))
                (sit-for 1.5)))))
          (unless success
            (insert "No references found after retries (LSP may still be indexing large project).\n")))))
      (insert "\n--- Pure LSP xref-find-references (SPC c D) completed ---\n"))
    (message "my-lsp-xref-find-references completed for %s" symbol)
    (when (file-exists-p output-file)
      (with-temp-buffer
        (insert-file-contents output-file)
        (buffer-string)))
    output-file))

(provide 'lsp-xref)
;;; lsp-xref.el ends here
