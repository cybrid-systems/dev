#!/bin/bash
set -e

# 支持 Mac（UID 通常 501）和 Linux（1000）的动态权限
if [ -n "$USER_UID" ] && [ "$USER_UID" != "1000" ]; then
    usermod -u "$USER_UID" dev 2>/dev/null || true
fi
if [ -n "$USER_GID" ] && [ "$USER_GID" != "1000" ]; then
    groupmod -g "$USER_GID" dev 2>/dev/null || true
fi

# 自动修复挂载目录权限
chown -R dev:dev /home/dev/code 2>/dev/null || true

# 使用 Ubuntu 内置 su 执行（最稳定、无 setuid 问题）
exec su - dev -c "$@"
