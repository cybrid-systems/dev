#!/bin/bash
set -euo pipefail

echo "=== 安装语言工具 (NodeJS/Python/Rust/Racket) ==="

export HOME=/home/dev

# ==================== Node.js (LTS) ====================
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash -
sudo apt-get install -y nodejs

# ==================== Python 工具 ====================
pipx ensurepath
pipx install isort pipenv nose pytest black pyflakes

# ==================== Rust + fd ====================
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
sudo ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true

# ==================== Racket ====================
VERSION=9.1
cd /tmp

case "$(uname -m)" in
x86_64 | amd64) RACKET_ARCH="x86_64" ;;
aarch64 | arm64) RACKET_ARCH="aarch64" ;;
*)
    echo "不支持的架构"
    exit 1
    ;;
esac

INSTALLER="racket-${VERSION}-${RACKET_ARCH}-linux-buster-cs.sh"
wget -q "https://download.racket-lang.org/installers/${VERSION}/${INSTALLER}" -O racket-installer.sh
chmod +x racket-installer.sh
./racket-installer.sh --unix-style --dest /usr/local
rm -f racket-installer.sh

raco pkg install --auto --skip-installed fmt racket-langserver

echo "=== 语言工具安装完成 ==="
