#!/bin/bash
set -e

if [ -n "$USER_UID" ] && [ "$USER_UID" != "1000" ]; then
    usermod -u "$USER_UID" dev 2>/dev/null || true
fi
if [ -n "$USER_GID" ] && [ "$USER_GID" != "1000" ]; then
    groupmod -g "$USER_GID" dev 2>/dev/null || true
fi

chown -R dev:dev /home/dev/code 2>/dev/null || true

exec su - dev -c "$@"
