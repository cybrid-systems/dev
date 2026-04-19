;;; lsp-helper.el --- Helper for doom-lsp bridge (avoids quoting hell)

(defun +lsp-helper/find-def (file symbol)
  (find-file file)
  (+lsp-deferred)
  (goto-char (point-min))
  (re-search-forward (regexp-quote symbol) nil t)
  (+lookup/definition)
  (message "find-def completed for %s" symbol))

(defun +lsp-helper/find-refs (file symbol)
  (find-file file)
  (+lsp-deferred)
  (goto-char (point-min))
  (re-search-forward (regexp-quote symbol) nil t)
  (+lookup/references)
  (message "find-refs completed for %s" symbol))

(defun +lsp-helper/hover (file line col)
  (find-file file)
  (goto-line line)
  (move-to-column col)
  (+lsp-deferred)
  (lsp-describe-thing-at-point))

(provide 'lsp-helper)
;;; lsp-helper.el ends here
