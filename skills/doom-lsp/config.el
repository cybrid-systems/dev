;;; config.el --- doom-lsp module - Agent optimized

;; Use Doom's native lookup handlers instead of raw lsp calls
(after! lsp-mode
  (setq lsp-clients-clangd-args
        '("--background-index"
          "--clang-tidy"
          "--header-insertion=never"
          "--completion-style=detailed"
          "--pch-storage=memory"
          "--j=2"))

  ;; Register for C/C++ and Python
  (add-to-list 'lsp-language-id-configuration '(c-mode . "c"))
  (add-to-list 'lsp-language-id-configuration '(c++-mode . "cpp"))
  (add-to-list 'lsp-language-id-configuration '(python-mode . "python"))

  ;; Use Doom's optimized lookup handlers (this is the key improvement)
  (set-lookup-handlers! '(c-mode c++-mode python-mode)
    :definition #'+lsp/lookup-definition
    :references #'+lsp/lookup-references
    :implementation #'+lsp/lookup-implementation
    :type-definition #'+lsp/lookup-type-definition
    :documentation #'lsp-describe-thing-at-point)

  ;; Enable useful features for Agent workflows
  (setq lsp-enable-symbol-highlighting t
        lsp-ui-sideline-enable t
        lsp-ui-doc-enable t
        lsp-signature-auto-activate t
        lsp-idle-delay 0.5)

  (message "doom-lsp v7.0 loaded - using Doom native handlers for Agent"))

;; One-shot analysis command for Agent
(defun +doom-lsp/agent-analyze (file symbol)
  "One-shot full LSP analysis for Agent use."
  (interactive "fFile: \nsSymbol: ")
  (find-file file)
  (+lsp-deferred)
  (goto-char (point-min))
  (when (search-forward symbol nil t)
    (let ((bounds (bounds-of-thing-at-point 'symbol)))
      (when bounds (goto-char (car bounds)))))
  (let ((def (+lookup/definition))
        (refs (+lookup/references))
        (diags (lsp-diagnostics))
        (hover (lsp-describe-thing-at-point)))
    (message "=== Agent Analysis for '%s' ===\nDefinition: %s\nReferences: %s\nDiagnostics: %s\nHover: %s"
             symbol def refs diags hover)))

(provide 'config)
;;; config.el ends here
