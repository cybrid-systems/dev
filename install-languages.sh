#!/bin/bash
set -euo pipefail

# ==================== Python 工具 ====================
# 先确保/home/dev/.cache权限（可选，但防止root写问题）
chown -R dev:dev /home/dev 2>/dev/null || true

# 以dev用户运行pipx，避免权限问题
su - dev -c "pipx ensurepath"
su - dev -c "pipx install isort pipenv nose pytest black pyflakes"
echo "正在为 dev 用户安装 pexpect 并验证..."
if ! su - dev -c "
    pip install pexpect --user --break-system-packages
    python3 -c 'import pexpect; print(\"✅ pexpect 安装成功，路径：\", pexpect.__file__)'
"; then
    echo "❌ pexpect 安装失败或验证不通过，请检查网络或 Python 环境"
    exit 1
fi
# --- 新增：给 root 用户全局安装（CI 直接可用）---
pip install --break-system-packages pexpect

echo "=== 语言工具安装完成 ==="
