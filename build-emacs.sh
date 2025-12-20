#!/bin/bash
set -euo pipefail

VERSION=30.2
GCC_VERSION=${GCC_VERSION:-14}

apt install -y libxpm-dev libjpeg-dev libpng-dev libgif-dev libtiff-dev libgnutls28-dev pkg-config fontconfig libjansson-dev libgccjit-$GCC_VERSION-dev fonts-emojione shfmt glslang-tools texinfo libtree-sitter-dev libncurses-dev

cd && wget https://mirrors.tuna.tsinghua.edu.cn/gnu/emacs/emacs-$VERSION.tar.xz || exit
tar -xf emacs-$VERSION.tar.xz || exit
cd emacs-$VERSION || exit
export CC=gcc-$GCC_VERSION CXX=g++-$GCC_VERSION
./configure --with-tree-sitter --with-gnutls --with-x-toolkit=no
make -j && make install

# clear
cd && rm emacs* -rf
