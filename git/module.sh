ensure_tool git git git || true
link_config "$DOTFILES_ROOT/git/config" "$CONFIG_HOME/git/config"
# ~/.gitconfig overrides XDG Git config. Never replace it with a minimal template.
if [[ -e $HOME/.gitconfig || -L $HOME/.gitconfig ]]; then
    status skipped '~/.gitconfig retained; it may override managed defaults. Review identity/helpers locally.'
fi
if [[ ! -f $CONFIG_HOME/git/local.conf ]]; then
    status skipped "Local identity not created; see $DOTFILES_ROOT/git/local.conf.example"
fi
