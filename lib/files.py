#!/usr/bin/env python3
"""Link management with private journals; never read configuration contents."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import sys
import tempfile


def exists(path):
    return os.path.lexists(path)


def safe_parents(path):
    # Refuse symlink parents: writing through one could modify another config/repo.
    for parent in path.parents:
        if parent.is_symlink():
            raise ValueError(f"symlink parent requires manual resolution: {parent}")


def private_state(root, repo):
    safe_parents(root / 'placeholder')
    if root == repo or repo in root.parents:
        raise ValueError('backup/state directory must be outside the repository')
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(root, 0o700)


def save(path, data):
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as stream:
        json.dump(data, stream, indent=2)
        stream.write('\n')
        temporary = stream.name
    os.replace(temporary, path)


def link(args):
    source, destination = Path(args.source).absolute(), Path(args.destination).absolute()
    repo = Path(args.repo).resolve()
    if destination == repo or repo in destination.parents:
        raise ValueError('configuration destinations must be outside the repository')
    if not source.exists():
        raise ValueError(f'managed source missing: {source}')
    if destination.is_symlink() and destination.resolve() == source.resolve():
        print(f'[already configured] {destination}')
        return 0
    safe_parents(destination)
    conflict = exists(destination)
    snapshot = destination.lstat() if conflict else None
    if args.mode != 'apply':
        print(f'[{"conflict" if conflict else "missing"}] {destination} -> {source}')
        return int(args.mode == 'check')
    if conflict:
        print(f'Conflict at {destination}. Back up and link, or skip? [b/S] ', end='', file=sys.stderr, flush=True)
        choice = sys.stdin.readline().strip().lower()
        if choice not in ('b', 'backup'):
            print(f'[skipped] {destination}')
            return 0
    root = Path(args.state).absolute()
    private_state(root, Path(args.repo).resolve())
    with (root / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # Recheck after the prompt/lock to avoid replacing newly created files.
        if exists(destination) != conflict or (conflict and destination.lstat() != snapshot):
            raise ValueError(f'destination changed while waiting: {destination}')
        run = Path(tempfile.mkdtemp(prefix='link-', dir=root))
        backup = run / 'original'
        record = {'destination': str(destination), 'source': str(source),
                  'backup': str(backup) if conflict else None, 'status': 'prepared'}
        manifest = run / 'manifest.json'
        save(manifest, record)
        if conflict:
            destination.rename(backup)
        try:
            destination.parent.mkdir(parents=True, exist_ok=True)
            # os.symlink fails if a competing writer created a destination.
            destination.symlink_to(source, target_is_directory=source.is_dir())
        except BaseException:
            if conflict and not exists(destination):
                backup.rename(destination)
            record['status'] = 'failed'
            save(manifest, record)
            raise
        record['status'] = 'linked'
        save(manifest, record)
        print(f'[configured] {destination}; recovery: {manifest}')
    return 0


def rollback(args):
    root = Path(args.state).absolute()
    if not root.exists():
        print('[already configured] no link journal exists')
        return 0
    manifests = sorted(root.glob('link-*/manifest.json'), key=lambda p: p.stat().st_mtime_ns, reverse=True)
    if args.mode != 'apply':
        for manifest in manifests:
            print(f'[planned] inspect/restore {manifest}')
        return 0
    private_state(root, Path(args.repo).resolve())
    failed = False
    with (root / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for manifest in manifests:
            record = json.loads(manifest.read_text())
            if record['status'] != 'linked':
                continue
            destination, source = Path(record['destination']), Path(record['source'])
            safe_parents(destination)
            if not destination.is_symlink() or os.readlink(destination) != str(source):
                print(f'[failed] changed since setup; left untouched: {destination}')
                failed = True
                continue
            backup = Path(record['backup']) if record['backup'] else None
            if backup and not exists(backup):
                print(f'[failed] backup missing; left untouched: {destination}')
                failed = True
                continue
            print(f'Restore {destination}? [y/N] ', end='', file=sys.stderr, flush=True)
            if sys.stdin.readline().strip().lower() not in ('y', 'yes'):
                print(f'[skipped] {destination}')
                continue
            destination.unlink()
            try:
                if backup:
                    backup.rename(destination)
            except BaseException:
                destination.symlink_to(source)
                raise
            record['status'] = 'restored'
            save(manifest, record)
            print(f'[configured] restored {destination}')
    return int(failed)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['link', 'rollback'])
    parser.add_argument('--source')
    parser.add_argument('--destination')
    parser.add_argument('--state', required=True)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--mode', choices=['check', 'dry-run', 'apply'], required=True)
    args = parser.parse_args()
    try:
        return link(args) if args.operation == 'link' else rollback(args)
    except (OSError, ValueError) as error:
        print(f'[failed] {error}')
        return 1


if __name__ == '__main__':
    sys.exit(main())
