"""Syntax/runtime smoke tests with real local binaries and isolated state."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RuntimeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('tmux'), 'tmux unavailable')
    def test_tmux_config_in_isolated_server(self):
        with tempfile.TemporaryDirectory(prefix='tmux-dotfiles-') as base:
            home = Path(base) / 'home with spaces'
            config = home / 'config'
            data = home / 'data'
            (config / 'tmux').mkdir(parents=True)
            (config / 'tmux/tmux.conf').symlink_to(ROOT / 'tmux/tmux.conf')
            # Dummy plugin entrypoints prove quoted paths execute correctly.
            for directory, filename in [('tpm', 'tpm'), ('vim-tmux-navigator', 'vim-tmux-navigator.tmux')]:
                p = data / 'tmux/plugins' / directory / filename
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text('#!/bin/sh\nprintf loaded > "' + str(home / directory) + '"\n')
                p.chmod(0o755)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_DATA_HOME=str(data))
            env.pop('TMUX', None)
            socket = str(Path(base) / 'socket')
            command = [shutil.which('tmux'), '-S', socket]
            try:
                result = subprocess.run(command + ['-f', str(ROOT / 'tmux/loader.conf'), 'new-session', '-d', '-s', 'test'], env=env, capture_output=True, text=True, timeout=10)
                if result.returncode and 'Operation not permitted' in result.stderr:
                    self.skipTest('Environment blocks tmux Unix sockets; runtime loading unverified')
                self.assertEqual(result.returncode, 0, result.stderr)
                result = subprocess.run(command + ['show-options', '-gv', 'prefix'], env=env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.stdout.strip(), 'C-a')
                result = subprocess.run(command + ['show-environment', '-g', 'TMUX_PLUGIN_MANAGER_PATH'], env=env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.stdout.strip(), f'TMUX_PLUGIN_MANAGER_PATH={data}/tmux/plugins/')
                self.assertEqual((home / 'tpm').read_text(), 'loaded')
                self.assertEqual((home / 'vim-tmux-navigator').read_text(), 'loaded')
            finally:
                subprocess.run(command + ['kill-server'], env=env, capture_output=True, timeout=10)

    @unittest.skipUnless(shutil.which('nvim'), 'nvim unavailable')
    def test_lua_syntax_without_loading_plugins(self):
        with tempfile.TemporaryDirectory(prefix='nvim-dotfiles-') as base:
            env = dict(os.environ, HOME=base, XDG_CONFIG_HOME=f'{base}/config',
                       XDG_DATA_HOME=f'{base}/data', XDG_STATE_HOME=f'{base}/state', XDG_CACHE_HOME=f'{base}/cache')
            env.pop('NVIM_APPNAME', None)
            script = Path(base) / 'syntax.lua'
            # loadfile only compiles; no module or plugin code is executed.
            paths = [*ROOT.glob('nvim/config/**/*.lua'), ROOT / 'wezterm/wezterm.lua']
            import json
            script.write_text('\n'.join('assert(loadfile(' + json.dumps(str(p)) + '))' for p in paths))
            result = subprocess.run([shutil.which('nvim'), '--clean', '--headless', '-i', 'NONE', '-u', 'NONE', '-l', str(script)], env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
