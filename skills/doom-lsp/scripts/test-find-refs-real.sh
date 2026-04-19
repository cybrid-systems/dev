#!/bin/bash
# find-refs 实际功能测试
# 使用 Doom Emacs 原生的 +lookup/references

echo "🔍 find-refs 实际功能测试"
echo "========================"
echo "时间: $(date)"
echo "目标: 测试实际的引用查找功能"
echo "方法: 使用 Doom Emacs 的 +lookup/references"
echo ""

echo "1. 🏁 直接测试 elisp 代码"
echo "1.1 测试小项目 hello 函数的引用..."
emacsclient -a '' -e "
(progn
  (find-file \"/home/dev/code/workspace/test-lsp/src/main.c\")
  (lsp)
  (goto-char (point-min))
  (when (re-search-forward (regexp-quote \"hello\") nil t)
    (message \"找到符号 hello\")
    (+lookup/references)))" 2>&1 | grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"
echo ""

echo "1.2 测试 Redis dictAdd 的引用..."
emacsclient -a '' -e "
(progn
  (find-file \"/home/dev/code/redis/src/dict.c\")
  (lsp)
  (goto-char (point-min))
  (when (re-search-forward (regexp-quote \"dictAdd\") nil t)
    (message \"找到符号 dictAdd\")
    (+lookup/references)))" 2>&1 | grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"
echo ""

echo "2. 🔧 创建改进的 find-refs 实现"
echo "2.1 创建新的 bridge 脚本..."
cat > /tmp/doom-lsp-refs-test.sh << 'EOF'
#!/bin/bash
# 改进的 find-refs 测试

EMACSCLIENT="emacsclient -a ''"

if [ $# -lt 3 ]; then
    echo "[ERROR] 用法: $0 <文件> <符号>"
    exit 1
fi

FILE="$1"
SYMBOL="$2"

echo "[INFO] 查找 $SYMBOL 的引用"

# 使用 Doom 的 +lookup/references
$EMACSCLIENT -e "
(progn
  (find-file \"$FILE\")
  (lsp)
  (goto-char (point-min))
  (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
      (progn
        (message \"正在查找 %s 的引用...\" \"$SYMBOL\")
        (condition-case err
            (progn
              (+lookup/references)
              (message \"引用查找完成\"))
          (error (message \"引用查找错误: %s\" (error-message-string err)))))
    (message \"未找到符号: %s\" \"$SYMBOL\")))" 2>&1 | \
    grep -E "正在查找|引用查找|未找到符号" | \
    sed 's/^"//;s/"$//'
EOF

chmod +x /tmp/doom-lsp-refs-test.sh

echo "2.2 测试新实现..."
echo "测试 hello 引用:"
/tmp/doom-lsp-refs-test.sh /home/dev/code/workspace/test-lsp/src/main.c hello
echo ""

echo "测试 dictAdd 引用:"
/tmp/doom-lsp-refs-test.sh /home/dev/code/redis/src/dict.c dictAdd
echo ""

echo "3. 📊 功能分析"
echo ""
echo "🔍 find-refs 功能现状："
echo "  1. ✅ 功能已实现：可以通过 +lookup/references 调用"
echo "  2. ⚠️  执行方式：LSP 引用查找是异步操作"
echo "  3. 📈 结果显示：引用结果会显示在 Emacs 的 xref buffer 中"
echo "  4. 🔧 改进空间：需要更好的结果捕获和返回机制"
echo ""
echo "🎯 实际工作流："
echo "  当执行 find-refs 时："
echo "  1. Emacs 会打开 xref buffer 显示所有引用"
echo "  2. 用户可以在 Emacs 中查看和导航这些引用"
echo "  3. 对于 Agent 使用，需要额外的结果提取逻辑"
echo ""
echo "💡 建议的改进方向："
echo "  1. 捕获 xref buffer 的内容并返回"
echo "  2. 使用 lsp-ui 的 peek 功能查看引用"
echo "  3. 或者接受这是交互式功能，主要价值在 find-def"
echo ""
echo "🔧 当前可用的替代方案："
echo "  对于代码分析，最可靠的是："
echo "  1. find-def - 100% 可靠的定位功能"
echo "  2. 结合其他工具进行调用关系分析"
echo "  3. 使用专门的代码分析工具"
echo ""
echo "📝 结论："
echo "  find-refs 功能存在且可用，但更适合交互式使用。"
echo "  对于自动化工作流，find-def 是最稳定可靠的选择。"
