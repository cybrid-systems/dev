#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

VERSION=9.1

apt-get update -qq
apt-get install -y xvfb \
    libgtk2.0-0 \
    libglib2.0-0 \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0

# === 自动检测 Docker --platform ===
case "$(uname -m)" in
x86_64 | amd64)
    RACKET_ARCH="x86_64"
    ;;
aarch64 | arm64)
    RACKET_ARCH="aarch64"
    ;;
*)
    echo "❌ 不支持的架构: $(uname -m)"
    exit 1
    ;;
esac

echo "=== 正在安装 Racket ${VERSION} (${RACKET_ARCH}) ==="

cd /tmp
INSTALLER="racket-${VERSION}-${RACKET_ARCH}-linux-buster-cs.sh"

wget --progress=bar:force "https://download.racket-lang.org/installers/${VERSION}/${INSTALLER}" -O racket-installer.sh
chmod +x racket-installer.sh

cat <<EOF | ./racket-installer.sh
yes
/usr/local
EOF

rm -f racket-installer.sh

# === 安装你需要的包 ===
echo "=== 安装 fmt 和 racket-langserver ==="
raco pkg install --auto --skip-installed fmt racket-langserver

echo "✅ Racket 9.1 安装完成！"
