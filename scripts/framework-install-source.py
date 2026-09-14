#!/usr/bin/env python3
"""Read native Git source identity; validate installation without writing anything."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


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


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--development', action='store_true')
    args = parser.parse_args()
    try:
        source = identity(args.root, args.development)
        validate(source)
        print(describe(source))
    except (OSError, ValueError) as error:
        parser.exit(1, f'framework install source error: {error}\n')
