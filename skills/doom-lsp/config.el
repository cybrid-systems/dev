;;; config.el --- Doom LSP module configuration for Agent use

;; Use Doom's built-in lookup handlers instead of raw lsp calls
(after! lsp-mode
  (setq lsp-clients-clangd-args
        '("--background-index"
          "--clang-tidy"
          "--header-insertion=never"
          "--completion-style=detailed"
          "--pch-storage=memory"))

  ;; Enable for C/C++ and Python by default
  (add-to-list 'lsp-language-id-configuration '(c-mode . "c"))
  (add-to-list 'lsp-language-id-configuration '(c++-mode . "cpp"))

  ;; Use Doom's optimized lookup handlers (this replaces all the re-search-forward hacks)
  (set-lookup-handlers! '(c-mode c++-mode python-mode)
    :definition #'+lsp/lookup-definition
    :references #'+lsp/lookup-references
    :implementation #'+lsp/lookup-implementation
    :type-definition #'+lsp/lookup-type-definition)

  ;; Enable useful features for Agent
  (setq lsp-enable-symbol-highlighting t
        lsp-ui-sideline-enable t
        lsp-ui-doc-enable t
        lsp-signature-auto-activate t)

  (message "doom-lsp module loaded - Agent optimized"))

;; Provide a command for agent-analyze
(defun +doom-lsp/agent-analyze (file symbol)
  "One-shot full analysis for Agent: definition + references + diagnostics + hover."
  (interactive "fFile: \nsSymbol: ")
  (find-file file)
  (+lsp-deferred)
  (goto-char (point-min))
  (search-forward symbol nil t)
  (let ((def (ignore-errors (+lookup/definition)))
        (refs (ignore-errors (+lookup/references)))
        (diags (ignore-errors (lsp-diagnostics)))
        (hover (ignore-errors (lsp-describe-thing-at-point))))
    (message "Agent Analysis for %s:\nDefinition: %s\nReferences: %s\nDiagnostics: %s"
             symbol def refs diags)))

(provide 'config)
;;; config.el ends here
