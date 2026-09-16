#!/usr/bin/env python3
"""Read native Git source identity; validate installation without writing anything."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import shutil
import tempfile


def identity(root: Path, development: bool = False) -> dict:
    root = root.resolve(strict=True)
    def git(*args: str) -> bytes:
        result = subprocess.run(['git', '-C', str(root), *args], capture_output=True)
        if result.returncode:
            raise ValueError(f'cannot verify installation source: {result.stderr.decode().strip()}')
        return result.stdout
    if Path(git('rev-parse', '--show-toplevel').decode().strip()).resolve() != root:
        raise ValueError('installation source must be the Git checkout root')
    sha = git('rev-parse', 'HEAD').decode().strip()
    branch = git('branch', '--show-current').decode().strip() or None
    dirty = bool(git('status', '--porcelain=v1', '--untracked-files=all'))
    digest = hashlib.sha256()
    for name in sorted(set(git('ls-files', '-z', '--cached', '--others', '--exclude-standard').split(b'\0')) - {b''}):
        path = root / name.decode()
        content = path.readlink().as_posix().encode() if path.is_symlink() else path.read_bytes() if path.is_file() else b'<missing-or-directory>'
        digest.update(name + b'\0' + str(path.lstat().st_mode if path.exists() or path.is_symlink() else 0).encode() + b'\0' + content + b'\0')
    return {'root': str(root), 'sha': sha, 'branch': branch, 'dirty': dirty,
            'contentDigest': digest.hexdigest(), 'mode': 'development' if development else 'detached'}


def validate(source: dict) -> None:
    if source['mode'] != 'development' and (source['dirty'] or source['branch'] is not None):
        raise ValueError('ordinary installation requires a clean detached Git checkout; use a dedicated git worktree --detach at the intended commit, or explicitly opt in with --development for mutable development links')


def describe(source: dict) -> str:
    return f"source={source['root']} sha={source['sha']} branch={source['branch'] or '(detached)'} dirty={str(source['dirty']).lower()} mode={source['mode']} (source identity only; not release certification)"


def materialize(root: Path, releases: Path) -> Path:
    """Keep release Git objects independent of any disposable source checkout."""
    source = identity(root)
    validate(source)
    if releases.is_symlink():
        raise ValueError(f'release directory collision: {releases}; symlink directories are not managed')
    destination = releases / source['sha']
    if destination.exists() or destination.is_symlink():
        if destination.is_symlink():
            raise ValueError(f'release destination must not be a symlink: {destination}')
        installed = identity(destination)
        if any(installed[key] != source[key] for key in ('sha', 'branch', 'dirty', 'contentDigest')):
            raise ValueError(f'release destination collision or drift: {destination}; preserve it and choose a clean installation location')
        if not (destination / '.git').is_dir() or (destination / '.git/objects/info/alternates').exists():
            raise ValueError(f'release destination is not an independent clone: {destination}')
        return destination
    releases.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='.install-', dir=releases))
    try:
        subprocess.run(['git', 'clone', '--quiet', '--no-local', '--no-checkout', str(root), str(temporary)], check=True)
        subprocess.run(['git', '-C', str(temporary), 'checkout', '--quiet', '--detach', source['sha']], check=True)
        installed = identity(temporary)
        if any(installed[key] != source[key] for key in ('sha', 'branch', 'dirty', 'contentDigest')):
            raise ValueError('source changed while preparing durable release; rerun setup from a clean detached checkout')
        # Clone contains all Git objects and never borrows a worktree gitdir.
        temporary.rename(destination)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--development', action='store_true')
    parser.add_argument('--materialize', type=Path)
    args = parser.parse_args()
    try:
        source = identity(args.root, args.development)
        validate(source)
        print(materialize(args.root, args.materialize) if args.materialize else describe(source))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'framework install source error: {error}\n')
