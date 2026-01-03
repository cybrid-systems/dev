#!/bin/bash

set -euo pipefail

DOOM_BIN=~/.config/emacs/bin/doom
DOOM_CONF_DIR=~/.config/doom

# doom emacs
mkdir $DOOM_CONF_DIR -p
git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.config/emacs

$DOOM_BIN env
$DOOM_BIN install --no-config --no-env
cp ~/*.el $DOOM_CONF_DIR
$DOOM_BIN sync

# install tree-sitter
emacs --batch --eval "
(progn
  (setq treesit-language-source-alist
        '((cpp \"https://github.com/tree-sitter/tree-sitter-cpp\")
          (c   \"https://github.com/tree-sitter/tree-sitter-c\")))
  (dolist (lang '(c cpp))
    (treesit-install-language-grammar lang)))"

# doom doctor
apt install -y markdown shellcheck ispell

# clear
cd && rm ./*.el -rf
