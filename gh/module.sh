ensure_tool gh gh gh || true
# gh's config directory also contains hosts.yml authentication; never link it.
status 'already configured' 'GitHub CLI uses built-in defaults; all existing configuration/authentication retained'
status skipped 'Authenticate manually with gh auth login; dotfiles never reads or creates hosts.yml'
