#!/bin/bash
set -euo pipefail

VERSION=30.2
GCC_VERSION=${GCC_VERSION:-16}
export HOME=/home/dev

cd /tmp
wget https://mirrors.tuna.tsinghua.edu.cn/gnu/emacs/emacs-$VERSION.tar.xz || exit
tar -xf emacs-$VERSION.tar.xz || exit
cd emacs-$VERSION || exit
export CC=gcc-$GCC_VERSION CXX=g++-$GCC_VERSION
./configure --with-tree-sitter --with-gnutls --with-x-toolkit=no
make -j && sudo make install
# clear
cd && rm emacs* -rf
