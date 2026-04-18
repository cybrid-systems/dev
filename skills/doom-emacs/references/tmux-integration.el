;; tmux-gptel integration for Doom Emacs
;; Add to ~/.config/doom/config.el

;; tmux-gptel integration functions
(defun my/tmux-capture-to-gptel ()
  "Capture tmux pane content and insert into gptel."
  (interactive)
  (let ((cmd "tmux capture-pane -p -S -1000 | sed '/^[[:space:]]*$/d'"))
    (with-temp-buffer
      (call-process-shell-command cmd nil t)
      (when (derived-mode-p 'gptel-mode)
        (insert (buffer-string))
        (message "Tmux content inserted into gptel")))))

(defun my/gptel-to-tmux ()
  "Send gptel response to tmux for execution."
  (interactive)
  (let ((response (buffer-substring-no-properties
                   (point-min) (point-max))))
    (with-temp-buffer
      (insert response)
      (call-process-region (point-min) (point-max)
                           "bash" nil nil nil
                           "-c" "while IFS= read -r line; do tmux send-keys \"$line\" C-m; sleep 0.1; done")
      (message "Gptel response sent to tmux"))))

;; Keybindings for tmux-gptel workflow
(map! :map gptel-mode-map
      :localleader
      "t" #'my/tmux-capture-to-gptel
      "T" #'my/gptel-to-tmux)

;; Auto-capture compilation errors
(defun my/compile-with-gptel-capture ()
  "Run make and auto-capture errors to gptel."
  (interactive)
  (let ((default-directory (project-root (project-current))))
    (compile "make")
    (run-at-time "2 sec" nil
                 (lambda ()
                   (when (get-buffer "*compilation*")
                     (with-current-buffer "*compilation*"
                       (when (search-forward "error:" nil t)
                         (my/tmux-capture-to-gptel))))))))
