#!/bin/bash
set -euo pipefail

export HOME=/home/dev
DOOM_BIN=$HOME/.config/emacs/bin/doom
DOOM_CONF_DIR=$HOME/.config/doom

# doom emacs
mkdir $DOOM_CONF_DIR -p
git clone --depth 1 https://github.com/hlissner/doom-emacs $HOME/.config/emacs
# amd64 build work around
mkdir -p ~/.config/emacs/.local/straight/repos
cd ~/.config/emacs/.local/straight/repos
git clone --depth 1 https://github.com/emacsmirror/gcmh.git gcmh
$DOOM_BIN env
$DOOM_BIN install --no-config --no-env
cp ~/*.el $DOOM_CONF_DIR
$DOOM_BIN sync

# install tree-sitter
emacs --batch --eval "
(progn (setq treesit-language-source-alist '((cpp \"https://github.com/tree-sitter/tree-sitter-cpp\") (c \"https://github.com/tree-sitter/tree-sitter-c\"))) (dolist (lang '(c cpp)) (treesit-install-language-grammar lang)))"
