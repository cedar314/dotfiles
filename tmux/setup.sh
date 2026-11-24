#!/usr/bin/env bash
set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/lib/common.sh"
parse_options "$@" && initialize || exit 1
source "$DOTFILES_ROOT/tmux/module.sh"
finish
