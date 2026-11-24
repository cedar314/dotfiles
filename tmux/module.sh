ensure_tool tmux - tmux || true
if command -v tmux >/dev/null; then
    version=$(tmux -V)
    if [[ $version =~ ([0-9]+)\.([0-9]+) ]] &&
        (( BASH_REMATCH[1] > 3 || (BASH_REMATCH[1] == 3 && BASH_REMATCH[2] >= 5) )); then
        :
    else
        fail 'tmux 3.5+ required for extended-keys-format; existing installation retained'
        return 1
    fi
fi
link_config "$DOTFILES_ROOT/tmux/tmux.conf" "$CONFIG_HOME/tmux/tmux.conf"
link_config "$DOTFILES_ROOT/tmux/loader.conf" "$HOME/.tmux.conf"
# Existing legacy TPM/plugin installations are retained; new config uses XDG data.
plugin_home=$DATA_HOME/tmux/plugins
if [[ -f $HOME/.tmux/plugins/tpm/tpm ]]; then
    status 'already configured' 'Existing legacy TPM retained; plugins can be copied manually or bootstrap XDG plugins separately'
fi
source "$DOTFILES_ROOT/tmux/versions.sh"
clone_missing https://github.com/tmux-plugins/tpm.git "$TPM_REVISION" "$plugin_home/tpm" tpm || true
clone_missing https://github.com/christoomey/vim-tmux-navigator.git "$NAVIGATOR_REVISION" "$plugin_home/vim-tmux-navigator" vim-tmux-navigator.tmux || true
status skipped 'Running tmux servers are not reloaded automatically'
