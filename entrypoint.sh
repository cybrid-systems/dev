#!/bin/bash
set -e
# Adjust UID/GID if provided
if [ -n "$USER_UID" ] && [ "$USER_UID" != "$(id -u dev)" ]; then
    usermod -u "$USER_UID" dev 2>/dev/null || true
fi
if [ -n "$USER_GID" ] && [ "$USER_GID" != "$(id -g dev)" ]; then
    groupmod -g "$USER_GID" dev 2>/dev/null || true
fi
# Fix ownership for mounted volume and home
chown -R dev:dev /home/dev/code 2>/dev/null || true
chown -R dev:dev /home/dev 2>/dev/null || true
# Drop to dev user with gosu (handles TTY properly)
exec /usr/local/bin/gosu dev "$@"
