#!/bin/bash
set -euo pipefail

# 默认值（镜像内固定为 1000）
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

# 如果传入的 UID/GID 和当前不一样，就动态修改
if [ "$USER_UID" != "$(id -u dev)" ] || [ "$USER_GID" != "$(id -g dev)" ]; then
    echo "🔧 正在调整 dev 用户 UID/GID → ${USER_UID}:${USER_GID}（匹配宿主机）"
    groupmod -o -g "${USER_GID}" dev
    usermod -o -u "${USER_UID}" dev
    chown -R dev:dev /home/dev
fi

# 给 code 目录也 chown（挂载卷）
chown -R dev:dev /home/dev/code 2>/dev/null || true

# 切换到 dev 用户并执行命令（保留所有 sudo 权限）
exec gosu dev "$@"
