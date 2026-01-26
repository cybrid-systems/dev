#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

VERSION=9.0

cd && wget https://github.com/racket/racket/archive/refs/tags/v$VERSION.tar.gz
tar zxvf v$VERSION.tar.gz
cd racket-$VERSION
make unix-style PREFIX=/usr/local JOBS=10

rm -rf v$VERSION.tar.gz racket-$VERSION
