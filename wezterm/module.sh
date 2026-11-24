# Homebrew's WezTerm cask targets macOS. Linux uses a preconfigured APT source.
ensure_tool wezterm - wezterm || true
link_config "$DOTFILES_ROOT/wezterm/wezterm.lua" "$CONFIG_HOME/wezterm/wezterm.lua"
if [[ -e $HOME/.wezterm.lua || -L $HOME/.wezterm.lua ]]; then
    status skipped '~/.wezterm.lua retained; review it if it takes precedence over the XDG config'
fi
status skipped 'JetBrains Mono is a host GUI prerequisite; no font or Windows configuration installed'
if ! command -v wezterm >/dev/null; then
    status skipped 'If APT has no wezterm candidate, provision its official Linux repository manually, then rerun this module'
fi
