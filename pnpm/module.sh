if command -v pnpm >/dev/null; then
    status 'already configured' 'Existing pnpm retained'
elif command -v brew >/dev/null; then
    brew_install pnpm || true
else
    source "$DOTFILES_ROOT/pnpm/versions.sh"
    npm_tool pnpm pnpm "$PNPM_VERSION" || true
fi
link_config "$DOTFILES_ROOT/pnpm/init.sh" "$CONFIG_HOME/dotfiles/shell/pnpm.sh"
status skipped 'pnpm registry/auth files and project packageManager declarations remain unmanaged'
