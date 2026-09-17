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
    source = base / 'source with spaces'
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
    home = base / 'home with spaces'
    home.mkdir()
    env = {**os.environ, 'PYTHONDONTWRITEBYTECODE': '1', 'HOME': str(home), 'CODEX_HOME': str(home / '.codex'), 'CODEX_SKILLS_HOME': str(home / '.agents/skills')}
    setup = ['bash', 'scripts/setup.sh']
    # Simulate an incompatible python3 before any path normalization or writes.
    fake_bin = base / 'old-python-bin'
    fake_bin.mkdir()
    fake_python = fake_bin / 'python3'
    fake_python.write_text('#!/bin/sh\nexit 1\n')
    fake_python.chmod(0o755)
    before = snapshot(home)
    result = run(setup, cwd=source, env={**env, 'PATH': str(fake_bin) + os.pathsep + env['PATH']}, ok=False)
    assert 'Python 3.11 or newer' in result.stderr
    assert snapshot(home) == before
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
    skill_collision = home / '.agents/skills/framework-management'
    skill_collision.mkdir(parents=True)
    (skill_collision / 'user.txt').write_text('preserve')
    before = snapshot(home)
    run(setup, cwd=source, env=env, ok=False)
    assert snapshot(home) == before
    shutil.rmtree(skill_collision)
    guidance = home / '.codex/AGENTS.md'
    guidance.write_text('user guidance')
    before = snapshot(home)
    result = run(setup, cwd=source, env=env, ok=False)
    assert snapshot(home) == before and 'strict global guidance is not active' in result.stderr
    guidance.unlink()
    run(setup, cwd=source, env=env)
    assert guidance.is_symlink()
    state_path = home / '.codex/frameworks/.codex-framework-links.json'
    state = json.loads(state_path.read_text())
    assert state['sourceIdentity']['mode'] == 'detached'
    assert state['sourceIdentity']['dirty'] is False
    durable = Path(state['sourceIdentity']['root'])
    assert durable != source and (durable / '.git').is_dir()
    assert not (durable / '.git/objects/info/alternates').exists()
    # Removing the originating checkout must not affect installed files or Git.
    moved = source.with_name('removed checkout')
    source.rename(moved)
    run(['git', 'status', '--porcelain'], cwd=durable, env=env)
    assert (home / '.agents/skills/framework-management/SKILL.md').is_file()
    assert guidance.is_symlink() and guidance.read_text() == (durable / 'templates/global/AGENTS.md').read_text()
    source = durable
    # Native prompt input/config checks are independent; inspect source check directly.
    check = ['python3', 'scripts/framework-link-install.py', '--check', '--state', str(state_path), '--source-root', str(source), '--guidance', f'{guidance}={source}/templates/global/AGENTS.md']
    for dest, target in state['managed'].items():
        check += ['--link', f'{dest}={target}']
    for dest, entry in state['managedFiles'].items():
        check += ['--file', f'{dest}={entry["source"]}']
    run(check, cwd=source, env=env)
    doctor = ['bash', str(home / '.codex/bin/codex-framework-doctor'), '--framework-only', '--skip-prompt-input']
    result = run(doctor, cwd=source, env=env)
    assert 'certification: not checked' in result.stdout
    # Durable destination drift fails before writes too.
    run(['git', 'checkout', '-qb', 'mutable'], cwd=source)
    assert 'installed source drift' in run(check, cwd=source, env=env, ok=False).stderr
    before = snapshot(home)
    run(setup, cwd=moved, env=env, ok=False)
    assert snapshot(home) == before
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
    guidance.unlink()
    guidance.write_text('replacement user guidance')
    before = snapshot(home)
    run(setup + ['--development'], cwd=source, env=env, ok=False)
    assert snapshot(home) == before
    guidance.unlink()
    guidance.symlink_to(source / 'templates/global/AGENTS.md')
    del state['managed'][str(guidance)]
    state_path.write_text(json.dumps(state))
    run(check, cwd=source, env=env, ok=False)
    run(setup + ['--development'], cwd=source, env=env)
    assert str(guidance) in json.loads(state_path.read_text())['managed']
    # Development removal has an explicit repair path when doctor runs from a checkout.
    removed_durable = durable.with_name('removed development source')
    durable.rename(removed_durable)
    result = run(['bash', 'scripts/framework-doctor.sh', '--framework-only', '--skip-prompt-input'], cwd=moved, env=env, ok=False)
    assert 'recovery: run bash scripts/setup.sh' in result.stdout
    run(setup, cwd=moved, env=env)
    assert (home / '.codex/bin/codex-framework-doctor').is_file()
    # Supported invocation is Bash (direct executable or bash), including from zsh.
    if shutil.which('zsh'):
        run(['zsh', '-c', 'bash scripts/setup.sh'], cwd=moved, env=env)
print('installation source self-test passed: durable clone survives removed source, Bash and zsh caller with spaces, unsafe sources, zero-write auxiliary/skill/guidance/release collisions, user guidance, source drift, development recovery, legacy ownership')
