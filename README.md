# Linux dotfiles

Portable configuration and independent setup modules for Ubuntu Linux, including
WSL2. This repository was built from an existing mixed APT/Linuxbrew setup.
macOS and Windows deployment are outside scope; a Mac can SSH into the configured
Linux host. No Windows-profile files are managed.

## Layout

| Path | Purpose |
| --- | --- |
| `setup.sh` | Interactive module selection, explicit module invocation, rollback |
| `lib/` | Platform/package checks, conflict handling, private backup journals |
| `git/` | Default branch and private local identity/include template |
| `docker/` | Native Docker Engine/Compose installation and service checks |
| `wezterm/` | Portable appearance/key configuration and local overrides |
| `tmux/` | Ctrl-a/vi navigation, modified keys, TPM and navigator pins |
| `nvim/` | Reviewed LazyVim configuration, plugin lock seed, language extras |
| `codex/` | Sanitized settings template and individually curated user skills |
| `zsh/` | XDG shell configuration and optional Oh My Zsh bootstrap |
| `nvm/` | Pinned nvm checkout and optional shell integration |
| `pnpm/` | Existing installation detection and user-level shell paths |
| `gh/` | GitHub CLI installation checks, with authentication unmanaged |
| `md-to-pdf/` | PDF helper, pinned package version and optional stylesheet |
| `tests/` | Temporary-home integration tests and isolated runtime checks |

Each technology has an executable `setup.sh`, shareable configuration or explicit
built-in defaults, and any needed version declarations. Existing plugin/framework
checkouts, package-manager directories and browser binaries are not vendored.

## Prerequisites

- Ubuntu, Bash 4+, Python 3, and normal core utilities. Ubuntu 26.04 WSL2 is the
  inspected platform; other Ubuntu releases require compatible package versions.
- An unprivileged user with a writable home. Run setup as that user, **not with
  `sudo`**. Individual system operations explain and request sudo when needed.
- APT for system packages. Existing Homebrew is preferred for development tools,
  but is never installed by setup. Where declared, APT is the fallback.
- Git/network access for approved plugin downloads. Existing tools are retained
  regardless of source. A missing tool with no supported installer fails clearly.
- A functional systemd runtime for optional Docker service activation. WSL may
  need systemd configured separately; setup never edits `/etc/wsl.conf`.

WezTerm needs a graphical Linux host, an available `wezterm` APT package (provision
its [official Linux repository](https://wezterm.org/install/linux.html) separately
if needed), and JetBrains Mono for the preserved font preference. No third-party
APT sources are added automatically. Headless SSH hosts generally do not need
this module. Agnoster also benefits from a font with Powerline glyphs.

## Setup

Keep this checkout at a stable path; managed files link back to it.

```sh
./setup.sh --dry-run --all      # inspect plans/conflicts; no writes or downloads
./setup.sh                     # select numbered modules, or enter all
./setup.sh git tmux zsh        # select modules explicitly
./nvm/setup.sh                 # every module is independently runnable
./setup.sh --check git gh      # read-only checks; exit nonzero if incomplete
```

`--dry-run` and `--check` never invoke installers or download plugins. Check mode
reports missing tools/configuration and conflicts with a nonzero exit status.
Optional downloads that you deliberately decline are reported as skipped; they
are not automatically treated as failures. A failed attempted operation exits
nonzero. Other selected modules continue so that failures can be reviewed together.
Read-only checks may invoke installed tools to inspect versions/capabilities.

Selecting a module does not silently authorize every installation: missing
packages are planned before confirmation. Supporting development tools and
plugin/bootstrap downloads are separate opt-in steps. There is no blanket `--yes`
flag. EOF and empty answers default to declining installation or skipping conflicts.
Avoid piping a stream of `yes` into setup.

APT transactions are simulated and rejected if they replace/remove existing
packages. The real transaction also uses `--no-upgrade --no-remove`; it does not
run `apt upgrade` or add repositories. Refresh stale indexes manually if required.
Homebrew auto-update, install upgrades, dependent upgrades and cleanup are
disabled. Outdated installed dependencies cause a conservative failure before
installation. Other applications/package managers running concurrently can still
change system state: do not run concurrent package transactions during setup.

### Links, conflicts and local state

Default locations follow `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_STATE_HOME`
(or `~/.config`, `~/.local/share`, `~/.local/state`). Paths must be absolute.

- A correct existing link is a no-op; no new backup/journal is created.
- An existing file, directory, valid link or dangling link prompts **backup and
  link [b]** or **skip [default]**. Nothing is silently replaced.
- Symlinked parent directories are rejected for manual resolution, preventing
  writes through a configuration tree into an unrelated directory or checkout.
- Backups and manifests live in `$XDG_STATE_HOME/dotfiles/link-*`, outside Git,
  with private directory/file permissions. Do not publish them: originals can
  contain private configuration. Cross-filesystem moves fail without replacing
  the original; resolve those conflicts manually.
- Links are journaled; local editable seeds and downloaded packages/plugins are
  reported separately and are not removed by link rollback.

No entire `~/.codex`, `~/.docker`, `~/.config/gh`, or home directory is linked.
Neovim files are linked individually. `lazyvim.json` and the runtime plugin lock
are **local copies** because LazyVim/lazy.nvim modify them. Existing copies remain
untouched. The reviewed lock seed stays under `nvim/config/lazy-lock.json`.

### Git and identity

The module links `$XDG_CONFIG_HOME/git/config`, which includes `local.conf` beside
it. Copy `git/local.conf.example` there and edit it privately to supply identity.
An existing `~/.gitconfig` remains intact and may override shared defaults; review
or migrate its settings manually. Credential helpers, signing keys and personal
identity are never copied into this repository.

### Shell and development tools

Zsh uses `~/.zshenv` to set `ZDOTDIR` and links `.zshrc` under the XDG config tree.
It initializes Homebrew once, disables Oh My Zsh updates, and loads selected module
fragments under `$XDG_CONFIG_HOME/dotfiles/shell/`. Private host-specific shell
settings belong in `$ZDOTDIR/local.zsh`. Bash and the default login shell are not
changed. Launch `zsh` explicitly or use `chsh` yourself.

nvm defaults to `$XDG_DATA_HOME/nvm`, respects an explicit absolute `NVM_DIR`, and
can reuse `~/.nvm`. Its shell fragment uses `--no-use`, leaving an existing
Homebrew/system Node selected. **nvm installation does not install Node.** For a
chosen exact project runtime, run the following yourself:

```sh
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/shell/nvm.sh"
nvm install <exact-version>
nvm use <exact-version>
# Set a default explicitly only if desired:
nvm alias default <exact-version>
```

Keep project `.nvmrc` and `packageManager` declarations with their projects. If you
use Bash instead of the managed Zsh, manually source the desired module fragments
from your own shell config. No automatic `.nvmrc` switching hook is installed.

pnpm retains an existing installation. Otherwise it uses Homebrew, or a declared
npm version under `~/.local` when Node/npm already exist. `PNPM_HOME` and
`~/.local/bin` are added without duplicate entries by its shell fragment.
Registry configuration and auth files remain unmanaged. GitHub CLI setup never
reads/writes `hosts.yml` or logs in; use `gh auth login` yourself when needed.

### Neovim and tmux

Neovim requires 0.11.2+; setup reports older installed versions without upgrading.
The active customizations and language extras are retained, including Bamboo,
formatters, navigation and Markdown tooling. The inspected missing Markdown lint
config reference was removed; project/default rules can apply normally.

Optional bootstrap clones the declared lazy.nvim revision, seeds a local lock,
and offers `:Lazy install` for missing plugins. Existing plugins are not reset or
updated. Setup never runs `:Lazy sync`, `:Lazy update`, or `:Lazy restore`, which
can change existing plugins. Plugin build hooks may download their own tools when
you approve installation. Mason and Treesitter automatic installation and update
checks are disabled; install chosen servers/formatters via `:Mason` and parsers via
`:TSInstall` explicitly. Runtime locks are under `$XDG_STATE_HOME/nvim/` and can be
reviewed before promoting deliberate changes into the repository seed.
`NVIM_APPNAME` must be unset or `nvim` for setup.

Clipboard support depends on the host/session (Wayland, WSL's win32yank, X11,
or OSC52 for SSH). Detection reports available providers but installs none.
The tmux module links a `~/.tmux.conf` loader so tmux can find custom XDG paths.
tmux 3.5+ is required for the preserved modified-key settings.
TPM and navigator are optional declared-revision downloads under the XDG data
tree. Existing installations there are retained. Legacy `~/.tmux/plugins` remains
untouched; the new config uses the XDG plugin location. Running tmux servers are
never reloaded or restarted automatically.

### Docker

The module installs **native Linux Engine and Compose**, without Docker Desktop.
On a fresh supported Ubuntu host it uses `docker.io` and `docker-compose-v2`, as
on the inspected machine. An existing upstream Docker CE installation keeps its
package family; unrecognized installations require manual resolution. Setup does
not remove packages to switch families, provision an upstream repository, edit
`daemon.json`, or change Docker contexts, groups or firewall rules.

APT package hooks can start services during installation; this is disclosed before
confirmation. If systemd is running, an inactive local service can be started with
a separate prompt. Setup never restarts/enables services automatically. An explicit
`DOCKER_HOST`/`DOCKER_CONTEXT` prevents its optional local activation step. Package
installation itself can have system-level effects; inspect the presented plan.

User group membership is unchanged. Use sudo where appropriate or plan Docker
socket access separately. The module does not run test containers, pull images,
remove data, or write Docker CLI config, which can contain registry credentials.
Keep Compose definitions in the repositories of the services they run.

### Codex and PDF

Codex retains an existing user config without reading it. On a new installation,
it offers a **local editable copy** of `codex/config.toml.example`; authentication,
project trust and generated UI settings remain unmanaged. Individual reviewed
skills under `codex/skills/NAME/` are linked to `~/.agents/skills/NAME`. No custom
skills were found in the directly inspected directory, so none were invented or
copied from bundled/plugin caches. No `AGENTS.md` files are managed or modified.

The PDF module preserves `mdpdf` and the stylesheet. As in the inspected helper,
the stylesheet is not forced; pass `--stylesheet` to `md-to-pdf` when wanted.
Missing npm packages install to `~/.local` at declared versions, without sudo or
implicit browser downloads. Provide a compatible Chromium/Chrome separately and
configure Puppeteer for that executable if necessary. No browser sandbox flags
are changed. Existing Markdown-to-PDF installations remain intact.

## Updates and recovery

Review repository changes before updating a checkout: edits to linked files take
effect immediately. Re-run setup to discover newly missing configuration; it will
not perform software upgrades. Update packages/plugins deliberately outside setup.
Change revision declarations and the reviewed plugin lock only as an intentional,
tested maintenance change. Existing checkouts are never reset to a changed pin.
Local overrides belong outside this checkout, not in tracked files.

```sh
./setup.sh --dry-run --rollback  # list link journals without changing anything
./setup.sh --rollback            # prompts for each still-managed link, newest first
```

Rollback removes only a link whose target still matches the recorded source, then
restores its original file/directory/link when present. Changed or missing targets
are retained and reported for manual resolution. Correct links that predated
setup have no journal and are not removed. Empty parent directories may remain.
Rollback does not uninstall software/plugins, undo service activation, delete local
identity/authentication, or remove editable seeds. A link removal does not delete
its repository source, so edits made through that link remain in the checkout.

If setup was interrupted during a link operation, inspect its `manifest.json`
(`prepared`, `failed`, `linked`, or `restored`) and sibling `original` privately.
Do not delete the backup directory until recovery is verified. Link creation
failures normally restore the original immediately. Never blindly restore a
backup over subsequent work. Keep a separate backup of important local files.

The directory was not initialized as a Git repository, committed or pushed.
Before initializing/publishing it yourself, review the complete file list and
`.gitignore`; ignore patterns are a guardrail, not a substitute for reviewing what
is staged. Never stage home directories, credentials, local backups or agent state.

## Verification

```sh
python3 -m unittest discover -s tests -v
```

Tests use temporary homes with paths containing spaces and mock all installation,
Git download, npm and service commands. They cover idempotency, conflicts, backup
and rollback, failed linking/downloads, preservation of sensitive-file fixtures,
unsupported OS behavior and rejection of package replacements. Runtime checks use
real Neovim to compile Lua without loading plugins and attempt an isolated tmux
server with dummy plugins. A sandbox that blocks Unix sockets skips the tmux
runtime check with an explicit reason. No real-home deployment is exercised.

Bash/Zsh syntax checks are also run during development. ShellCheck/shfmt were not
available in the inspected environment. Network bootstrap, real package installs,
Docker service control, browser/PDF rendering and WezTerm GUI behavior require
separate host verification; mocked tests do not establish those behaviors.
