#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ln -s $(which fdfind) /usr/local/bin/fd
