#!/usr/bin/env python3
"""Integration checks use temporary homes and command doubles, never real installs."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash')
PYTHON = shutil.which('python3')
spec = importlib.util.spec_from_file_location('files', ROOT / 'lib/files.py')
files = importlib.util.module_from_spec(spec)
spec.loader.exec_module(files)


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='dotfiles-tests-')
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.home = self.base / 'home with spaces'
        self.home.mkdir()
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.log = self.base / 'commands'
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / 'config'),
                        XDG_DATA_HOME=str(self.home / 'data'), XDG_STATE_HOME=str(self.home / 'state'),
                        XDG_CACHE_HOME=str(self.home / 'cache'), PATH=f'{self.bin}:/usr/bin:/bin',
                        TEST_LOG=str(self.log), TEST_CASE='normal')
        for key in ['DOTFILES_ENV_READY', 'ZDOTDIR', 'CODEX_HOME', 'NVM_DIR', 'NVIM_APPNAME', 'DOCKER_HOST', 'DOCKER_CONTEXT',
                    'DOCKER_CONFIG', 'GH_CONFIG_DIR', 'NPM_CONFIG_PREFIX']:
            self.env.pop(key, None)
        for name in ['git', 'docker', 'dockerd', 'tmux', 'nvim', 'codex', 'node', 'npm', 'pnpm',
                     'gh', 'wezterm', 'brew', 'apt-get', 'dpkg-query', 'systemctl', 'sudo',
                     'rg', 'fd', 'cc', 'wl-copy', 'md-to-pdf', 'zsh']:
            self.mock(name)

    def mock(self, name):
        path = self.bin / name
        path.write_text('''#!/bin/bash
printf '%s %s\\n' "${0##*/}" "$*" >> "$TEST_LOG"
case "${0##*/}" in
  uname) printf '%s\\n' Darwin ;;
  dpkg-query)
    [[ $TEST_CASE != docker-missing ]] && printf 'install ok installed' || exit 1 ;;
  docker) [[ $TEST_CASE != docker-missing ]] ;;
  brew)
    case "$1" in
      list) exit 0 ;;
      deps) printf '%s\\n' libexample ;;
      outdated) [[ $TEST_CASE != brew-upgrade ]] || printf '%s\\n' libexample ;;
    esac ;;
  apt-get)
    if [[ $* == *--simulate* ]]; then
      case $TEST_CASE in
        apt-upgrade) printf '%s\\n' 'Inst dependency [1.0] (2.0 Ubuntu)' ;;
        apt-remove) printf '%s\\n' 'Remv existing [1.0]' ;;
        apt-failure) exit 1 ;;
        *) printf '%s\\n' 'Inst newpackage (1.0 Ubuntu)' ;;
      esac
    elif [[ $TEST_CASE == install-zsh && $* == *' install -- zsh' ]]; then
      printf '#!/bin/bash\\nexit 0\\n' > "${0%/*}/zsh"
      chmod +x "${0%/*}/zsh"
    fi ;;
  sudo) [[ $1 != -- ]] || shift; "$@" ;;
  tmux) [[ $1 != -V ]] || printf 'tmux 3.6\\n' ;;
  nvim) [[ $TEST_CASE != old-nvim ]] ;;
  git)
    if [[ $* == *clone* ]]; then
      [[ $TEST_CASE != clone-failure ]] || exit 1
      destination=${!#}
      mkdir -p "$destination"
      touch "$destination/nvm.sh"
    fi ;;
esac
''')
        path.chmod(0o755)

    def run_setup(self, *arguments, answers='', expected=0):
        result = subprocess.run([BASH, str(ROOT / 'setup.sh'), *arguments], env=self.env,
                                input=answers, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def common(self, command, answers='', expected=0):
        script = f'source "{ROOT}/lib/common.sh"; initialize || exit 1; {command}; finish'
        result = subprocess.run([BASH, '-c', script], env=self.env,
                                input=answers, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def file_command(self, operation='link', answers='', source=None, destination=None, mode='apply', expected=0):
        args = [PYTHON, str(ROOT / 'lib/files.py'), operation,
                '--repo', str(ROOT), '--state', str(self.home / 'state/dotfiles'), '--mode', mode]
        if operation == 'link':
            args += ['--source', str(source or ROOT / 'git/config'),
                     '--destination', str(destination or self.home / 'config/test/config')]
        result = subprocess.run(args, env=self.env, input=answers, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def journal(self):
        return list((self.home / 'state/dotfiles').glob('link-*/manifest.json'))

    def snapshot(self):
        return {str(p.relative_to(self.home)): ('link', os.readlink(p)) if p.is_symlink()
                else ('file', p.read_bytes()) if p.is_file() else ('dir', None)
                for p in self.home.rglob('*')}

    def test_read_only_modes_all_modules(self):
        before = self.snapshot()
        self.run_setup('--dry-run', '--all')
        self.assertEqual(before, self.snapshot())
        self.run_setup('--check', '--all', expected=1)
        self.assertEqual(before, self.snapshot())
        commands = self.log.read_text()
        self.assertNotIn('apt-get --no-upgrade', commands)
        self.assertNotIn('brew install', commands)
        self.assertNotIn('git clone', commands)
        self.assertNotIn('npm install', commands)

    def test_unset_xdg_prompts_once_and_reuses_saved_choice(self):
        self.env.pop('XDG_CONFIG_HOME')
        chosen = self.home / 'chosen config'
        result = self.run_setup('codex', 'gh', answers=str(chosen) + '\n')
        self.assertEqual(result.stderr.count('(Enter for default)'), 1)
        self.assertTrue((self.home / '.codex/config.toml').is_file())
        self.assertFalse((self.home / '.config').exists())
        self.assertTrue((self.home / '.zshenv').is_file())
        self.assertFalse((self.home / '.zshenv').is_symlink())
        before = self.snapshot()
        result = self.run_setup('codex', 'gh')
        self.assertNotIn('(Enter for default)', result.stderr)
        self.assertEqual(before, self.snapshot())

    def test_unset_xdg_enter_uses_standard_default(self):
        self.env.pop('XDG_CONFIG_HOME')
        self.run_setup('codex', answers='\n')
        self.assertTrue((self.home / '.codex/config.toml').is_file())

    def test_unset_xdg_eof_aborts_without_changes(self):
        self.env.pop('XDG_CONFIG_HOME')
        self.run_setup('codex', expected=1)
        self.assertEqual(self.snapshot(), {})

    def test_read_only_unset_xdg_does_not_prompt_or_write(self):
        self.env.pop('XDG_CONFIG_HOME')
        for mode, expected in [('--dry-run', 0), ('--check', 1)]:
            result = self.run_setup(mode, 'codex', expected=expected)
            self.assertNotIn('(Enter for default)', result.stderr)
            self.assertEqual(self.snapshot(), {})

    def test_standalone_codex_uses_shared_bootstrap(self):
        self.env.pop('XDG_CONFIG_HOME')
        result = subprocess.run([BASH, str(ROOT / 'codex/setup.sh')], env=self.env,
                                input='\n', text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / '.codex/config.toml').is_file())
        self.assertTrue((self.home / '.zshenv').is_file())

    def test_existing_zshenv_skip_stops_modules(self):
        path = self.home / '.zshenv'
        path.write_text('export ORIGINAL=kept\n')
        before = self.snapshot()
        self.run_setup('codex', expected=1)
        self.assertEqual(before, self.snapshot())

    @unittest.skipUnless(shutil.which('zsh'), 'zsh unavailable')
    def test_zshenv_backup_preserves_previous_behavior_and_persists_choice(self):
        path = self.home / '.zshenv'
        original = 'export ORIGINAL=kept\n'
        path.write_text(original)
        self.run_setup('gh', answers='b\n')
        manifest = next(p for p in self.journal() if json.loads(p.read_text())['destination'] == str(path))
        backup = Path(json.loads(manifest.read_text())['backup'])
        self.assertEqual(backup.read_text(), original)
        env = dict(self.env)
        env.pop('XDG_CONFIG_HOME')
        result = subprocess.run([shutil.which('zsh'), '-c', 'print -rl -- "$ORIGINAL" "$XDG_CONFIG_HOME" "$ZDOTDIR"'],
                                env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['kept', str(self.home / 'config'), str(self.home / 'config/zsh')])
        self.run_setup('--rollback', answers='y\n')
        self.assertEqual(path.read_text(), original)

    def test_repo_zshenv_link_is_backed_up_without_editing_repo(self):
        source = ROOT / 'zsh/.zshenv'
        before = source.read_bytes()
        path = self.home / '.zshenv'
        path.symlink_to(source)
        self.run_setup('gh', answers='b\n')
        self.assertFalse(path.is_symlink())
        self.assertEqual(source.read_bytes(), before)
        self.run_setup('--rollback', answers='y\n')
        self.assertEqual(os.readlink(path), str(source))

    def test_modified_generated_zshenv_is_not_removed_by_rollback(self):
        self.run_setup('gh')
        path = self.home / '.zshenv'
        with path.open('a') as stream:
            stream.write('# later user change\n')
        self.run_setup('--rollback', answers='y\n', expected=1)
        self.assertIn('# later user change', path.read_text())

    @unittest.skipUnless(shutil.which('zsh'), 'zsh unavailable')
    def test_path_with_shell_characters_is_saved_literally(self):
        chosen = str(self.home / "config '$HOME'")
        self.env['XDG_CONFIG_HOME'] = chosen
        self.run_setup('gh')
        env = dict(self.env)
        env.pop('XDG_CONFIG_HOME')
        result = subprocess.run([shutil.which('zsh'), '-c', 'print -r -- "$XDG_CONFIG_HOME"'],
                                env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.rstrip('\n'), chosen)

    def test_codex_skill_links_use_native_and_discovery_paths(self):
        self.run_setup('codex')
        for manifest in (ROOT / 'codex/skills').glob('*/SKILL.md'):
            canonical = self.home / '.codex/skills' / manifest.parent.name
            discovery = self.home / '.agents/skills' / manifest.parent.name
            self.assertEqual(os.readlink(canonical), str(manifest.parent))
            self.assertEqual(os.readlink(discovery), str(canonical))
        self.assertFalse((self.home / '.codex/skills/README').exists())
        before = self.snapshot()
        self.run_setup('--check', 'codex')
        self.run_setup('codex')
        self.assertEqual(before, self.snapshot())

    def test_missing_zsh_is_checked_for_non_zsh_modules(self):
        (self.bin / 'zsh').unlink()
        for name in ['bash', 'python3', 'uname', 'awk', 'dirname', 'grep', 'chmod']:
            (self.bin / name).symlink_to(shutil.which(name))
        self.env['PATH'] = str(self.bin)
        result = self.run_setup('--dry-run', 'gh')
        self.assertIn('APT would install: zsh', result.stdout)
        self.assertEqual(self.snapshot(), {})
        self.run_setup('gh', expected=1)
        self.assertEqual(self.snapshot(), {})
        self.env['TEST_CASE'] = 'install-zsh'
        result = self.run_setup('gh', answers='y\n')
        self.assertIn('APT: zsh', result.stdout)
        self.assertTrue((self.home / '.zshenv').exists())

    def test_invalid_prompted_xdg_path_has_no_side_effects(self):
        self.env.pop('XDG_CONFIG_HOME')
        self.run_setup('codex', answers='relative/path\n', expected=1)
        self.assertEqual(self.snapshot(), {})

    def test_skipped_codex_skill_conflict_does_not_create_discovery_link(self):
        manifest = sorted((ROOT / 'codex/skills').glob('*/SKILL.md'))[0]
        canonical = self.home / '.codex/skills' / manifest.parent.name
        canonical.parent.mkdir(parents=True)
        canonical.write_text('existing user work')
        self.run_setup('codex')
        self.assertEqual(canonical.read_text(), 'existing user work')
        self.assertFalse((self.home / '.agents/skills' / manifest.parent.name).exists())

    def test_codex_skill_conflict_can_be_backed_up(self):
        manifest = sorted((ROOT / 'codex/skills').glob('*/SKILL.md'))[0]
        canonical = self.home / '.codex/skills' / manifest.parent.name
        canonical.parent.mkdir(parents=True)
        canonical.symlink_to(self.home / 'missing-target')
        self.run_setup('codex', answers='b\n')
        self.assertEqual(os.readlink(canonical), str(manifest.parent))
        discovery = self.home / '.agents/skills' / manifest.parent.name
        self.assertEqual(os.readlink(discovery), str(canonical))

    def test_first_run_and_second_run(self):
        self.run_setup('git', 'gh', 'pnpm', 'md-to-pdf', 'wezterm')
        before = self.snapshot()
        self.run_setup('git', 'gh', 'pnpm', 'md-to-pdf', 'wezterm')
        self.assertEqual(before, self.snapshot())
        self.run_setup('--check', 'git', 'gh', 'pnpm', 'md-to-pdf', 'wezterm')

    def test_all_modules_repeat_with_optional_downloads_declined(self):
        self.run_setup('--all')
        before = self.snapshot()
        self.run_setup('--all')
        self.assertEqual(before, self.snapshot())

    def test_fresh_docker_installs_native_engine_and_compose(self):
        self.env['TEST_CASE'] = 'docker-missing'
        # A hermetic PATH hides real Docker tools while retaining required utilities.
        for name in ['docker', 'dockerd']:
            (self.bin / name).unlink()
        for name in ['bash', 'python3', 'uname', 'awk', 'dirname', 'grep']:
            (self.bin / name).symlink_to(shutil.which(name))
        self.env['PATH'] = str(self.bin)
        self.run_setup('docker', answers='y\n')
        self.assertIn('apt-get --no-upgrade --no-remove install -- docker.io docker-compose-v2', self.log.read_text())
        self.assertEqual((self.home / 'config/docker/config.json').read_text(), '{}\n')
        self.assertEqual((self.home / '.docker/config.json').resolve(), self.home / 'config/docker/config.json')

    def test_native_codex_and_private_docker_defaults(self):
        self.run_setup('codex', 'docker', 'zsh')
        self.assertFalse((self.home / '.codex').is_symlink())
        self.assertFalse((self.home / '.codex/skills').is_symlink())
        for name in ('config.toml', 'AGENTS.md'):
            self.assertEqual(os.readlink(self.home / '.codex' / name), str(ROOT / 'codex' / name))
        docker = self.home / 'config/docker/config.json'
        self.assertFalse(docker.is_symlink())
        self.assertEqual(docker.stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.home / '.docker/config.json').resolve(), docker)
        self.assertEqual(os.readlink(self.home / '.zshrc'), str(self.home / 'config/zsh/.zshrc'))
        before = self.snapshot()
        self.run_setup('codex', 'docker', 'zsh')
        self.assertEqual(before, self.snapshot())

    def test_existing_codex_configuration_can_be_skipped_without_reading(self):
        target = self.home / '.codex/config.toml'
        target.parent.mkdir()
        target.write_text('PRIVATE_TEST_FIXTURE')
        result = self.run_setup('codex')
        self.assertNotIn('PRIVATE_TEST_FIXTURE', result.stdout + result.stderr)
        self.assertEqual(target.read_text(), 'PRIVATE_TEST_FIXTURE')
        self.assertFalse(target.is_symlink())

    def test_existing_codex_configuration_backup_and_rollback(self):
        target = self.home / '.codex/config.toml'
        target.parent.mkdir()
        target.write_text('PRIVATE_TEST_FIXTURE')
        result = self.run_setup('codex', answers='b\n')
        self.assertNotIn('PRIVATE_TEST_FIXTURE', result.stdout + result.stderr)
        self.assertEqual(target.resolve(), ROOT / 'codex/config.toml')
        self.run_setup('--rollback', answers='y\n' * len(self.journal()))
        self.assertEqual(target.read_text(), 'PRIVATE_TEST_FIXTURE')

    def test_inherited_codex_override_is_not_persisted(self):
        self.env['CODEX_HOME'] = str(self.home / 'custom codex')
        self.env['DOCKER_CONFIG'] = str(self.home / 'custom docker')
        self.run_setup('codex', 'docker')
        self.assertFalse((self.home / 'custom codex').exists())
        self.assertTrue((self.home / '.codex/config.toml').is_symlink())
        self.assertFalse((self.home / 'config/dotfiles/environment/codex.sh').exists())
        self.assertEqual(os.readlink(self.home / 'custom docker/config.json'), str(self.home / 'config/docker/config.json'))

    def test_codex_setup_refuses_symlinked_home(self):
        source = self.home / 'config/codex'
        source.mkdir(parents=True)
        (self.home / '.codex').symlink_to(source)
        result = self.run_setup('codex', expected=1)
        self.assertIn('symlink parent requires manual resolution', result.stderr)
        self.assertEqual((self.home / '.codex').resolve(), source)
        self.assertFalse((source / 'config.toml').exists())

    def test_rollback_keeps_docker_private_config_and_removes_codex_links(self):
        self.run_setup('codex', 'docker')
        self.run_setup('--rollback', answers='y\n' * len(self.journal()))
        self.assertTrue((self.home / 'config/docker/config.json').is_file())
        self.assertFalse(os.path.lexists(self.home / '.codex/config.toml'))
        self.assertTrue((ROOT / 'codex/config.toml').is_file())

    def test_menu_and_duplicate_module(self):
        output = self.run_setup(answers='1 1 10\n').stdout
        self.assertEqual(output.count('Module: git\n'), 1)
        self.assertIn('Module: gh', output)

    def test_invalid_menu_has_no_changes(self):
        self.run_setup(answers='1 99\n', expected=2)
        self.assertEqual(self.snapshot(), {})

    def test_conflicts_default_skip_and_backup_restore(self):
        for kind in ['file', 'directory', 'link', 'dangling']:
            with self.subTest(kind=kind):
                target = self.home / f'conflict-{kind}'
                if kind == 'file': target.write_text('private local fixture')
                elif kind == 'directory': target.mkdir(); (target / 'work').write_text('work')
                else: target.symlink_to(ROOT / 'README.md' if kind == 'link' else self.home / 'absent')
                original = os.readlink(target) if target.is_symlink() else None
                self.file_command(destination=target)
                self.assertFalse(self.journal())
                self.file_command(destination=target, answers='b\n')
                self.assertTrue(target.is_symlink())
                manifest = self.journal()[0]
                backup = Path(json.loads(manifest.read_text())['backup'])
                self.assertTrue(os.path.lexists(backup))
                self.assertEqual((manifest.parent.stat().st_mode & 0o777), 0o700)
                self.file_command(operation='rollback', answers='y\n')
                if original is not None: self.assertEqual(os.readlink(target), original)
                elif kind == 'directory': self.assertEqual((target / 'work').read_text(), 'work')
                else: self.assertEqual(target.read_text(), 'private local fixture')
                shutil.rmtree(self.home / 'state')

    def test_correct_link_does_not_create_journal(self):
        target = self.home / 'test'
        target.symlink_to(ROOT / 'git/config')
        self.file_command(destination=target)
        self.assertFalse((self.home / 'state').exists())

    def test_rollback_retains_subsequent_changes(self):
        target = self.home / 'test'
        self.file_command(destination=target)
        target.unlink()
        target.write_text('new user work')
        self.file_command(operation='rollback', answers='y\n', expected=1)
        self.assertEqual(target.read_text(), 'new user work')

    def test_rollback_decline_and_idempotency(self):
        target = self.home / 'test'
        self.file_command(destination=target)
        self.file_command(operation='rollback')
        self.assertTrue(target.is_symlink())
        self.file_command(operation='rollback', answers='y\n')
        self.assertFalse(target.exists())
        self.file_command(operation='rollback', answers='y\n')

    def test_symlink_parent_is_rejected(self):
        real = self.home / 'real'
        real.mkdir()
        (self.home / 'alias').symlink_to(real)
        self.file_command(destination=self.home / 'alias/config', expected=1)
        self.assertEqual(list(real.iterdir()), [])

    def test_backups_cannot_be_inside_repository(self):
        result = subprocess.run([PYTHON, str(ROOT / 'lib/files.py'), 'link',
                                 '--source', str(ROOT / 'git/config'), '--destination', str(self.home / 'target'),
                                 '--repo', str(ROOT), '--state', str(ROOT / 'forbidden-backups'), '--mode', 'apply'],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertFalse((ROOT / 'forbidden-backups').exists())

    def test_failed_link_restores_backup(self):
        target = self.home / 'target'
        target.write_text('original')
        args = type('Args', (), dict(source=str(ROOT / 'git/config'), destination=str(target), mode='apply',
                                    state=str(self.home / 'state/dotfiles'), repo=str(ROOT), preserve_existing=False))()
        with patch('sys.stdin', __import__('io').StringIO('b\n')), patch.object(Path, 'symlink_to', side_effect=OSError('injected failure')):
            with self.assertRaises(OSError): files.link(args)
        self.assertEqual(target.read_text(), 'original')

    def test_sensitive_configuration_untouched(self):
        fixtures = ['.docker/config.json', '.docker/.token_seed', '.codex/config.toml', '.codex/auth.json',
                    'config/gh/hosts.yml', 'config/pnpm/auth.ini', '.gitconfig']
        for name in fixtures:
            path = self.home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('PRIVATE_TEST_FIXTURE\n')
        before = {name: (self.home / name).read_bytes() for name in fixtures}
        result = self.run_setup('docker', 'codex', 'gh', 'pnpm', 'git')
        self.assertNotIn('PRIVATE_TEST_FIXTURE', result.stdout + result.stderr)
        for name in fixtures: self.assertEqual((self.home / name).read_bytes(), before[name])

    def test_apt_plan_rejects_replacements(self):
        for case in ['apt-upgrade', 'apt-remove', 'apt-failure']:
            self.env['TEST_CASE'] = case
            self.common('apt_install example || true', answers='y\n', expected=1)
        self.assertNotIn('apt-get --no-upgrade', self.log.read_text())

    def test_apt_declined_and_approved(self):
        self.common('apt_install example || true')
        self.assertNotIn('apt-get --no-upgrade', self.log.read_text())
        self.common('apt_install example || true', answers='y\n')
        self.assertIn('apt-get --no-upgrade --no-remove install -- example', self.log.read_text())

    def test_brew_outdated_dependency_is_rejected(self):
        self.env['TEST_CASE'] = 'brew-upgrade'
        self.common('brew_install example || true', answers='y\n', expected=1)
        self.assertNotIn('brew install', self.log.read_text())

    def test_brew_no_upgrade_environment_and_approval(self):
        self.common('[[ $HOMEBREW_NO_AUTO_UPDATE == 1 && $HOMEBREW_NO_INSTALL_UPGRADE == 1 ]] || fail environment; brew_install example || true', answers='y\n')
        self.assertIn('brew install --dry-run example', self.log.read_text())
        self.assertIn('brew install example', self.log.read_text())

    def test_old_neovim_does_not_link_configuration(self):
        self.env['TEST_CASE'] = 'old-nvim'
        self.run_setup('nvim', expected=1)
        self.assertFalse((self.home / 'config/nvim').exists())

    def test_unsupported_platform(self):
        self.mock('uname')
        self.run_setup('git', expected=1)
        self.assertEqual(self.snapshot(), {})

    def test_nvm_clone_is_idempotent_and_no_node_selection(self):
        self.run_setup('nvm', answers='y\n')
        before = self.snapshot()
        self.run_setup('nvm')
        self.assertEqual(before, self.snapshot())
        commands = self.log.read_text()
        self.assertEqual(commands.count('clone --no-checkout'), 1)
        self.assertNotIn('nvm install', commands)
        self.assertTrue((self.home / 'data/nvm/nvm.sh').exists())

    def test_failed_clone_cleans_only_staging_directory(self):
        self.env['TEST_CASE'] = 'clone-failure'
        self.run_setup('nvm', answers='y\n', expected=1)
        self.assertFalse((self.home / 'data/nvm').exists())
        self.assertEqual(list(self.home.rglob('.dotfiles-download.*')), [])

    def test_pdf_function_arguments(self):
        source = self.home / 'input file.md'
        source.write_text('# Test')
        script = f'source "{ROOT}/md-to-pdf/init.sh"; mdpdf "$HOME/input file.md" -o "$HOME/out dir/result.pdf"'
        result = subprocess.run([BASH, '-c', script], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('md-to-pdf', self.log.read_text())
        result = subprocess.run([BASH, '-c', f'source "{ROOT}/md-to-pdf/init.sh"; mdpdf -o'], env=self.env, capture_output=True)
        self.assertEqual(result.returncode, 2)


if __name__ == '__main__':
    unittest.main(verbosity=2)
