#!/usr/bin/env python3
"""Installation source and collision regressions; all writes use temporary homes."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent

def run(command, *, cwd, env=None, ok=True):
    result = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True)
    assert (result.returncode == 0) == ok, result.stdout + result.stderr
    return result

def snapshot(path):
    return {str(p.relative_to(path)): ('link', os.readlink(p)) if p.is_symlink() else ('file', p.read_bytes()) if p.is_file() else ('dir', '') for p in path.rglob('*')}

with tempfile.TemporaryDirectory(prefix='framework-source-test-') as temporary:
    base = Path(temporary).resolve()
    source = base / 'source'
    source.mkdir()
    # Copy current owned and baseline source, including uncommitted changes, into
    # a separate Git fixture. Never run setup against the real user home.
    files = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT).split(b'\0')
    for name in set(files) - {b''}:
        original = ROOT / os.fsdecode(name)
        if original.is_file():
            destination = source / os.fsdecode(name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, destination, follow_symlinks=False)
    run(['git', 'init', '-q'], cwd=source)
    run(['git', 'add', '.'], cwd=source)
    run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], cwd=source)
    home = base / 'home'
    home.mkdir()
    env = {**os.environ, 'PYTHONDONTWRITEBYTECODE': '1', 'HOME': str(home), 'CODEX_HOME': str(home / '.codex'), 'CODEX_SKILLS_HOME': str(home / '.agents/skills')}
    setup = ['bash', 'scripts/setup.sh']
    before = snapshot(home)
    result = run(setup, cwd=source, env=env, ok=False)
    assert 'clean detached Git checkout' in result.stderr
    assert snapshot(home) == before
    run(['git', 'checkout', '--detach', '-q'], cwd=source)
    (source / 'dirty.txt').write_text('dirty')
    run(setup, cwd=source, env=env, ok=False)
    assert snapshot(home) == before
    (source / 'dirty.txt').unlink()
    collision = home / '.codex/bin/codex-framework-doctor'
    collision.parent.mkdir(parents=True)
    collision.write_text('user owned')
    before = snapshot(home)
    run(setup, cwd=source, env=env, ok=False)
    assert snapshot(home) == before
    collision.unlink()
    guidance = home / '.codex/AGENTS.md'
    guidance.write_text('user guidance')
    run(setup, cwd=source, env=env)
    assert guidance.read_text() == 'user guidance' and not guidance.is_symlink()
    state_path = home / '.codex/frameworks/.codex-framework-links.json'
    state = json.loads(state_path.read_text())
    assert state['sourceIdentity']['mode'] == 'detached'
    assert state['sourceIdentity']['dirty'] is False
    # Native prompt input/config checks are independent; inspect source check directly.
    check = ['python3', 'scripts/framework-link-install.py', '--check', '--state', str(state_path), '--source-root', str(source), '--guidance', f'{guidance}={source}/templates/global/AGENTS.md']
    for dest, target in state['managed'].items():
        check += ['--link', f'{dest}={target}']
    for dest, entry in state['managedFiles'].items():
        check += ['--file', f'{dest}={entry["source"]}']
    run(check, cwd=source, env=env)
    run(['git', 'checkout', '-qb', 'mutable'], cwd=source)
    assert 'installed source drift' in run(check, cwd=source, env=env, ok=False).stderr
    run(['git', 'checkout', '--detach', '-q'], cwd=source)
    (source / 'README.md').write_text('source drift')
    result = run(check, cwd=source, env=env, ok=False)
    assert 'installed source drift' in result.stderr
    run(setup + ['--development'], cwd=source, env=env)
    state = json.loads(state_path.read_text())
    assert state['sourceIdentity']['mode'] == 'development' and state['sourceIdentity']['dirty']
    run(check, cwd=source, env=env)
    (source / 'README.md').write_text('further dirty source drift')
    assert 'installed source drift' in run(check, cwd=source, env=env, ok=False).stderr
    # Prove legacy ownership from both stored and actual root link, then migrate.
    guidance.unlink()
    guidance.symlink_to(source / 'templates/global/AGENTS.md')
    run(setup + ['--development'], cwd=source, env=env)
    state = json.loads(state_path.read_text())
    assert state['managed'][str(guidance)] == str(source / 'templates/global/AGENTS.md')
    del state['managed'][str(guidance)]
    state_path.write_text(json.dumps(state))
    run(check, cwd=source, env=env, ok=False)
    run(setup + ['--development'], cwd=source, env=env)
    assert str(guidance) in json.loads(state_path.read_text())['managed']
print('installation source self-test passed: unsafe sources, zero-write collision, user guidance, detached and development installs, source drift, legacy ownership')
