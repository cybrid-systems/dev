#!/bin/bash
# Redis 实际工作流测试 - 分析哈希表实现
# 这是一个完整的代码分析工作流，模拟 Agent 实际使用场景

echo "🔍 Redis 代码分析工作流 - 哈希表实现分析"
echo "=========================================="
echo "时间: $(date)"
echo "目标: 分析 Redis dict.c 中的 dictAdd 函数及其相关代码"
echo ""

# 1. 初始化环境
echo "1. 🏁 初始化工作环境"
echo "检查 Emacs daemon 和 LSP..."
doom-lsp health-check
echo ""

# 2. 设置 Redis 项目
echo "2. 📁 设置 Redis 项目"
doom-lsp setup-project /home/dev/code/redis
echo ""

# 3. 打开核心文件
echo "3. 📄 打开核心文件 dict.c"
echo "打开文件到 dictAdd 函数附近..."
doom-lsp open-file /home/dev/code/redis/src/dict.c 150
echo "等待 LSP 索引完成..."
sleep 8
echo ""

# 4. 分析 dictAdd 函数
echo "4. 🔎 分析 dictAdd 函数"
echo "4.1 查找 dictAdd 定义..."
doom-lsp find-def /home/dev/code/redis/src/dict.c dictAdd
echo ""

echo "4.2 查看 dictAdd 的调用关系..."
echo "查找 dictAdd 的引用（可能需要时间）..."
doom-lsp find-refs /home/dev/code/redis/src/dict.c dictAdd
echo ""

# 5. 分析相关数据结构
echo "5. 🏗️ 分析相关数据结构"
echo "5.1 查找 dict 结构体定义..."
doom-lsp find-def /home/dev/code/redis/src/dict.c dict
echo ""

echo "5.2 查找 dictType 结构体..."
doom-lsp find-def /home/dev/code/redis/src/dict.c dictType
echo ""

# 6. 分析关键函数
echo "6. ⚙️ 分析关键相关函数"
echo "6.1 查找 dictFind 函数..."
doom-lsp find-def /home/dev/code/redis/src/dict.c dictFind
echo ""

echo "6.2 查找 dictDelete 函数..."
doom-lsp find-def /home/dev/code/redis/src/dict.c dictDelete
echo ""

# 7. 实际使用场景模拟
echo "7. 🎯 实际使用场景模拟"
echo "7.1 打开 server.c 查看 dictAdd 的使用..."
doom-lsp open-file /home/dev/code/redis/src/server.c 1
sleep 3
echo ""

echo "7.2 在 server.c 中查找 dict 相关使用..."
echo "查找 initServer 函数（包含 dict 初始化）..."
doom-lsp find-def /home/dev/code/redis/src/server.c initServer
echo ""

# 8. 工作流总结
echo "8. 📊 工作流完成总结"
echo ""
echo "✅ 工作流执行完成！"
echo ""
echo "📈 分析成果："
echo "  ✓ Redis 项目环境设置完成"
echo "  ✓ 核心文件 dict.c 已打开并索引"
echo "  ✓ dictAdd 函数定义已定位"
echo "  ✓ 相关数据结构（dict, dictType）已分析"
echo "  ✓ 关键相关函数（dictFind, dictDelete）已查找"
echo "  ✓ 实际使用场景（server.c）已探索"
echo ""
echo "🎯 工作流价值："
echo "  这个工作流展示了 Agent 如何："
echo "  1. 快速设置项目环境"
echo "  2. 定位核心函数定义"
echo "  3. 分析代码结构和调用关系"
echo "  4. 探索实际使用场景"
echo ""
echo "🔧 后续工作建议："
echo "  1. 深入分析 dictAdd 的实现细节"
echo "  2. 查看哈希冲突处理逻辑"
echo "  3. 分析 rehash 机制"
echo "  4. 研究性能优化技巧"
echo ""
echo "工作流脚本: skills/doom-lsp/scripts/redis-workflow.sh"
