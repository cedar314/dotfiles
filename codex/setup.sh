#!/usr/bin/env bash
set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/lib/common.sh"
parse_options "$@" && initialize && bootstrap_environment || exit 1
# Keep the application home and skills directory real; reject unsafe parents
# before creating the home or linking any user-authored configuration.
python3 - "$DOTFILES_ROOT/lib" "$HOME/.codex" "$MODE" <<'PYHOME' || exit 1
from pathlib import Path
import sys

sys.path.insert(0, sys.argv[1])
from files import exists, safe_parents

home = Path(sys.argv[2]).absolute()
try:
    safe_parents(home / 'skills/placeholder')
    repo = Path(sys.argv[1]).resolve().parent
    if home == repo or repo in home.parents:
        raise ValueError('Codex home must be outside the repository')
    if exists(home) and not home.is_dir():
        raise ValueError('Codex home must be a real directory')
    if sys.argv[3] == 'apply':
        home.mkdir(mode=0o700, exist_ok=True)
except (OSError, ValueError) as error:
    print(f'[failed] {error}', file=sys.stderr)
    sys.exit(1)
PYHOME
if [[ -n ${CODEX_HOME:-} ]]; then
    status skipped 'Inherited CODEX_HOME is not managed; unset it in the launching shell to use ~/.codex'
fi
ensure_tool codex codex - || true
codex_home=$HOME/.codex
for name in config.toml AGENTS.md; do
    link_config "$DOTFILES_ROOT/codex/$name" "$codex_home/$name"
done
# Link individual custom skills; Codex owns the real skills directory.
for manifest in "$DOTFILES_ROOT/codex/skills/"*/SKILL.md; do
    [[ -f $manifest ]] || continue
    source_directory=$(dirname -- "$manifest")
    name=$(basename -- "$source_directory")
    config_link=$codex_home/skills/$name
    discovery_link=$HOME/.agents/skills/$name
    link_config "$source_directory" "$config_link"
    if [[ -L $config_link && $(readlink -f -- "$config_link") == "$source_directory" ]]; then
        link_config "$config_link" "$discovery_link"
    elif [[ $MODE != apply ]]; then
        missing "Would link $discovery_link -> $config_link after configuring the skill"
    else
        status skipped "Discovery link for $name: Codex-home skill destination was not configured"
    fi
done
finish
