#!/usr/bin/env bash
# Shared by standalone modules and the root menu. Bash 4+ and Python 3 required.
set -uo pipefail
DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
MODE=apply
FAILED=0
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
DOTFILES_STATE=$STATE_HOME/dotfiles
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 HOMEBREW_NO_INSTALL_UPGRADE=1
export HOMEBREW_NO_ANALYTICS=1

status() { printf '[%s] %s\n' "$1" "$2"; }
fail() { status failed "$*"; FAILED=1; }
confirm() {
    local answer
    printf '%s [y/N] ' "$*" >&2
    IFS= read -r answer || return 1
    [[ $answer == y || $answer == Y || $answer == yes ]]
}
parse_options() {
    local option
    for option in "$@"; do
        case $option in
            --check) MODE=check ;;
            --dry-run) MODE=dry-run ;;
            *) printf 'Unknown option: %s\n' "$option" >&2; return 1 ;;
        esac
    done
}
initialize() {
    local kernel os_id path
    [[ ${BASH_VERSINFO[0]} -ge 4 ]] || { fail 'Bash 4+ required'; return 1; }
    command -v python3 >/dev/null || { fail 'Python 3 required'; return 1; }
    for path in "$HOME" "$CONFIG_HOME" "$DATA_HOME" "$STATE_HOME"; do
        [[ $path == /* ]] || { fail 'HOME and XDG paths must be absolute'; return 1; }
    done
    for path in "${CODEX_HOME:-$HOME/.codex}" "${NVM_DIR:-$DATA_HOME/nvm}"; do
        [[ $path == /* ]] || { fail 'CODEX_HOME and NVM_DIR must be absolute when set'; return 1; }
    done
    kernel=$(uname -s)
    os_id=$(awk -F= '$1 == "ID" {gsub(/"/, "", $2); print $2}' /etc/os-release 2>/dev/null)
    [[ $kernel == Linux && $os_id == ubuntu ]] || { fail 'Supported platform: Ubuntu Linux (including WSL2)'; return 1; }
    # Homebrew may be installed but absent from a fresh shell's PATH.
    if ! command -v brew >/dev/null && [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        PATH=/home/linuxbrew/.linuxbrew/bin:$PATH
        export PATH
    fi
}
finish() {
    if (( FAILED )); then status failed 'Some checks or operations failed'; return 1; fi
    status complete "Mode: $MODE. Review installed/configured/already configured/skipped messages above."
}
missing() {
    status missing "$*"
    [[ $MODE != check ]] || FAILED=1
}
link_config() {
    python3 "$DOTFILES_ROOT/lib/files.py" link --source "$1" --destination "$2" \
        --repo "$DOTFILES_ROOT" --state "$DOTFILES_STATE" --mode "$MODE" || FAILED=1
}
privileged() {
    if (( EUID == 0 )); then "$@"; else
        command -v sudo >/dev/null || { fail 'sudo is required for this operation'; return 1; }
        sudo -- "$@"
    fi
}
apt_install() {
    local simulation
    [[ $MODE == apply ]] || { missing "APT would install: $*"; return 0; }
    command -v apt-get >/dev/null || { fail 'APT unavailable'; return 1; }
    simulation=$(LC_ALL=C apt-get --simulate --no-upgrade install -- "$@" 2>&1) || {
        fail "APT cannot resolve requested packages: $*. Refresh package indexes manually if needed."; return 1;
    }
    # Inst NAME [OLD] means upgrade/reinstall; removals are never authorized here.
    if printf '%s\n' "$simulation" | grep -Eq '^Remv |^Inst [^ ]+ \['; then
        fail 'APT transaction would replace existing packages; review manually'; return 1
    fi
    printf '%s\n' "$simulation"
    confirm "Install missing APT packages ($*)? sudo may be required; package services may start." || {
        status skipped "APT installation: $*"; return 1;
    }
    privileged apt-get --no-upgrade --no-remove install -- "$@" || { fail 'APT installation failed'; return 1; }
    status installed "APT: $*"
}
brew_install() {
    local formula=$1 dependencies outdated dependency
    [[ $MODE == apply ]] || { missing "Homebrew would install: $formula"; return 0; }
    if [[ -n $(brew list --versions "$formula" 2>/dev/null) ]]; then
        fail "$formula is already installed through Homebrew but unavailable on PATH; resolve PATH manually"
        return 1
    fi
    # Conservatively reject any outdated installed dependency. Do not let install
    # implicitly upgrade dependencies, dependents, or an existing target.
    dependencies=$(brew deps --include-build "$formula") || { fail "Cannot inspect dependencies: $formula"; return 1; }
    outdated=$(brew outdated --quiet --formula) || { fail 'Cannot inspect Homebrew versions'; return 1; }
    while IFS= read -r dependency; do
        [[ -n $dependency ]] || continue
        if printf '%s\n' "$outdated" | grep -Fxq -- "$dependency"; then
            fail "Homebrew dependency $dependency is outdated; review installation manually"; return 1
        fi
    done <<< "$dependencies"
    brew install --dry-run "$formula" || { fail "Cannot plan Homebrew installation: $formula"; return 1; }
    confirm "Install missing Homebrew package $formula (no sudo)?" || { status skipped "$formula installation"; return 1; }
    brew install "$formula" || { fail "Homebrew installation failed: $formula"; return 1; }
    status installed "Homebrew: $formula"
}
ensure_tool() {
    local executable=$1 formula=$2 apt_package=$3
    if command -v "$executable" >/dev/null; then status 'already configured' "$executable installed"; return 0; fi
    if [[ $executable == fd ]] && command -v fdfind >/dev/null; then
        status 'already configured' 'fd available as Ubuntu fdfind'; return 0
    fi
    if [[ $formula != - ]] && command -v brew >/dev/null; then
        brew_install "$formula" || return 1
    elif [[ $apt_package != - ]]; then
        apt_install "$apt_package" || return 1
    else
        missing "$executable; install Homebrew separately or provide the executable on PATH"
        [[ $MODE != apply ]] || { fail "No supported installer available for $executable"; return 1; }
    fi
    if [[ $MODE == apply && $executable == fd ]] && command -v fdfind >/dev/null; then return 0; fi
    if [[ $MODE == apply ]] && ! command -v "$executable" >/dev/null; then
        fail "$executable remains unavailable on PATH"; return 1
    fi
}
# Clone a declared revision into an absent location. Never checkout/reset an
# existing installation. A failed download is removed only from our staging dir.
clone_missing() {
    local url=$1 revision=$2 destination=$3 marker=$4 stage
    if [[ -f $destination/$marker ]]; then status 'already configured' "$destination retained"; return 0; fi
    if [[ -e $destination || -L $destination ]]; then fail "Incomplete/conflicting installation: $destination; resolve manually"; return 1; fi
    [[ $MODE == apply ]] || { missing "Optional download: $url at $revision -> $destination"; return 0; }
    confirm "Download $url at $revision to $destination?" || { status skipped "$destination download"; return 1; }
    ensure_tool git git git || return 1
    # Reuse the symlink-parent guard before creating anything at this location.
    python3 - "$DOTFILES_ROOT/lib" "$destination" <<'PY' || { fail 'Unsafe download destination'; return 1; }
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from files import safe_parents
safe_parents(Path(sys.argv[2]).absolute())
PY
    mkdir -p -- "$(dirname -- "$destination")" || { fail 'Cannot create download parent'; return 1; }
    stage=$(mktemp -d "$(dirname -- "$destination")/.dotfiles-download.XXXXXXXX") || { fail 'Cannot create download staging directory'; return 1; }
    if git -c core.hooksPath=/dev/null clone --no-checkout -- "$url" "$stage" &&
        git -C "$stage" -c core.hooksPath=/dev/null checkout --detach "$revision" && [[ -f $stage/$marker ]]; then
        if [[ -e $destination || -L $destination ]]; then
            fail "Download destination appeared: $destination"
        elif mv -T -n -- "$stage" "$destination" && [[ ! -d $stage ]]; then
            status installed "$destination at $revision"; return 0
        else fail "Cannot publish download: $destination"; fi
    else fail "Download failed: $url at $revision"; fi
    rm -rf -- "$stage"
    return 1
}
optional_tools() {
    local executable formula apt_package
    if [[ $MODE == apply ]] && ! confirm 'Install missing supporting development tools for this module?'; then
        status skipped 'Supporting tools'; return 0
    fi
    while (( $# )); do
        executable=$1 formula=$2 apt_package=$3; shift 3
        ensure_tool "$executable" "$formula" "$apt_package" || true
    done
}
# npm globals are user-owned and pinned. Ignore registry auth/config during
# inspection; npm itself may use the user's chosen registry when installing.
npm_tool() {
    local executable=$1 package=$2 version=$3
    if command -v "$executable" >/dev/null; then status 'already configured' "$executable installed"; return 0; fi
    [[ $MODE == apply ]] || { missing "Optional npm package: $package@$version in ~/.local"; return 0; }
    command -v node >/dev/null && command -v npm >/dev/null || { fail 'Node/npm required; install a runtime explicitly with nvm first'; return 1; }
    [[ ! -e $HOME/.local/bin/$executable && ! -L $HOME/.local/bin/$executable ]] || {
        fail "Conflicting executable: $HOME/.local/bin/$executable; retain it and resolve manually"; return 1;
    }
    [[ ! -e $HOME/.local/lib/node_modules/$package && ! -L $HOME/.local/lib/node_modules/$package ]] || {
        fail "Existing npm package directory: $package; resolve PATH manually"; return 1;
    }
    python3 - "$DOTFILES_ROOT/lib" "$HOME/.local/lib/node_modules/$package" "$HOME/.local/bin/$executable" <<'PYGUARD' || { fail 'Unsafe npm prefix'; return 1; }
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from files import safe_parents
for value in sys.argv[2:]:
    safe_parents(Path(value))
PYGUARD
    confirm "Download/install $package@$version into ~/.local (no sudo, browser download disabled)?" || {
        status skipped "$package installation"; return 1;
    }
    PUPPETEER_SKIP_DOWNLOAD=true npm install --global --prefix "$HOME/.local" --no-audit --no-fund "$package@$version" || {
        fail "npm installation failed: $package"; return 1;
    }
    status installed "$package@$version; ensure ~/.local/bin is on PATH"
}
