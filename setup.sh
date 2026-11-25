#!/usr/bin/env bash
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
modules=(git docker wezterm tmux nvim codex zsh nvm pnpm gh md-to-pdf)
options=()
selected=()
rollback=0
usage() {
    printf 'Usage: %s [--check|--dry-run] [MODULE ...|--all|--rollback]\n' "$0"
    printf 'Modules: %s\n' "${modules[*]}"
}
for argument in "$@"; do
    case $argument in
        --check|--dry-run) options+=("$argument") ;;
        --all) selected=("${modules[@]}") ;;
        --rollback) rollback=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            valid=0
            for module in "${modules[@]}"; do [[ $argument != "$module" ]] || valid=1; done
            (( valid )) || { usage >&2; exit 2; }
            selected+=("$argument") ;;
    esac
 done
if (( rollback )); then
    (( ${#selected[@]} == 0 )) || { printf 'Use --rollback without modules\n' >&2; exit 2; }
    source "$ROOT/lib/common.sh"
    parse_options "${options[@]}" && initialize || exit 1
    python3 "$ROOT/lib/files.py" rollback --repo "$ROOT" --state "$DOTFILES_STATE" --mode "$MODE"
    exit $?
fi
if (( ${#selected[@]} == 0 )); then
    printf 'Select modules (space-separated numbers, or all):\n'
    for index in "${!modules[@]}"; do printf '%2d) %s\n' "$((index + 1))" "${modules[index]}"; done
    IFS= read -r selection || { printf 'No selection; nothing changed.\n'; exit 0; }
    if [[ $selection == all ]]; then selected=("${modules[@]}"); else
        read -r -a numbers <<< "$selection"
        for number in "${numbers[@]}"; do
            [[ $number =~ ^([1-9]|10|11)$ ]] || { printf 'Invalid selection: %s\n' "$number" >&2; exit 2; }
            selected+=("${modules[number-1]}")
        done
    fi
fi
source "$ROOT/lib/common.sh"
parse_options "${options[@]}" && initialize && bootstrap_environment || exit 1
export DOTFILES_ENV_READY=1
result=$FAILED
seen=' '
for module in "${selected[@]}"; do
    [[ $seen != *" $module "* ]] || continue
    seen+="$module "
    printf '\nModule: %s\n' "$module"
    bash "$ROOT/$module/setup.sh" "${options[@]}" || result=1
 done
exit "$result"
