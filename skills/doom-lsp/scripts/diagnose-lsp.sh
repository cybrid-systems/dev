#!/bin/bash
# 诊断 LSP 服务器问题

echo "🔧 诊断 LSP 服务器问题"
echo "====================="

EMACSCLIENT="emacsclient -a ''"

echo "1. 测试 Emacs 基本连接..."
$EMACSCLIENT -e "(message \"Emacs connection test\")" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Emacs 连接正常"
else
    echo "❌ Emacs 连接失败"
    exit 1
fi

echo ""
echo "2. 测试 LSP 模块..."
$EMACSCLIENT -e "
(progn
  (if (featurep 'lsp-mode)
      (princ \"✅ lsp-mode 已加载\\n\")
    (progn
      (princ \"⚠️  lsp-mode 未加载，尝试加载...\\n\")
      (condition-case err
          (progn
            (require 'lsp-mode)
            (princ \"✅ lsp-mode 加载成功\\n\"))
        (error (princ (format \"❌ lsp-mode 加载失败: %s\\n\" (error-message-string err))))))))" 2>&1 | sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g'

echo ""
echo "3. 测试文件打开和 LSP 启动..."
$EMACSCLIENT -e "
(progn
  (require 'lsp-mode)
  (find-file \"/home/dev/code/redis/src/dict.c\")
  (princ \"✅ 文件已打开\\n\")
  
  (condition-case err
      (progn
        (lsp)
        (princ \"✅ lsp 命令执行成功\\n\")
        
        ;; 等待一下
        (sit-for 2)
        
        ;; 检查 workspace
        (let ((ws (lsp-find-workspace 'lsp-mode nil)))
          (if ws
              (progn
                (princ \"✅ 找到 LSP workspace\\n\")
                (princ (format \"Workspace root: %s\\n\" (lsp--workspace-root ws)))
                (princ (format \"Server: %s\\n\" (lsp--workspace-server-id ws))))
            (princ \"❌ 未找到 LSP workspace\\n\"))))
    (error (princ (format \"❌ lsp 命令失败: %s\\n\" (error-message-string err))))))" 2>&1 | sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g'

echo ""
echo "4. 检查 compile_commands.json..."
if [ -f "/home/dev/code/redis/compile_commands.json" ]; then
    echo "✅ compile_commands.json 存在"
    echo "   位置: /home/dev/code/redis/compile_commands.json"
    echo "   大小: $(stat -c%s /home/dev/code/redis/compile_commands.json) 字节"
else
    echo "❌ compile_commands.json 不存在"
fi

echo ""
echo "5. 检查 clangd 进程..."
CLANGD_PID=$(ps aux | grep clangd | grep -v grep | awk '{print $2}')
if [ -n "$CLANGD_PID" ]; then
    echo "✅ clangd 正在运行 (PID: $CLANGD_PID)"
    echo "   命令行: $(ps -p $CLANGD_PID -o cmd=)"
else
    echo "❌ clangd 未运行"
fi

echo ""
echo "6. 测试简单 LSP 请求..."
$EMACSCLIENT -e "
(progn
  (require 'lsp-mode)
  (find-file \"/home/dev/code/redis/src/dict.c\")
  (lsp)
  (sit-for 3)
  
  (let ((ws (lsp-find-workspace 'lsp-mode nil)))
    (if ws
        (progn
          (princ \"✅ 测试 LSP 请求...\\n\")
          (condition-case err
              (let ((response (lsp-request \"initialize\" 
                            (list :processId (emacs-pid)
                                  :rootPath (lsp--workspace-root ws)
                                  :capabilities (make-hash-table)))))
                (if response
                    (princ \"✅ initialize 请求成功\\n\")
                  (princ \"❌ initialize 请求返回空\\n\")))
            (error (princ (format \"❌ initialize 请求失败: %s\\n\" (error-message-string err))))))
      (princ \"❌ 无法测试：无 workspace\\n\"))))" 2>&1 | sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g'
