#!/bin/bash
# doom-lsp-final-working.sh - 最终能工作的版本

EMACSCLIENT="emacsclient -a ''"

case "$1" in
    find-refs)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        echo "[INFO] find-refs for $SYMBOL"
        
        timeout 25s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          
          (find-file \"$FILE\")
          (lsp)
          
          (goto-char (point-min))
          (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
              (let* ((line (line-number-at-pos))
                     (col (current-column))
                     (params (list :textDocument (lsp--text-document-identifier)
                                   :position (list :line (1- line) :character col)
                                   :context (list :includeDeclaration t)))
                     (workspace (lsp-find-workspace 'lsp-mode nil)))
                
                (if workspace
                    (let ((response (lsp-request \"textDocument/references\" params)))
                      (cond
                       ((null response)
                        (princ \"[INFO] 未找到引用\\n\")
                        nil)
                       
                       ((eq response :json-false)
                        (princ \"[INFO] 未找到引用\\n\")
                        nil)
                       
                       (t
                        (princ (format \"[SUCCESS] 找到 %d 个引用\\n\\n\" (length response)))
                        (dolist (ref response)
                          (let* ((uri (gethash \"uri\" ref))
                                 (range (gethash \"range\" ref))
                                 (start (gethash \"start\" range))
                                 (line (1+ (gethash \"line\" start)))
                                 (col (1+ (gethash \"character\" start)))
                                 (filename (file-name-nondirectory uri)))
                            (princ (format \"  %s:%d:%d\\n\" filename line col))))
                        (princ \"\\n\")
                        t)))
                  (princ \"[ERROR] LSP workspace 未找到\\n\")
                  nil))
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")
            nil))" 2>&1 | \
            grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"
        
        if [ $? -eq 124 ]; then
            echo "[WARNING] 操作超时"
        fi
        ;;
        
    test)
        echo "[INFO] 测试 find-refs..."
        $0 find-refs /home/dev/code/workspace/test-lsp/src/main.c hello
        ;;
        
    *)
        echo "用法: doom-lsp find-refs <文件> <符号>"
        echo "       doom-lsp test"
        ;;
esac
