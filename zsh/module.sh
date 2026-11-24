ensure_tool zsh - zsh || true
link_config "$DOTFILES_ROOT/zsh/.zshenv" "$HOME/.zshenv"
link_config "$DOTFILES_ROOT/zsh/.zshrc" "$CONFIG_HOME/zsh/.zshrc"
source "$DOTFILES_ROOT/zsh/versions.sh"
# Reuse the current installation without tracking or moving it.
if [[ -f $CONFIG_HOME/zsh/oh-my-zsh/oh-my-zsh.sh ]]; then
    link_config "$CONFIG_HOME/zsh/oh-my-zsh" "$DATA_HOME/oh-my-zsh"
else
    clone_missing https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_REVISION" "$DATA_HOME/oh-my-zsh" oh-my-zsh.sh || true
fi
status skipped 'Login shell and Bash configuration retained; launch zsh explicitly or run chsh manually'
