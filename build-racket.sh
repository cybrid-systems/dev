#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

VERSION=9.1

apt install -y xvfb libcairo2  libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0 libgtk2.0-0 libgdk-pixbuf2.0-0 libx11-6 libcanberra-gtk-module

cd && wget https://github.com/racket/racket/archive/refs/tags/v$VERSION.tar.gz
tar zxvf v$VERSION.tar.gz
cd racket-$VERSION
make unix-style PREFIX=/usr/local JOBS=14
raco pkg install --auto fmt
raco pkg install --auto racket-langserver

rm -rf v$VERSION.tar.gz racket-$VERSION
