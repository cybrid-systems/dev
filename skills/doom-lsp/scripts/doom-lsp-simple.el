;;; doom-lsp-simple.el - 简单的 LSP 桥接实现
;; 直接输出消息到标准输出

(defun doom-lsp-print (level message)
  "打印消息到标准输出"
  (princ (format "[%s] %s\n" level message)))

(defun doom-lsp-health-check ()
  "健康检查"
  (if (and (daemonp) (boundp 'lsp-mode))
      (progn
        (doom-lsp-print "INFO" "Emacs daemon 正在运行")
        (doom-lsp-print "SUCCESS" "LSP 模块已加载")
        t)
    (progn
      (doom-lsp-print "ERROR" "Emacs daemon 或 LSP 未就绪")
      nil)))

(defun doom-lsp-setup-project (project-dir)
  "设置项目"
  (doom-lsp-print "INFO" (format "设置项目: %s" project-dir))
  (let ((compile-commands (expand-file-name "compile_commands.json" project-dir)))
    (if (file-exists-p compile-commands)
        (progn
          (doom-lsp-print "SUCCESS" "找到 compile_commands.json")
          (princ (format "COMPILE_COMMANDS_FOUND:%s\n" compile-commands)))
      (doom-lsp-print "WARNING" "未找到 compile_commands.json"))))

(defun doom-lsp-open-file (file line &optional col)
  "打开文件"
  (doom-lsp-print "INFO" (format "打开 %s (行:%s 列:%s)" file line (or col 1)))
  (find-file file)
  (goto-line line)
  (move-to-column (or col 1))
  (lsp)
  (doom-lsp-print "SUCCESS" "文件已打开并触发 LSP"))

(defun doom-lsp-find-symbol-position (file symbol)
  "在文件中查找符号位置"
  (find-file file)
  (lsp)
  (goto-char (point-min))
  (if (re-search-forward (regexp-quote symbol) nil t)
      (point)
    nil))

(defun doom-lsp-find-def (file symbol)
  "查找定义"
  (doom-lsp-print "INFO" (format "find-def (gd) for %s" symbol))
  (if-let ((pos (doom-lsp-find-symbol-position file symbol)))
      (progn
        (goto-char pos)
        (lsp-find-definition)
        (doom-lsp-print "SUCCESS" "find-def 完成"))
    (doom-lsp-print "ERROR" (format "符号 %s 未找到" symbol))))

(defun doom-lsp-find-refs (file symbol)
  "查找引用"
  (doom-lsp-print "INFO" (format "find-refs (SPC c D) for %s" symbol))
  (if-let ((pos (doom-lsp-find-symbol-position file symbol)))
      (progn
        (goto-char pos)
        (let ((refs (lsp-find-references)))
          (if refs
              (doom-lsp-print "INFO" (format "找到 %d 个引用" (length refs)))
            (doom-lsp-print "INFO" "未找到引用（可能需要索引）")))
        (doom-lsp-print "SUCCESS" "find-refs 完成"))
    (doom-lsp-print "ERROR" (format "符号 %s 未找到" symbol))))

(defun doom-lsp-hover (file line &optional col)
  "显示 hover 信息"
  (doom-lsp-print "INFO" (format "hover at %s:%s:%s" file line (or col 0)))
  (find-file file)
  (lsp)
  (goto-line line)
  (move-to-column (or col 0))
  (lsp-describe-thing-at-point)
  (doom-lsp-print "SUCCESS" "hover 完成"))

;; 主入口点
(defun doom-lsp-main ()
  "主函数，从命令行参数读取命令"
  (let ((command (pop argv))
        (args argv))
    (pcase command
      ("health-check" (doom-lsp-health-check))
      ("setup-project" (doom-lsp-setup-project (car args)))
      ("open-file" (apply #'doom-lsp-open-file args))
      ("find-def" (apply #'doom-lsp-find-def args))
      ("find-refs" (apply #'doom-lsp-find-refs args))
      ("hover" (apply #'doom-lsp-hover args))
      (_ (doom-lsp-print "ERROR" (format "未知命令: %s" command))))))

;; 如果直接运行这个文件
(when (and noninteractive (member "--doom-lsp" argv))
  (doom-lsp-main))
