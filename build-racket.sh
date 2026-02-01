#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

VERSION=9.0

apt install -y xvfb libcairo2  libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0

cd && wget https://github.com/racket/racket/archive/refs/tags/v$VERSION.tar.gz
tar zxvf v$VERSION.tar.gz
cd racket-$VERSION
make unix-style PREFIX=/usr/local JOBS=10
raco pkg install --auto fmt
raco pkg install --auto racket-langserver

rm -rf v$VERSION.tar.gz racket-$VERSION
