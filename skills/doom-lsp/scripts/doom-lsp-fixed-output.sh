#!/bin/bash
# doom-lsp-fixed-output.sh - 修复输出问题的版本

EMACSCLIENT="emacsclient -a ''"

# 处理 emacsclient 输出，移除引号
process_output() {
    # 移除开头的双引号，移除结尾的 \n" 或 "
    sed -e 's/^"//' -e 's/\\n"$//' -e 's/"$//' -e 's/\\n/ /g'
}

case "$1" in
    find-refs)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        echo "[INFO] find-refs for $SYMBOL"
        
        # 使用 process_output 处理输出
        timeout 30s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          
          (find-file \"$FILE\")
          (lsp)
          (sit-for 2)  ; 等待 LSP 就绪
          
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
                        (princ \"[INFO] 未找到引用\\n\"))
                       
                       ((eq response :json-false)
                        (princ \"[INFO] 未找到引用\\n\"))
                       
                       ((and (vectorp response) (= (length response) 0))
                        (princ \"[INFO] 找到 0 个引用\\n\"))
                       
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
                        (princ \"\\n\")))))
                  (princ \"[ERROR] LSP workspace 未找到\\n\")))
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")))" 2>&1 | process_output
        
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo "[WARNING] 操作超时"
        elif [ $EXIT_CODE -ne 0 ]; then
            echo "[WARNING] 退出代码: $EXIT_CODE"
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
