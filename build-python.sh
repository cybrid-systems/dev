#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y \
    python3-pip \
    python3-venv \
    python3-full \
    pipx

pipx ensurepath

# doom doctor
pipx install isort pipenv nose pytest black pyflakes
