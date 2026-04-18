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
