# --no-use keeps the current (e.g. Homebrew) Node executable selected.
export NVM_DIR="${NVM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nvm}"
if [ -s "$NVM_DIR/nvm.sh" ] && ! command -v nvm >/dev/null 2>&1; then
  . "$NVM_DIR/nvm.sh" --no-use
fi
