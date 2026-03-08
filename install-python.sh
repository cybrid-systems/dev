#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

pipx ensurepath

# doom doctor
pipx install isort pipenv nose pytest black pyflakes
