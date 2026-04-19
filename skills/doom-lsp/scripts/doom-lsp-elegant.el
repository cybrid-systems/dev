;;; doom-lsp-elegant.el - 优雅的 LSP 桥接实现
;; 避免 bash 中的复杂字符串拼接，使用纯 elisp 函数

(defun doom-lsp--ensure-file-opened (file)
  "确保文件已打开并 LSP 就绪"
  (unless (and (buffer-live-p (get-file-buffer file))
               (lsp-find-workspace 'lsp-mode nil))
    (find-file file)
    (lsp)
    (sit-for 1)))

(defun doom-lsp--find-symbol-position (file symbol)
  "在文件中查找符号位置"
  (doom-lsp--ensure-file-opened file)
  (with-current-buffer (get-file-buffer file)
    (goto-char (point-min))
    (if (re-search-forward (regexp-quote symbol) nil t)
        (point)
      nil)))

;; 主要功能函数
(defun doom-lsp-health-check ()
  "健康检查"
  (if (and (daemonp) (boundp 'lsp-mode))
      (progn
        (message "INFO: Emacs daemon 正在运行")
        (message "SUCCESS: LSP 模块已加载")
        t)
    (progn
      (message "ERROR: Emacs daemon 或 LSP 未就绪")
      nil)))

(defun doom-lsp-setup-project (project-dir)
  "设置项目"
  (message "INFO: 设置项目: %s" project-dir)
  (let ((compile-commands (expand-file-name "compile_commands.json" project-dir)))
    (if (file-exists-p compile-commands)
        (progn
          (message "SUCCESS: 找到 compile_commands.json")
          (message "COMPILE_COMMANDS_FOUND:%s" compile-commands))
      (message "WARNING: 未找到 compile_commands.json"))))

(defun doom-lsp-open-file (file line &optional col)
  "打开文件"
  (message "INFO: 打开 %s (行:%s 列:%s)" file line (or col 1))
  (find-file file)
  (goto-line line)
  (move-to-column (or col 1))
  (lsp)
  (message "SUCCESS: 文件已打开并触发 LSP"))

(defun doom-lsp-find-def (file symbol)
  "查找定义"
  (message "INFO: find-def (gd) for %s" symbol)
  (if-let ((pos (doom-lsp--find-symbol-position file symbol)))
      (progn
        (with-current-buffer (get-file-buffer file)
          (goto-char pos)
          (lsp-find-definition))
        (message "SUCCESS: find-def 完成"))
    (message "ERROR: 符号 %s 未找到" symbol)))

(defun doom-lsp-find-refs (file symbol)
  "查找引用"
  (message "INFO: find-refs (SPC c D) for %s" symbol)
  (if-let ((pos (doom-lsp--find-symbol-position file symbol)))
      (progn
        (with-current-buffer (get-file-buffer file)
          (goto-char pos)
          (let ((refs (lsp-find-references)))
            (if refs
                (message "SUCCESS: 找到 %d 个引用" (length refs))
              (message "INFO: 未找到引用（可能需要索引）"))))
        (message "SUCCESS: find-refs 完成"))
    (message "ERROR: 符号 %s 未找到" symbol)))

(defun doom-lsp-hover (file line &optional col)
  "显示 hover 信息"
  (message "INFO: hover at %s:%s:%s" file line (or col 0))
  (doom-lsp--ensure-file-opened file)
  (with-current-buffer (get-file-buffer file)
    (goto-line line)
    (move-to-column (or col 0))
    (lsp-describe-thing-at-point))
  (message "SUCCESS: hover 完成"))

;; 命令行接口
(defun doom-lsp-command (command &rest args)
  "统一的命令行接口"
  (let ((result (pcase command
                  ("health-check" (doom-lsp-health-check))
                  ("setup-project" (doom-lsp-setup-project (car args)))
                  ("open-file" (apply #'doom-lsp-open-file args))
                  ("find-def" (apply #'doom-lsp-find-def args))
                  ("find-refs" (apply #'doom-lsp-find-refs args))
                  ("hover" (apply #'doom-lsp-hover args))
                  (_ (progn (message "ERROR: 未知命令: %s" command) nil)))))
    ;; 确保所有消息都被刷新
    (sit-for 0.1)
    result))

(provide 'doom-lsp-elegant)
