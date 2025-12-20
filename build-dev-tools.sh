#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/usr/local/lib64}"
CMAKE_VERSION=v4.2.1
CMAKE_TARGZ=cmake-$CMAKE_VERSION.tar.gz
CMAKE_HOME=CMake-${CMAKE_VERSION:1}

apt update

# cmake
cd && wget https://github.com/Kitware/CMake/archive/refs/tags/$CMAKE_VERSION.tar.gz -O $CMAKE_TARGZ
tar zxvf $CMAKE_TARGZ
cd $CMAKE_HOME || exit
./bootstrap --parallel=64
make -j10 && make install

# ninja
cd && git clone https://github.com/ninja-build/ninja.git && cd ninja || exit
git checkout release
python3 ./configure.py --bootstrap
cp ninja /usr/local/bin

# zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# tmux
cd && git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .
# config tmux
cat >> .tmux.conf.local << 'EOF'
set -g history-limit 100000
set -g status-keys vi
set -g mode-keys vi
set -gu prefix2
unbind C-a
unbind C-b
bind-key -T copy-mode-vi 'v' send -X begin-selection
bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel
set -g prefix M-o
bind M-o send-prefix
EOF

# clear
cd && rm $CMAKE_TARGZ $CMAKE_HOME ninja -rf
