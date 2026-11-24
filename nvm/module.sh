nvm_home=${NVM_DIR:-$DATA_HOME/nvm}
# Respect an existing conventional install when NVM_DIR is not explicitly set.
if [[ -z ${NVM_DIR:-} && -s $HOME/.nvm/nvm.sh ]]; then
    link_config "$HOME/.nvm" "$DATA_HOME/nvm"
else
    source "$DOTFILES_ROOT/nvm/versions.sh"
    clone_missing https://github.com/nvm-sh/nvm.git "$NVM_REVISION" "$nvm_home" nvm.sh || true
fi
link_config "$DOTFILES_ROOT/nvm/init.sh" "$CONFIG_HOME/dotfiles/shell/nvm.sh"
status skipped 'Node runtimes and default selection retained. Source nvm/init.sh, then explicitly run nvm install <version> and nvm use <version>.'
