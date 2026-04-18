#!/bin/bash
# 安装 redis-analyzer 工具

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYZER_SCRIPT="$SCRIPT_DIR/scripts/redis-analyzer.sh"
INSTALL_DIR="/usr/local/bin"

echo "🔧 安装 Redis 分析工具"
echo "====================="

# 检查脚本是否存在
if [ ! -f "$ANALYZER_SCRIPT" ]; then
    echo "❌ 错误: 找不到 redis-analyzer.sh"
    echo "请确保在 doom-lsp 技能目录中运行"
    exit 1
fi

# 检查安装权限
if [ ! -w "$INSTALL_DIR" ]; then
    echo "⚠️  需要 sudo 权限安装到 $INSTALL_DIR"
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# 安装脚本
echo "安装 redis-analyzer 到 $INSTALL_DIR..."
$SUDO_CMD cp "$ANALYZER_SCRIPT" "$INSTALL_DIR/redis-analyzer"
$SUDO_CMD chmod +x "$INSTALL_DIR/redis-analyzer"

# 创建配置文件示例
CONFIG_EXAMPLE="$SCRIPT_DIR/references/redis-analyzer-config.sh"
cat > "$CONFIG_EXAMPLE" << 'EOF'
#!/bin/bash
# Redis 分析工具配置示例

# 设置 Redis 源码目录
export REDIS_DIR="/home/dev/code/redis"

# 可选：设置分析报告输出目录
export REDIS_REPORT_DIR="/tmp/redis-analysis"

# 可选：设置默认分析命令
export REDIS_DEFAULT_COMMANDS="set get incr decr lpush rpush"

# 可选：启用详细日志
# export REDIS_ANALYZER_VERBOSE=1

echo "Redis 分析工具配置已加载"
echo "Redis 目录: $REDIS_DIR"
EOF

chmod +x "$CONFIG_EXAMPLE"

echo ""
echo "✅ 安装完成！"
echo ""
echo "使用方法:"
echo "1. 设置环境变量（可选）:"
echo "   export REDIS_DIR=/path/to/redis"
echo ""
echo "2. 基本使用:"
echo "   redis-analyzer analyze set      # 分析 set 命令"
echo "   redis-analyzer batch            # 批量分析常用命令"
echo "   redis-analyzer interactive      # 交互式分析"
echo ""
echo "3. 查看帮助:"
echo "   redis-analyzer help"
echo ""
echo "4. 配置示例:"
echo "   参考: $CONFIG_EXAMPLE"
echo ""
echo "📝 注意:"
echo "   - 确保已安装 doom-lsp"
echo "   - Redis 项目需要 compile_commands.json"
echo "   - 首次使用建议运行: doom-lsp setup-project \$REDIS_DIR"

# 测试安装
if command -v redis-analyzer >/dev/null 2>&1; then
    echo ""
    echo "🔍 测试安装..."
    redis-analyzer help | head -10
    echo ""
    echo "🎉 安装成功！现在可以开始分析 Redis 代码了。"
else
    echo ""
    echo "⚠️  安装可能有问题，请检查 PATH 设置。"
fi