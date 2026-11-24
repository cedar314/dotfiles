ensure_tool codex codex - || true
codex_home=${CODEX_HOME:-$HOME/.codex}
if [[ -e $codex_home/config.toml || -L $codex_home/config.toml ]]; then
    status 'already configured' 'Existing Codex configuration retained without reading or replacing it'
elif [[ $MODE == apply ]]; then
    if confirm 'Create a local editable Codex config from the sanitized template?'; then
        (umask 077; python3 "$DOTFILES_ROOT/lib/seed.py" "$DOTFILES_ROOT/codex/config.toml.example" "$codex_home/config.toml") || fail 'Cannot create local Codex config'
        status configured 'Local Codex template created'
    else status skipped 'Codex template'; fi
else missing 'Optional local Codex template'; fi
# Empty until individual user skills have been reviewed and explicitly added.
for skill in "$DOTFILES_ROOT/codex/skills/"*/SKILL.md; do
    [[ -f $skill ]] || continue
    directory=$(dirname -- "$skill")
    link_config "$directory" "$HOME/.agents/skills/$(basename -- "$directory")"
done
status skipped 'Authentication, trust, bundled skills, plugins and AGENTS.md files remain unmanaged'
