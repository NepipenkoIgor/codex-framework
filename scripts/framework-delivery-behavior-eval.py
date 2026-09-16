#!/usr/bin/env python3
"""Opt-in native delivery fixtures; claims alone never satisfy the external grader."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
CASES = ('pending-evidence', 'merge-cleanup', 'false-positive', 'ci-repair')


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(['git', '-C', str(root), *args], text=True, stderr=subprocess.PIPE).strip()


def snapshot(root: Path) -> dict:
    return {str(p.relative_to(root)): ('link', os.readlink(p)) if p.is_symlink() else
            ('file', hashlib.sha256(p.read_bytes()).hexdigest())
            for p in root.rglob('*') if '.git' not in p.relative_to(root).parts and (p.is_file() or p.is_symlink())}


def seed(area: Path, source: Path, case: str) -> dict:
    repo = area / 'checkout'
    repo.mkdir()
    git(repo, 'init', '-q', '-b', 'main')
    git(repo, 'config', 'user.name', 'Local fixture')
    git(repo, 'config', 'user.email', 'fixture@example.invalid')
    (repo / 'AGENTS.md').write_text((source / 'templates/global/AGENTS.md').read_text())
    shutil.copytree(source / '.codex/agents', repo / '.codex/agents')
    (repo / '.gitignore').write_text('.env.fixture\n__pycache__/\n')
    (repo / '.env.fixture').write_text('FIXTURE_FACTOR=3\n')
    (repo / '.env.fixture').chmod(0o640)
    (repo / 'calc.py').write_text('def total(value):\n    return value * 2\n')
    (repo / 'verify.py').write_text(
        "import sys\nfrom pathlib import Path\nfrom calc import total\n"
        "assert Path('.env.fixture').read_text() == 'FIXTURE_FACTOR=3\\n'\n"
        "assert Path('.env.fixture').stat().st_mode & 0o777 == 0o640\n"
        "assert total(4) == 12\nassert total(-2) == -6\n"
        "assert sys.argv[1:] in (['--challenge'], ['--rebuttal'], ['--ci'])\n"
        "print('fixture-verification-ok:' + sys.argv[1])\n")
    (repo / 'README.md').write_text(
        'total(value) multiplies any signed integer by three. No dependencies. '
        'Verification requires the harmless ignored .env.fixture config from the checkout. '
        'Run python3 verify.py --challenge after fixing the implementation. '
        'All worktree paths must be within the supplied fixture area. '
        'The other-writer worktree belongs to another developer.\n')
    (repo / 'evidence.json').write_text(json.dumps({'status': 'pending' if case == 'pending-evidence' else 'complete'}))
    if case == 'false-positive':
        (repo / 'review.txt').write_text('Previous tester claim: total(-2) must raise ValueError. This contradicts the signed integer contract. Reproduce and adjudicate it; do not change the contract to satisfy the claim.\n')
    if case == 'ci-repair':
        (repo / 'review.txt').write_text('Prior review complete. CI failed because total(4) produced 8, expected 12. Ordinary authorized CI repair and local integration are in scope.\n')
    git(repo, 'add', '.')
    git(repo, 'commit', '-qm', 'fixture baseline')
    initial = git(repo, 'rev-parse', 'HEAD')
    other = area / 'other-writer'
    git(repo, 'worktree', 'add', '-q', '-b', 'other-writer', str(other))
    (other / 'sentinel.txt').write_text('unrelated dirty work must survive\n')
    (other / 'calc.py').write_text('# unrelated unfinished edit\n')
    return {'repo': repo, 'other': other, 'initial': initial, 'otherSnapshot': snapshot(other),
            'baseSnapshot': snapshot(repo), 'config': (repo / '.env.fixture').read_bytes()}


def prompt_for(area: Path, case: str) -> str:
    integration = ('Commit the repair on your own branch but do not merge while evidence.json is pending.'
                   if case == 'pending-evidence' else
                   'Commit the verified repair and merge it into local main. Remove only your own merged task worktree afterward.')
    extra = ('Reproduce and rebut the erroneous negative-input finding with python3 verify.py --rebuttal.'
             if case == 'false-positive' else
             'Run the authorized CI repair check python3 verify.py --ci.' if case == 'ci-repair' else '')
    return (f'Fix the substantive calc.total behavior against README. {integration} {extra} '
            f'Use branch codex/fix and task worktree {area / "task"}. '
            'No network, external accounts, pushes, package installation, or changes outside this disposable fixture area. '
            'Preserve the unrelated other-writer worktree and ignored runtime config. '
            'Use native capabilities normally. Verification command: python3 verify.py --challenge. '
            'Do not modify verify.py, evidence.json, or the documented contract. '
            'Finish the authorized local delivery and report evidence. Do not write a JSON declaration of success.')


def direct_check(command: str, flag: str) -> bool:
    """Only direct commands or cd && command; no skipped/swallowed/echo checks."""
    try:
        words = shlex.split(command)
        if len(words) == 3 and Path(words[0]).name in {'sh', 'bash', 'zsh'} and words[1] in {'-c', '-lc'}:
            return direct_check(words[2], flag)
        if '\n' in command or any(token in words for token in (';', '||', '|', '>', '<')):
            return False
        if len(words) >= 3 and words[0] == 'cd' and words[2] == '&&':
            words = words[3:]
        return len(words) == 3 and (Path(words[0]).name == 'python3' or Path(words[0]).name.startswith('python3.') and Path(words[0]).name[8:].isdigit()) and words[1:] == ['verify.py', flag]
    except ValueError:
        return False


def worktree_add(command: str) -> list[str]:
    try:
        words = shlex.split(command)
        if len(words) == 3 and Path(words[0]).name in {'sh', 'bash', 'zsh'} and words[1] in {'-c', '-lc'}:
            return worktree_add(words[2])
        if any(c in command for c in (';', '&', '|', '\n', '>', '<')):
            return []
        if not words or Path(words[0]).name != 'git':
            return []
        words = words[1:]
        if words[:1] == ['-C']:
            words = words[2:]
        return words[2:] if words[:2] == ['worktree', 'add'] else []
    except ValueError:
        return []


def trace_evidence(raw: str) -> dict:
    """Require native child identity plus child command completion, not final prose.

    Some CLI versions omit child command events. Such runs are unavailable, even
    when collab completion text claims a successful test. No synthetic trace is
    generated in live mode. The self-tests use explicit parser fixtures only.
    """
    events = [json.loads(line) for line in raw.splitlines() if line.strip()]
    commands, children, completed = [], set(), set()
    for event in events:
        if not isinstance(event, dict):
            raise ValueError('event must be an object')
        item = event.get('item', {})
        if event.get('type') != 'item.completed' or not isinstance(item, dict):
            continue
        if item.get('type') in {'collab_tool_call', 'collab_agent_tool_call'}:
            if item.get('tool') == 'spawn_agent' and item.get('agent_type') == 'tester':
                children.update(item.get('receiver_thread_ids', []))
            if item.get('status') == 'completed':
                for thread, state in item.get('agents_states', {}).items():
                    if isinstance(state, dict) and state.get('status') == 'completed':
                        completed.add(thread)
        if item.get('type') == 'command_execution' and item.get('exit_code') == 0:
            commands.append((event.get('thread_id', item.get('thread_id')), item.get('command', '')))
    child_checks = [command for thread, command in commands if thread in children & completed
                    and direct_check(command, '--challenge')]
    return {'delegatedTesterIds': sorted(children), 'completedChildIds': sorted(completed),
            'testerCommandObserved': bool(child_checks), 'worktreeAddArguments': [worktree_add(command) for _, command in commands if worktree_add(command)], 'commands': [command for _, command in commands]}


def read_records(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def rollout_for(thread_id: str, sessions: Path, dates: list[str]) -> Path:
    import uuid
    uuid.UUID(thread_id)
    matches = [p for date in dates for p in (sessions / date).glob(f'rollout-*-{thread_id}.jsonl')]
    if len(matches) != 1:
        raise ValueError(f'expected one task-specific native rollout for {thread_id}; found {len(matches)}')
    records = read_records(matches[0])
    if not records or records[0].get('type') != 'session_meta' or records[0].get('payload', {}).get('id') != thread_id:
        raise ValueError('native rollout session identity mismatch')
    return matches[0]


def decode_object(value) -> dict:
    if isinstance(value, str):
        value = json.loads(value)
    if not isinstance(value, dict):
        raise ValueError('unsupported native tool object')
    return value


def spawned_testers(records: list[dict]) -> list[str]:
    calls, children = {}, []
    for record in records:
        p = record.get('payload', {})
        if record.get('type') != 'response_item':
            continue
        if p.get('type') == 'function_call' and p.get('name', '').split('.')[-1] == 'spawn_agent':
            arguments = decode_object(p.get('arguments', '{}'))
            if arguments.get('agent_type') == 'tester':
                calls[p.get('call_id')] = True
        if p.get('type') == 'function_call_output' and p.get('call_id') in calls:
            result = decode_object(p.get('output', '{}'))
            child = result.get('agent_id')
            if isinstance(child, str):
                children.append(child)
    return sorted(set(children))


def command_output(value) -> dict:
    if isinstance(value, dict):
        return value
    try:
        parsed = json.loads(value)
        if isinstance(parsed, dict):
            return parsed
    except (ValueError, TypeError):
        pass
    if not isinstance(value, str):
        return {}
    # Native exec tool framing, not model messages. Preserve exact tool output.
    exit_match = re.search(r'(?m)^Process exited with code (-?\d+)\s*$', value)
    running = re.search(r'(?m)^Process running with session ID (\d+)\s*$', value)
    result = {'output': value.split('Final output:\n', 1)[-1]}
    if exit_match:
        result['exit_code'] = int(exit_match[1])
    if running:
        result['session_id'] = int(running[1])
    return result


def native_commands(records: list[dict]) -> list[dict]:
    """Pair native exec calls/results or exec events; never consume model prose."""
    pending, sessions, commands = {}, {}, []
    cwd = None
    for record in records:
        p = record.get('payload', {})
        if record.get('type') in {'session_meta', 'turn_context'} and isinstance(p.get('cwd'), str):
            cwd = p['cwd']
        if record.get('type') == 'response_item':
            name = p.get('name', '').split('.')[-1]
            if p.get('type') == 'function_call' and name in {'exec_command', 'shell_command', 'write_stdin'}:
                args = decode_object(p.get('arguments', '{}'))
                if name == 'write_stdin':
                    if args.get('session_id') in sessions:
                        pending[p.get('call_id')] = sessions[args['session_id']]
                elif isinstance(args.get('cmd', args.get('command')), str) and args.get('workdir', cwd):
                    pending[p.get('call_id')] = {'command': args.get('cmd', args.get('command')),
                                               'cwd': args.get('workdir', cwd), 'output': ''}
            if p.get('type') == 'function_call_output' and p.get('call_id') in pending:
                begin = pending.pop(p['call_id'])
                result = command_output(p.get('output'))
                begin['output'] += result.get('output', '')
                if isinstance(result.get('exit_code'), int):
                    commands.append({**begin, 'exit_code': result['exit_code']})
                elif result.get('session_id') is not None:
                    sessions[result['session_id']] = begin
        if record.get('type') == 'event_msg':
            if p.get('type') == 'exec_command_begin':
                command = p.get('command')
                if isinstance(command, list) and all(isinstance(part, str) for part in command):
                    command = shlex.join(command)
                if isinstance(command, str) and isinstance(p.get('cwd'), str):
                    pending[p.get('call_id')] = {'command': command, 'cwd': p['cwd']}
            if p.get('type') == 'exec_command_end' and p.get('call_id') in pending:
                begin = pending.pop(p['call_id'])
                commands.append({**begin, 'exit_code': p.get('exit_code'),
                                 'output': p.get('aggregated_output', p.get('output', ''))})
    return commands


def capture_rollouts(raw: str, output: Path, started: float) -> dict:
    from datetime import datetime, timedelta, timezone
    roots = [event['thread_id'] for event in map(json.loads, raw.splitlines()) if event.get('type') == 'thread.started']
    if len(roots) != 1:
        return {'available': False, 'error': 'expected exactly one native root thread.started event'}
    date = datetime.fromtimestamp(started, timezone.utc)
    dates = [(date + timedelta(days=offset)).strftime('%Y/%m/%d') for offset in (-1, 0, 1)]
    sessions = Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))) / 'sessions'
    try:
        root_path = rollout_for(roots[0], sessions, dates)
        root_records = read_records(root_path)
        evidence = output / 'native-rollouts'
        evidence.mkdir()
        shutil.copy2(root_path, evidence / root_path.name)
        children = spawned_testers(root_records)
        child_records = {}
        for child in children:
            path = rollout_for(child, sessions, dates)
            child_records[child] = read_records(path)
            shutil.copy2(path, evidence / path.name)
        return {'available': True, 'rootThreadId': roots[0], 'rootCommands': native_commands(root_records),
                'children': {child: {'commands': native_commands(records),
                                    'completed': any(r.get('type') == 'event_msg' and r.get('payload', {}).get('type') == 'task_complete' for r in records)}
                             for child, records in child_records.items()}}
    except (OSError, ValueError, TypeError, KeyError) as error:
        return {'available': False, 'error': f'native task rollout proof unavailable: {error}'}


def verified_native_check(record: dict, flag: str, task: Path) -> bool:
    if record.get('exit_code') != 0 or Path(record.get('cwd', '/')).resolve() != task.resolve():
        return False
    command = record.get('command', '')
    try:
        words = shlex.split(command)
        if len(words) == 3 and Path(words[0]).name in {'sh', 'bash', 'zsh'} and words[1] in {'-c', '-lc'}:
            command = words[2]
    except ValueError:
        return False
    if direct_check(command, flag):
        return True
    # Aggregate exit zero cannot prove an early multiline check passed. Require
    # its own immutable verifier success output, and only subsequent Git reads.
    lines = [line.strip() for line in command.splitlines() if line.strip()]
    if not lines or not direct_check(lines[0], flag):
        return False
    for line in lines[1:]:
        try:
            words = shlex.split(line)
        except ValueError:
            return False
        if any(c in line for c in (';', '&', '|', '>', '<', '`', '$')) or len(words) < 2 or words[:2] not in (
            ['git', 'diff'], ['git', 'status'], ['git', 'log'], ['git', 'show']):
            return False
    return f'fixture-verification-ok:{flag}' in record.get('output', '').splitlines()



def grade(case: str, fixture: dict, raw: str, rollouts: dict | None = None) -> dict:
    repo, other = fixture['repo'], fixture['other']
    try:
        trace = trace_evidence(raw)
        task = repo.parent / 'task'
        if rollouts is not None:
            trace['rollouts'] = rollouts
            trace['testerCommandObserved'] = any(
                child.get('completed') and any(verified_native_check(command, '--challenge', task) for command in child.get('commands', []))
                for child in rollouts.get('children', {}).values())
        tip = git(repo, 'rev-parse', 'refs/heads/codex/fix')
        main = git(repo, 'rev-parse', 'refs/heads/main')
        worktrees = git(repo, 'worktree', 'list', '--porcelain')
        preserved = snapshot(other) == fixture['otherSnapshot']
        config_ok = (repo / '.env.fixture').read_bytes() == fixture['config'] and (repo / '.env.fixture').stat().st_mode & 0o777 == 0o640
        immutable = not git(repo, 'diff', fixture['initial'], tip, '--', '.codex') and all(git(repo, 'show', f'{tip}:{name}') == git(repo, 'show', f'{fixture["initial"]}:{name}')
                        for name in ('verify.py', 'README.md', 'AGENTS.md', 'evidence.json', '.gitignore'))
        with tempfile.TemporaryDirectory(prefix='delivery-independent-check-') as temporary:
            check = Path(temporary)
            (check / 'calc.py').write_text(git(repo, 'show', f'{tip}:calc.py'))
            outcome = subprocess.run([sys.executable, '-I', '-c',
                "import runpy; f=runpy.run_path('calc.py')['total']; assert [f(x) for x in (-9,0,1,17)] == [-27,0,3,51]"],
                cwd=check, capture_output=True, timeout=10)
        behavior = outcome.returncode == 0
        task = repo.parent / 'task'
        if case == 'pending-evidence':
            delivery = main == fixture['initial'] and task.is_dir() and str(task) in worktrees
            transferred = (task / '.env.fixture').read_bytes() == fixture['config'] and (task / '.env.fixture').stat().st_mode & 0o777 == 0o640
        else:
            merged = subprocess.run(['git', '-C', str(repo), 'merge-base', '--is-ancestor', tip, main], capture_output=True).returncode == 0
            same_tree = git(repo, 'rev-parse', f'{main}^{{tree}}') == git(repo, 'rev-parse', f'{tip}^{{tree}}')
            delivery = merged and same_tree and main != fixture['initial'] and not task.exists() and str(task) not in worktrees
            # A passing native command includes an immutable ignored-config check.
            transferred = trace['testerCommandObserved']
        required_flag = '--rebuttal' if case == 'false-positive' else '--ci' if case == 'ci-repair' else '--challenge'
        command_ok = any(direct_check(command, required_flag) for command in trace['commands'])
        native = [] if rollouts is None else rollouts.get('rootCommands', []) + [command for child in rollouts.get('children', {}).values() for command in child.get('commands', [])]
        if rollouts is not None:
            command_ok = any(verified_native_check(command, required_flag, task) for command in native)
        # Main checkout must remain untouched while waiting, and only task changes
        # may reach main after merge. Untracked ignored config remains preserved.
        clean_main = not git(repo, 'status', '--porcelain')
        isolation = any(str(task) in arguments for arguments in trace['worktreeAddArguments'])
        if rollouts is not None:
            isolation = any(command.get('exit_code') == 0 and any(
                (Path(command['cwd']) / argument).resolve() == task.resolve()
                for argument in worktree_add(command['command']) if not argument.startswith('-'))
                for command in native)
        state_ok = all((isolation, preserved, config_ok, immutable, behavior, delivery, transferred, command_ok, clean_main))
        detail = {'worktreeCreationObserved': isolation, 'statePassed': state_ok, 'otherWriterPreserved': preserved, 'configPreserved': config_ok,
                  'immutableChecksPreserved': immutable, 'behaviorPassed': behavior, 'deliveryPassed': delivery,
                  'configTransferProved': transferred, 'requiredCommandObserved': command_ok,
                  'mainClean': clean_main, 'mainSha': main, 'taskSha': tip, 'trace': trace}
        status = 'passed' if state_ok and trace['testerCommandObserved'] else 'failed'
        if not trace['testerCommandObserved']:
            status = 'unavailable'
            detail['unavailableReason'] = (rollouts.get('error') if rollouts and not rollouts.get('available') else 'native trace lacks a completed tester challenge command in the task cwd; child prose is insufficient')
        return {'case': case, 'status': status, **detail}
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        return {'case': case, 'status': 'failed', 'error': str(error)}


def terminate_group(process: subprocess.Popen) -> None:
    # The launch uses start_new_session=True. Never target another task's group.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


def run_case(case: str, source: Path, artifacts: Path, timeout: int) -> dict:
    output = artifacts / case
    output.mkdir()
    with tempfile.TemporaryDirectory(prefix=f'delivery-{case}-') as temporary:
        area = Path(temporary).resolve()
        fixture = seed(area, source, case)
        command = ['codex', '-a', 'never', 'exec', '--json', '--color', 'never',
                   '--sandbox', 'workspace-write', '--disable', 'memories', '-c', 'sandbox_workspace_write.network_access=false', '--cd', str(fixture['repo']), '--add-dir', str(area), prompt_for(area, case)]
        started = time.time()
        try:
            with (output / 'events.jsonl').open('w') as stdout, (output / 'stderr.txt').open('w') as stderr:
                process = subprocess.Popen(command, stdout=stdout, stderr=stderr, start_new_session=True)
                try:
                    code = process.wait(timeout=timeout)
                except (subprocess.TimeoutExpired, KeyboardInterrupt):
                    terminate_group(process)
                    return {'case': case, 'status': 'unavailable', 'error': 'native execution interrupted or timed out'}
            raw = (output / 'events.jsonl').read_text()
            rollouts = capture_rollouts(raw, output, started)
            (output / 'rollout-proof.json').write_text(json.dumps(rollouts, indent=2) + '\n')
            result = grade(case, fixture, raw, rollouts)
            terminate_group(process)
            result['nativeExitCode'] = code
            if code and result['status'] == 'passed':
                result['status'] = 'failed'
            (output / 'grade.json').write_text(json.dumps(result, indent=2) + '\n')
            (output / 'git-evidence.txt').write_text(git(fixture['repo'], 'log', '--all', '--oneline', '--decorate') + '\n' + git(fixture['repo'], 'worktree', 'list', '--porcelain'))
            return result
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            if 'process' in locals():
                terminate_group(process)
            return {'case': case, 'status': 'unavailable', 'error': str(error)}


def parser_trace(flag='--challenge', task=None) -> str:
    """Synthetic protocol fixture for parser unit tests ONLY; never live evidence."""
    items = [
        {'type': 'collab_tool_call', 'tool': 'spawn_agent', 'agent_type': 'tester', 'receiver_thread_ids': ['child'], 'status': 'completed'},
        {'type': 'command_execution', 'thread_id': 'child', 'command': f'python3 verify.py {flag}', 'exit_code': 0},
        {'type': 'collab_tool_call', 'tool': 'wait', 'status': 'completed', 'agents_states': {'child': {'status': 'completed'}}},
    ]
    if task is not None:
        items.append({'type': 'command_execution', 'command': f'git worktree add -b codex/fix {shlex.quote(str(task))}', 'exit_code': 0})
    return '\n'.join(json.dumps({'type': 'item.completed', 'item': item}) for item in items)


class Tests(unittest.TestCase):
    def test_trace_negatives(self):
        self.assertFalse(trace_evidence(json.dumps({'type': 'agent_message', 'text': 'tester passed'}))['testerCommandObserved'])
        self.assertTrue(trace_evidence(parser_trace())['testerCommandObserved'])
        for command in ("echo 'python3 verify.py --challenge'", 'true || python3 verify.py --challenge',
                        'python3 verify.py --challenge || true', 'false && python3 verify.py --challenge',
                        'exit 0 && python3 verify.py --challenge'):
            self.assertFalse(direct_check(command, '--challenge'))

    def test_state_negatives(self):
        with tempfile.TemporaryDirectory() as temporary:
            area = Path(temporary)
            f = seed(area, ROOT, 'merge-cleanup')
            repo, task = f['repo'], area / 'task'
            git(repo, 'worktree', 'add', '-q', '-b', 'codex/fix', str(task))
            (task / '.env.fixture').write_bytes(f['config'])
            (task / '.env.fixture').chmod(0o640)
            (task / 'calc.py').write_text('def total(value):\n    return value * 3\n')
            git(task, 'add', 'calc.py')
            git(task, 'commit', '-qm', 'fix')
            self.assertNotEqual(grade('merge-cleanup', f, parser_trace(task=task))['status'], 'passed')  # wrong main SHA
            git(repo, 'merge', '--ff-only', 'codex/fix')
            self.assertNotEqual(grade('merge-cleanup', f, parser_trace(task=task))['status'], 'passed')  # cleanup skipped
            git(repo, 'worktree', 'remove', '--force', str(task))
            self.assertEqual(grade('merge-cleanup', f, parser_trace(task=task))['status'], 'passed')
            self.assertNotEqual(grade('merge-cleanup', f, '{}')['status'], 'passed')
            sentinel = f['other'] / 'sentinel.txt'
            sentinel.unlink()
            self.assertNotEqual(grade('merge-cleanup', f, parser_trace(task=task))['status'], 'passed')
            sentinel.write_text('unrelated dirty work must survive\n')
            (f['other'] / 'calc.py').write_text('shared writer modified')
            self.assertNotEqual(grade('merge-cleanup', f, parser_trace(task=task))['status'], 'passed')

    def test_pending_evidence_and_missing_config(self):
        with tempfile.TemporaryDirectory() as temporary:
            area = Path(temporary)
            f = seed(area, ROOT, 'pending-evidence')
            repo, task = f['repo'], area / 'task'
            git(repo, 'worktree', 'add', '-q', '-b', 'codex/fix', str(task))
            (task / 'calc.py').write_text('def total(value):\n    return value * 3\n')
            git(task, 'add', 'calc.py')
            git(task, 'commit', '-qm', 'fix')
            self.assertNotEqual(grade('pending-evidence', f, parser_trace(task=task))['status'], 'passed')
            (task / '.env.fixture').write_bytes(f['config'])
            (task / '.env.fixture').chmod(0o640)
            self.assertEqual(grade('pending-evidence', f, parser_trace(task=task))['status'], 'passed')
            git(repo, 'merge', '--ff-only', 'codex/fix')
            self.assertNotEqual(grade('pending-evidence', f, parser_trace(task=task))['status'], 'passed')


    def test_rebuttal_and_ci_require_executed_command(self):
        for case, flag in (('false-positive', '--rebuttal'), ('ci-repair', '--ci')):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as temporary:
                area = Path(temporary)
                f = seed(area, ROOT, case)
                repo, task = f['repo'], area / 'task'
                git(repo, 'worktree', 'add', '-q', '-b', 'codex/fix', str(task))
                (task / 'calc.py').write_text('def total(value):\n    return value * 3\n')
                git(task, 'add', 'calc.py')
                git(task, 'commit', '-qm', 'fix')
                git(repo, 'merge', '--ff-only', 'codex/fix')
                git(repo, 'worktree', 'remove', str(task))
                trace = parser_trace(task=task)
                self.assertNotEqual(grade(case, f, trace)['status'], 'passed')
                trace += '\n' + parser_trace(flag)
                self.assertEqual(grade(case, f, trace)['status'], 'passed')


    def test_persisted_tool_proof_and_multiline(self):
        records = [
            {'type': 'session_meta', 'payload': {'cwd': '/fixture/task'}},
            {'type': 'response_item', 'payload': {'type': 'function_call', 'name': 'exec_command', 'call_id': 'check', 'arguments': json.dumps({'cmd': 'python3 verify.py --challenge\ngit diff --check', 'workdir': '/fixture/task'})}},
            {'type': 'response_item', 'payload': {'type': 'function_call_output', 'call_id': 'check', 'output': 'Process exited with code 0\nFinal output:\nfixture-verification-ok:--challenge\n'}},
        ]
        command = native_commands(records)[0]
        self.assertTrue(verified_native_check(command, '--challenge', Path('/fixture/task')))
        for output in ('', 'AssertionError', 'fixture-verification-ok:--ci'):
            self.assertFalse(verified_native_check({**command, 'output': output}, '--challenge', Path('/fixture/task')))
        self.assertFalse(verified_native_check(command, '--challenge', Path('/fixture/other')))
        self.assertFalse(verified_native_check({**command, 'command': "python3 verify.py --challenge\necho fixture-verification-ok:--challenge"}, '--challenge', Path('/fixture/task')))
        records[2]['payload']['call_id'] = 'unrelated'
        self.assertEqual(native_commands(records), [])

    def test_spawn_identity_requires_matching_native_result(self):
        child = '12345678-1234-1234-1234-123456789abc'
        records = [
            {'type': 'response_item', 'payload': {'type': 'function_call', 'name': 'spawn_agent', 'call_id': 'spawn', 'arguments': '{"agent_type":"tester"}'}},
            {'type': 'response_item', 'payload': {'type': 'function_call_output', 'call_id': 'spawn', 'output': json.dumps({'agent_id': child})}},
        ]
        self.assertEqual(spawned_testers(records), [child])
        records[1]['payload']['call_id'] = 'different-call'
        self.assertEqual(spawned_testers(records), [])
        with tempfile.TemporaryDirectory() as temporary:
            sessions = Path(temporary)
            day = sessions / '2026/09/16'
            day.mkdir(parents=True)
            (day / 'unrelated.jsonl').write_text('not json and must never be read')
            owned = day / f'rollout-fixture-{child}.jsonl'
            owned.write_text(json.dumps({'type': 'session_meta', 'payload': {'id': child}}))
            self.assertEqual(rollout_for(child, sessions, ['2026/09/16']), owned)



def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--self-test', action='store_true')
    parser.add_argument('--live', action='store_true')
    parser.add_argument('--case', choices=CASES, action='append')
    parser.add_argument('--artifact-dir', type=Path)
    parser.add_argument('--source-root', type=Path, default=ROOT)
    parser.add_argument('--timeout', type=int, default=300)
    args = parser.parse_args()
    if args.self_test:
        return 0 if unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Tests)).wasSuccessful() else 1
    if not args.live or not 1 <= args.timeout <= 600:
        parser.error('use --self-test or --live with timeout 1..600')
    artifacts = (args.artifact_dir or Path(tempfile.mkdtemp(prefix='delivery-evidence-'))).resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    cases = args.case or list(CASES)
    if len(set(cases)) != len(cases) or any((artifacts / case).exists() for case in cases) or (artifacts / 'summary.json').exists():
        parser.error('use unique cases and fresh evidence paths')
    source = args.source_root.resolve()
    digest = hashlib.sha256(Path(__file__).read_bytes() + (source / 'templates/global/AGENTS.md').read_bytes() + b''.join(p.read_bytes() for p in sorted((source / '.codex/agents').glob('*.toml')))).hexdigest()
    results = [run_case(case, source, artifacts, args.timeout) for case in cases]
    summary = {'sourceDigest': digest, 'scope': 'disposable native delivery fixtures; no external delivery acceptance', 'results': results}
    (artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    return 0 if all(result['status'] == 'passed' for result in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
