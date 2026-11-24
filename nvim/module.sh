if [[ ${NVIM_APPNAME:-nvim} != nvim ]]; then
    fail 'Unset NVIM_APPNAME before running the nvim module (this module manages nvim paths)'
    return 1
fi
ensure_tool nvim neovim neovim || true
if command -v nvim >/dev/null && ! nvim --clean --headless -i NONE -u NONE '+lua if vim.fn.has("nvim-0.11.2") == 0 then vim.cmd("cquit") end' +qa >/dev/null 2>&1; then
    fail 'Neovim 0.11.2+ required; existing installation will not be upgraded'
    return 1
fi
# Link files individually: LazyVim can write local/generated files without
# writing through a whole-directory link into the repository.
while IFS= read -r -d '' source; do
    relative=${source#"$DOTFILES_ROOT/nvim/config/"}
    case $relative in LICENSE|lazy-lock.json|lazyvim.json) continue ;; esac
    link_config "$source" "$CONFIG_HOME/nvim/$relative"
done < <(find "$DOTFILES_ROOT/nvim/config" -type f -print0)
# Runtime-generated files must be editable local copies, never symlinks.
for seed in lazyvim.json lazy-lock.json; do
    destination=$CONFIG_HOME/nvim/$seed
    [[ $seed != lazy-lock.json ]] || destination=$STATE_HOME/nvim/$seed
    if [[ -L $destination ]]; then
        fail "Mutable Neovim state is symlinked: $destination; resolve manually"
    elif [[ -e $destination ]]; then
        status 'already configured' "Local $seed retained"
    elif [[ $MODE == apply ]]; then
        if confirm "Seed local $seed from the reviewed repository template?"; then
            python3 "$DOTFILES_ROOT/lib/seed.py" "$DOTFILES_ROOT/nvim/config/$seed" "$destination" || fail "Cannot seed $seed"
        else status skipped "$seed seed"; fi
    else missing "Local Neovim $seed seed"; fi
done
revision=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["lazy.nvim"]["commit"])' "$DOTFILES_ROOT/nvim/config/lazy-lock.json")
clone_missing https://github.com/folke/lazy.nvim.git "$revision" "$DATA_HOME/nvim/lazy/lazy.nvim" lua/lazy/init.lua || true
managed=1
while IFS= read -r -d '' source; do
    relative=${source#"$DOTFILES_ROOT/nvim/config/"}
    case $relative in LICENSE|lazy-lock.json|lazyvim.json) continue ;; esac
    [[ -L $CONFIG_HOME/nvim/$relative && $(readlink -f -- "$CONFIG_HOME/nvim/$relative") == "$source" ]] || managed=0
done < <(find "$DOTFILES_ROOT/nvim/config" -type f -print0)
if [[ $MODE == apply && $managed == 1 && -f $DATA_HOME/nvim/lazy/lazy.nvim/lua/lazy/init.lua && -f $STATE_HOME/nvim/lazy-lock.json ]]; then
    if confirm 'Install missing locked Neovim plugins? Existing plugins retained; build hooks may download tools.'; then
        nvim --headless -i NONE '+Lazy! install' +qa || fail 'Neovim plugin installation failed'
    else status skipped 'Neovim plugin bootstrap'; fi
elif [[ $MODE == apply ]]; then
    status skipped 'Automatic plugin bootstrap requires all managed config links, lazy.nvim, and a seeded lock. Manual alternative: open nvim and run :Lazy install (missing plugins only; never :Lazy sync during setup)'
else status skipped 'Optional LazyVim plugin bootstrap is separate from configuration checks'; fi
optional_tools git git git rg ripgrep ripgrep fd fd fd-find cc gcc build-essential node node nodejs python3 python python3
status skipped 'Language servers/formatters: install chosen tools explicitly with :Mason. No language runtimes upgraded.'
if command -v win32yank.exe >/dev/null || command -v wl-copy >/dev/null || command -v xclip >/dev/null; then
    status 'already configured' 'Clipboard provider found'
else status skipped 'No clipboard provider found; configure OSC52 for SSH or install a local desktop provider'; fi
