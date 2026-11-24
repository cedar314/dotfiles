# Homebrew is optional. Set up the environment once, before loading dev tools.
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
export ZSH="${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git)
# Updates are a deliberate maintenance action, never a side effect of a shell.
zstyle ':omz:update' mode disabled
if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  print -u2 'Oh My Zsh is not installed; run the zsh module and approve bootstrap.'
fi
# Each development module owns its own optional shell integration.
for dotfiles_fragment in "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/shell/"*.sh(N); do
  source "$dotfiles_fragment"
done
unset dotfiles_fragment
[[ ! -f "$ZDOTDIR/local.zsh" ]] || source "$ZDOTDIR/local.zsh"
