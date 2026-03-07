#!/bin/bash

set -euo pipefail

GCC_VERSION=14
export DEBIAN_FRONTEND=noninteractive

# base
apt update
apt install -y build-essential apt-utils git zsh vim tmux curl wget libssl-dev ack-grep rsync ccache software-properties-common python3-dev net-tools bc bear libelf-dev pandoc tree

# gcc-14
add-apt-repository -y ppa:ubuntu-toolchain-r/test
apt update
apt -y install gcc-$GCC_VERSION g++-$GCC_VERSION
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-$GCC_VERSION 60 --slave /usr/bin/g++ g++ /usr/bin/g++-$GCC_VERSION
update-alternatives --set gcc /usr/bin/gcc-$GCC_VERSION

# locale
apt update
apt -y install locales tzdata
locale-gen en_US.UTF-8
echo "LANG=en_US.UTF-8" >>/etc/default/locale
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

# git
git config --global merge.conflictstyle diff3
