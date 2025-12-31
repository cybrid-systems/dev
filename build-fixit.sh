#!/bin/bash

set -euo pipefail

echo 'export PATH="$PATH:/root/.local/bin"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TERM=xterm-256color' >> ~/.zshrc
