#!/bin/bash
set -euo pipefail

echo "=== 先编译 Emacs，然后安装 Doom Emacs ==="

# ==================== 编译 Emacs（原 build-emacs.sh 内容） ====================
cd /tmp
git clone -b emacs-30 https://github.com/emacs-mirror/emacs.git
cd emacs
./autogen.sh
./configure --with-native-compilation --with-tree-sitter --with-json --with-modules --with-pgtk \
    --with-cairo --with-xwidgets --with-x-toolkit=gtk3 --with-mailutils --without-compress-install
make -j$(nproc)
make install
cd /tmp && rm -rf emacs

# ==================== Doom Emacs ====================
DOOM_DIR=/root/.config/emacs
DOOM_BIN=$DOOM_DIR/bin/doom
DOOM_CONF=/root/.config/doom

mkdir -p $DOOM_CONF
git clone --depth 1 https://github.com/hlissner/doom-emacs $DOOM_DIR

$DOOM_BIN env
$DOOM_BIN install --no-config --no-env --force

# 复制配置
cp /root/*.el $DOOM_CONF/ 2>/dev/null || true

$DOOM_BIN sync -e

# 安装 tree-sitter grammar
emacs --batch --eval '
(progn
  (setq treesit-language-source-alist
        '\''((cpp "https://github.com/tree-sitter/tree-sitter-cpp")
              (c   "https://github.com/tree-sitter/tree-sitter-c")))
  (dolist (lang '\''(c cpp))
    (treesit-install-language-grammar lang)))' 2>/dev/null || true

echo "=== Emacs Stack 安装完成 ==="
