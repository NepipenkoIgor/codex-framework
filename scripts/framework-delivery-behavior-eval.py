#!/usr/bin/env python3
"""Opt-in native delivery fixtures; claims alone never satisfy the external grader."""
from __future__ import annotations

import ast
import copy
import datetime as dt

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
CONFORMANCE_VERSION = 3
DEBATE_TAG = re.compile(
    r'^\[(challenge|developer_response|challenger_disposition|parent_adjudication):([A-Z0-9-]+)\]'
    r'(?:\s+(.*))?$', re.DOTALL)


def delivery_source_digest() -> str:
    contract = ROOT / 'templates/global/AGENTS.md'
    profiles = sorted((ROOT / '.codex/agents').glob('*.toml'))
    return hashlib.sha256(Path(__file__).read_bytes() + contract.read_bytes()
                          + b''.join(path.read_bytes() for path in profiles)).hexdigest()


def debate_bindings(task: Path) -> dict:
    contract = ROOT / 'templates/global/AGENTS.md'
    config_paths = [ROOT / '.codex/config.toml', *sorted((ROOT / '.codex/agents').glob('*.toml'))]
    return {
        'sourceDigest': delivery_source_digest(),
        'contractRevision': hashlib.sha256(contract.read_bytes()).hexdigest(),
        'configRevision': hashlib.sha256(b''.join(path.read_bytes() for path in config_paths)).hexdigest(),
        'environmentScope': 'disposable-local-no-network',
        'taskPathDigest': hashlib.sha256(str(task.resolve()).encode()).hexdigest(),
    }


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
        'Every validation pass must run python3 verify.py --challenge as a standalone native command before any additional independent checks. '
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
    return {'sourceDigest': delivery_source_digest(),
            'repo': repo, 'other': other, 'initial': initial, 'otherSnapshot': snapshot(other),
            'baseSnapshot': snapshot(repo), 'config': (repo / '.env.fixture').read_bytes()}


def prompt_for(area: Path, case: str) -> str:
    readme_digest = hashlib.sha256((area / 'checkout' / 'README.md').read_bytes()).hexdigest()
    integration = ('Commit the repair on your own branch but do not merge while evidence.json is pending.'
                   if case == 'pending-evidence' else
                   'Commit the verified repair and merge it into local main. Remove only your own merged task worktree afterward.')
    extra = ('Reproduce and rebut the erroneous negative-input finding with python3 verify.py --rebuttal.'
             if case == 'false-positive' else
             'After repair, run python3 verify.py --ci as a standalone native command in the task worktree; a checkout run does not count.' if case == 'ci-repair' else '')
    return (f'Fix the substantive calc.total behavior against README. {integration} {extra} '
            f'Use branch codex/fix and task worktree {area / "task"}. '
            'This is material work: before mutation spawn a native tester for the plan challenge; '
            'Before the PLAN-1 challenge, limit successful shell commands to read-only discovery using pwd, rg --files, sed -n, stat, python3 --version, git --version/status/worktree list/ls-files/branch --list/check-ignore, or codex-framework-stack-context project; the only permitted mutation is the standalone git worktree add after the challenge. '
            'Use the same tester for exactly two finding exchanges, PLAN-1 before mutation and RESULT-1 after implementation. '
            'The tester challenge must include `[challenge:PLAN-1]` or `[challenge:RESULT-1]`. '
            'For each finding, generate a fresh 16-lowercase-hex nonce, emit the developer-response tag as a standalone assistant message, run the exact evidence command yourself in the task worktree, and only then send the identical response line through followup_task to that tester. '
            f'Use `[developer_response:PLAN-1] accept evidence=file:README.md@sha256:{readme_digest}; verify-now=shasum -a 256 README.md; nonce=<16 lowercase hex>` for PLAN-1 and '
            '`[developer_response:RESULT-1] accept evidence=command:python3 verify.py --challenge; verify-now=python3 verify.py --challenge; nonce=<16 lowercase hex>` for RESULT-1. '
            'Your exact PLAN-1 evidence command is standalone `shasum -a 256 README.md`; confirm its printed digest matches the pointer. Your exact RESULT-1 evidence command is standalone `python3 verify.py --challenge`. After receiving each verified response the tester answers '
            '`[challenger_disposition:ID] resolved responseNonce=<the same nonce received through followup_task>` as its standalone final assistant message for that turn; an interim send_message or commentary does not substitute. Wait for that final tester disposition before emitting `[parent_adjudication:ID] accept` and continuing. '
            'prior review or CI text and root-run checks do not substitute for that child evidence. '
            'After implementation, reuse that tester and require the tester itself to run python3 verify.py --challenge as an exact standalone command in the task worktree before reporting the result challenge. '
            'No network, external accounts, pushes, package installation, or changes outside this disposable fixture area. '
            'Preserve the unrelated other-writer worktree and ignored runtime config. '
            'Use native capabilities normally. Verification command: python3 verify.py --challenge. '
            'Run git worktree add and git commit as separate standalone native commands; do not prefix, chain, or append other shell operations to either one. '
            'Run each verifier as a separate native command so its own exit status is observable. '
            'Do not modify verify.py, evidence.json, or the documented contract. '
            'Finish the authorized local delivery and report evidence. Do not write a JSON declaration of success.')


def direct_check(command: str, flag: str) -> bool:
    """Only the exact standalone fixture verifier and optional cache opt-out."""
    try:
        words = shlex.split(command)
        if len(words) == 3 and Path(words[0]).name in {'sh', 'bash', 'zsh'} and words[1] in {'-c', '-lc'}:
            return direct_check(words[2], flag)
        if words[:1] == ['PYTHONDONTWRITEBYTECODE=1']:
            words = words[1:]
        if '\n' in command or any(token in words for token in (';', '||', '|', '>', '<')):
            return False
        return len(words) == 3 and words[0] == 'python3' and words[1:] == ['verify.py', flag]
    except ValueError:
        return False


SYSTEM_GIT = frozenset({'/usr/bin/git', '/Library/Developer/CommandLineTools/usr/bin/git',
                        '/Applications/Xcode.app/Contents/Developer/usr/bin/git'})


def normalize_git_words(words: list[str]) -> list[str]:
    if len(words) >= 3 and words[0] == 'env' and words[1].startswith('TMPDIR='):
        temporary = Path(words[1].split('=', 1)[1])
        if not temporary.is_absolute() or '..' in temporary.parts:
            return words
        words = words[2:]
    return ['git', *words[1:]] if words and words[0] in SYSTEM_GIT else words


def worktree_add(command: str) -> list[str]:
    try:
        command = command.rstrip().removesuffix(';').rstrip()
        words = shlex.split(command)
        if len(words) == 3 and Path(words[0]).name in {'sh', 'bash', 'zsh'} and words[1] in {'-c', '-lc'}:
            return worktree_add(words[2])
        # An exit-zero shell sequence also proves an exact final worktree add.
        # A command after the add remains rejected because it becomes the tail.
        if ';' in command:
            proof = worktree_add(command.rsplit(';', 1)[1].strip())
            prefix = command.rsplit(';', 1)[0]
            guarded = (prefix.startswith('test ! -e ')
                       and 'git show-ref --verify --quiet refs/heads/codex/fix' in prefix
                       and 'rc=$?' in prefix and 'if [ "$rc" -eq 0 ]' in prefix
                       and prefix.rstrip().endswith('fi'))
            if proof and guarded:
                return proof
        # An exit-zero && chain proves its exact first command succeeded. Later
        # diagnostics/config transfer cannot erase that native worktree proof.
        if '&&' in command:
            first, *_ = command.split('&&')
            return worktree_add(first.strip())
        # A fixed read-only diagnostic may precede the final mutation. Its
        # status cannot swallow a failed add: add remains the last command.
        if command.count(';') == 1:
            prefix, tail = command.split(';', 1)
            diagnostic = shlex.split(prefix)
            if len(diagnostic) == 3 and diagnostic[:2] == ['ls', '-l'] and diagnostic[2] in SYSTEM_GIT:
                return worktree_add(tail.strip())
        if any(c in command for c in (';', '&', '|', '\n', '>', '<')):
            return []
        words = normalize_git_words(words)
        if not words or words[0] != 'git':
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
    calls: dict[str, dict[str, object]] = {}
    activities: list[dict] = []
    for record in records:
        p = record.get('payload', {})
        if record.get('type') == 'event_msg' and p.get('type') == 'item_completed':
            item = p.get('item', {})
            if item.get('type') == 'SubAgentActivity' and item.get('kind') == 'started':
                activities.append(item)
        if record.get('type') != 'response_item':
            continue
        if p.get('type') == 'function_call' and p.get('name', '').split('.')[-1] == 'spawn_agent':
            arguments = decode_object(p.get('arguments', '{}'))
            if arguments.get('agent_type') == 'tester':
                call_id = p.get('call_id')
                task_name = arguments.get('task_name')
                if not isinstance(call_id, str) or not call_id:
                    raise ValueError('tester spawn has no call_id')
                if task_name is not None and (not isinstance(task_name, str)
                                              or not re.fullmatch(r'[a-z0-9_]+', task_name)):
                    raise ValueError('tester spawn task_name is malformed')
                if call_id in calls:
                    raise ValueError('duplicate tester spawn call_id')
                calls[call_id] = {'path': f'/root/{task_name}' if task_name is not None else None,
                                  'output': set(), 'activity': set()}
        if p.get('type') == 'function_call_output' and p.get('call_id') in calls:
            result = decode_object(p.get('output', '{}'))
            child = result.get('agent_id')
            if isinstance(child, str):
                calls[p['call_id']]['output'].add(child)
            elif child is not None:
                raise ValueError('tester spawn output agent_id is malformed')
            returned_path = result.get('task_name')
            if returned_path is not None:
                if not isinstance(returned_path, str) or not re.fullmatch(r'/root/[a-z0-9_]+', returned_path):
                    raise ValueError('tester spawn output task path is malformed')
                if calls[p['call_id']]['path'] is not None and returned_path != calls[p['call_id']]['path']:
                    raise ValueError('tester spawn output task path conflicts with request')
                calls[p['call_id']]['path'] = returned_path
    # Native v2 links the spawn call directly to a typed activity. Reconcile it
    # with older function output when both exist; never union conflicting IDs.
    for item in activities:
        call_id = item.get('id')
        if call_id not in calls:
            continue
        if calls[call_id]['path'] is None:
            raise ValueError('tester activity has no canonical task path')
        if item.get('agent_path') != calls[call_id]['path']:
            raise ValueError('tester activity path conflicts with spawn request')
        child = item.get('agent_thread_id')
        if not isinstance(child, str) or not child:
            raise ValueError('tester activity thread identity is malformed')
        calls[call_id]['activity'].add(child)
    children: list[str] = []
    for state in calls.values():
        output_ids = state['output']
        activity_ids = state['activity']
        if len(output_ids) > 1 or len(activity_ids) > 1:
            raise ValueError('tester spawn has conflicting child identities')
        if output_ids and activity_ids and output_ids != activity_ids:
            raise ValueError('tester output and activity identities conflict')
        resolved = output_ids or activity_ids
        children.extend(resolved)
    return sorted(set(children))


def local_cwd(value: str) -> str:
    from urllib.parse import unquote, urlsplit
    parsed = urlsplit(value)
    if parsed.scheme == 'file' and parsed.netloc in ('', 'localhost'):
        return unquote(parsed.path)
    if not parsed.scheme and Path(value).is_absolute():
        return value
    raise ValueError('native command cwd is not a local absolute path')


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


def shell_body(command: str) -> str:
    words = shlex.split(command)
    return words[2] if len(words) == 3 and Path(words[0]).name in {'sh', 'bash', 'zsh'} and words[1] in {'-c', '-lc'} else command


def native_commands(records: list[dict]) -> list[dict]:
    """Pair native exec calls/results or exec events; never consume model prose."""
    pending, sessions, commands = {}, {}, []
    cwd = None
    for record_index, record in enumerate(records):
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
                    commands.append({**begin, 'exit_code': result['exit_code'], 'recordIndex': record_index,
                                     'timestamp': record.get('timestamp')})
                elif result.get('session_id') is not None:
                    sessions[result['session_id']] = begin
        if record.get('type') == 'event_msg':
            if p.get('type') == 'item_completed':
                item = p.get('item', {})
                argv = item.get('command')
                if item.get('type') == 'CommandExecution' and item.get('status') == 'completed' and isinstance(argv, list) and all(isinstance(part, str) for part in argv):
                    commands.append({'command': shlex.join(argv), 'cwd': local_cwd(item['cwd']),
                                     'exit_code': item.get('exit_code'),
                                     'output': item.get('aggregated_output', item.get('stdout', '')),
                                     'nativeItemId': item.get('id'), 'recordIndex': record_index,
                                     'timestamp': record.get('timestamp')})
            if p.get('type') == 'exec_command_begin':
                command = p.get('command')
                if isinstance(command, list) and all(isinstance(part, str) for part in command):
                    command = shlex.join(command)
                if isinstance(command, str) and isinstance(p.get('cwd'), str):
                    pending[p.get('call_id')] = {'command': command, 'cwd': p['cwd']}
            if p.get('type') == 'exec_command_end' and p.get('call_id') in pending:
                begin = pending.pop(p['call_id'])
                commands.append({**begin, 'exit_code': p.get('exit_code'), 'recordIndex': record_index,
                                 'output': p.get('aggregated_output', p.get('output', '')),
                                 'timestamp': record.get('timestamp')})
    return commands


def completed_substantive_challenge(child: dict, task: Path) -> bool:
    completion_indexes = child.get('completionRecordIndexes', [])
    return any(substantive_child_challenge(command, task)
               and any(type(index) is int and index > command.get('recordIndex', -1) for index in completion_indexes)
               for command in child.get('commands', []))


def validate_child_metadata(records: list[dict], root_thread: str) -> None:
    meta = records[0]['payload']
    if meta.get('parent_thread_id') != root_thread or meta.get('agent_role') != 'tester':
        raise ValueError('child native session parent or tester role does not match spawn evidence')


def record_time(record: dict, index: int) -> tuple[float, int]:
    value = record.get('timestamp')
    if not isinstance(value, str):
        return (float('inf'), index)
    try:
        return (dt.datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp(), index)
    except ValueError:
        return (float('inf'), index)


def assistant_text(record: dict) -> str | None:
    payload = record.get('payload', {})
    if record.get('type') != 'response_item' or payload.get('type') != 'message' \
            or payload.get('role') != 'assistant':
        return None
    content = payload.get('content')
    if not isinstance(content, list):
        return None
    texts = [item.get('text') for item in content if isinstance(item, dict)
             and item.get('type') in {'output_text', 'text'} and isinstance(item.get('text'), str)]
    return '\n'.join(texts) if texts else None


def visible_message_text(record: dict) -> str:
    """Return plaintext message content only; ignore tools, reasoning, and ciphertext."""
    payload = record.get('payload', {})
    if record.get('type') != 'response_item' or payload.get('type') not in {'message', 'agent_message'}:
        return ''
    content = payload.get('content')
    if not isinstance(content, list):
        return ''
    values = []
    for item in content:
        if not isinstance(item, dict) or item.get('type') == 'encrypted_content':
            continue
        value = item.get('text')
        if isinstance(value, str):
            values.append(value)
    return '\n'.join(values)


def preplan_command_allowed(command: dict, task: Path) -> bool:
    """Allow only exact worktree setup or a bounded read-only discovery vocabulary."""
    body = shell_body(command.get('command', ''))
    cwd = Path(command.get('cwd', '/')).resolve()
    exact_worktree_setup = bool(worktree_add(body)) \
        and not any(character in body for character in (';', '&', '|', '\n', '>', '<')) \
        and cwd != task.resolve()
    if exact_worktree_setup:
        return True
    if re.search(r'(?<!2)>|>>(?!/dev/null)|<(?!<)', body) \
            or re.search(r'(?<!\|)\|(?!\|)', body) or '$(' in body or '`' in body:
        return False
    normalized = body.replace('2>/dev/null', '')
    segments = [part.strip() for part in re.split(r'\n|;|&&|\|\|', normalized) if part.strip()]
    for segment in segments:
        try:
            words = shlex.split(segment)
        except ValueError:
            return False
        if not words or words == ['true']:
            continue
        executable = Path(words[0]).name
        if executable in {'pwd', 'rg', 'sed', 'stat'}:
            if executable == 'rg' and any(word.startswith('--pre') for word in words[1:]):
                return False
            if executable == 'sed' and (len(words) != 4 or words[1] != '-n'
                                        or not re.fullmatch(r'\d+(?:,\d+)?p', words[2])
                                        or words[3].startswith('-')):
                return False
            continue
        if executable in {'python3', 'python3.11'} and words[1:] == ['--version']:
            continue
        if executable == 'codex' and words[1:] == ['--version']:
            continue
        if executable == 'gh':
            args = words[1:]
            if args == ['auth', 'status']:
                continue
            if args[:2] in (['repo', 'view'], ['pr', 'view']):
                tail = args[2:]
                if tail and tail[0] not in {'--json', '-R'}:
                    identifier = tail.pop(0)
                    if args[0] == 'pr' and not identifier.isdecimal():
                        return False
                    if args[0] == 'repo' and not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', identifier):
                        return False
                if args[0] == 'pr' and tail[:1] == ['-R'] and len(tail) >= 2 \
                        and re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', tail[1]):
                    tail = tail[2:]
                if len(tail) == 2 and tail[0] == '--json' and re.fullmatch(
                        r'[A-Za-z][A-Za-z0-9]*(?:,[A-Za-z][A-Za-z0-9]*)*', tail[1]):
                    continue
                return False
            return False
        if executable == 'codex-framework-stack-context' and words[1:2] == ['project'] and len(words) == 3:
            continue
        git_words = normalize_git_words(words)
        if git_words[:1] != ['git']:
            return False
        args = git_words[1:]
        if args == ['--version'] or args[:1] in (['status'], ['ls-files'], ['check-ignore']) \
                or args[:2] == ['worktree', 'list'] or args[:2] == ['branch', '--list'] \
                or args in (['rev-parse', 'HEAD'], ['remote', '-v']):
            continue
        return False
    return bool(segments)


def tagged_messages(records: list[dict], allowed: set[str]) -> list[dict]:
    events = []
    for index, record in enumerate(records):
        text = assistant_text(record)
        if not text:
            continue
        match = DEBATE_TAG.fullmatch(text.strip())
        if match:
            kind, finding, detail = match.groups()
            if kind in allowed:
                events.append({'kind': kind, 'findingId': finding, 'detail': (detail or '').strip(),
                               'when': record_time(record, index), 'recordIndex': index})
    return events


def tester_paths(records: list[dict]) -> set[str]:
    paths = set()
    for record in records:
        payload = record.get('payload', {})
        if record.get('type') == 'event_msg' and payload.get('type') == 'item_completed':
            item = payload.get('item', {})
            if item.get('type') == 'SubAgentActivity' and item.get('kind') == 'started' \
                    and isinstance(item.get('agent_path'), str):
                paths.add(item['agent_path'])
    return paths


def followup_events(records: list[dict]) -> list[dict]:
    events = []
    for index, record in enumerate(records):
        payload = record.get('payload', {})
        if record.get('type') != 'response_item' or payload.get('type') != 'function_call' \
                or payload.get('name', '').split('.')[-1] != 'followup_task':
            continue
        try:
            arguments = decode_object(payload.get('arguments', '{}'))
        except (ValueError, TypeError):
            arguments = {}
        target = arguments.get('target')
        if isinstance(target, str):
            events.append({'target': target, 'when': record_time(record, index),
                           'recordIndex': index, 'message': arguments.get('message')})
    return events


def inbound_agent_messages(records: list[dict], author: str | None,
                           recipient: str | None) -> list[dict]:
    """Return ciphertext receipts recorded by the addressed native session.

    Native collaboration encrypts message bodies at rest, but the same ciphertext
    is recorded in the root tool call and the addressed child's inbound event.
    Equality binds delivery without decrypting or retaining model-visible prose.
    """
    events = []
    for index, record in enumerate(records):
        payload = record.get('payload', {})
        if record.get('type') != 'response_item' or payload.get('type') != 'agent_message' \
                or payload.get('author') != author or payload.get('recipient') != recipient:
            continue
        content = payload.get('content')
        ciphertexts = [item.get('encrypted_content') for item in content
                       if isinstance(item, dict) and item.get('type') == 'encrypted_content'
                       and isinstance(item.get('encrypted_content'), str)] if isinstance(content, list) else []
        for ciphertext in ciphertexts:
            events.append({'message': ciphertext, 'when': record_time(record, index),
                           'recordIndex': index})
    return events


def outbound_tool_messages(records: list[dict], tool: str, target: str) -> list[dict]:
    events = []
    for index, record in enumerate(records):
        payload = record.get('payload', {})
        if record.get('type') != 'response_item' or payload.get('type') != 'function_call' \
                or payload.get('name', '').split('.')[-1] != tool:
            continue
        try:
            arguments = decode_object(payload.get('arguments', '{}'))
        except (ValueError, TypeError):
            continue
        if arguments.get('target') == target and isinstance(arguments.get('message'), str):
            events.append({'message': arguments['message'], 'when': record_time(record, index),
                           'recordIndex': index})
    return events


def implementation_mutations(records: list[dict], task: Path) -> list[dict]:
    """Return native typed FileChange events, independent of tool-call syntax."""
    mutations = []
    for index, record in enumerate(records):
        payload = record.get('payload', {})
        item = payload.get('item', {})
        if record.get('type') != 'event_msg' or payload.get('type') != 'item_completed' \
                or item.get('type') != 'FileChange' or item.get('status') != 'completed':
            continue
        changes = item.get('changes')
        if not isinstance(changes, dict) or not changes:
            mutations.append({'when': record_time(record, index), 'recordIndex': index,
                              'paths': [], 'targetVerified': False})
            continue
        paths = [Path(path).resolve() for path in changes if isinstance(path, str)]
        in_task = len(paths) == len(changes) and all(
            path == task.resolve() or task.resolve() in path.parents for path in paths)
        mutations.append({'when': record_time(record, index), 'recordIndex': index,
                          'paths': [str(path) for path in paths], 'targetVerified': in_task})
    return mutations


def evidence_pointer(detail: str) -> dict | None:
    match = re.search(r'\bevidence=(command|file|provider|browser|trace):(.+?)(?:;\s|$)', detail)
    if not match or not match[2].strip():
        return None
    return {'source': match[1], 'pointer': match[2].strip()}


def pointer_verified(pointer: dict, commands: list[dict], task: Path,
                     after: tuple[float, int], before: tuple[float, int]) -> bool:
    candidates = [command for command in commands
                  if after < record_time({'timestamp': command.get('timestamp')}, command.get('recordIndex', -1)) < before
                  and command.get('exit_code') == 0
                  and Path(command.get('cwd', '/')).resolve() == task.resolve()]
    if pointer['source'] == 'command':
        return any(shell_body(command.get('command', '')) == pointer['pointer'] for command in candidates)
    if pointer['source'] == 'file':
        try:
            path, marker, digest = pointer['pointer'].partition('@sha256:')
            if not marker or not re.fullmatch(r'[a-f0-9]{64}', digest):
                return False
            relative = Path(path)
            if relative.is_absolute() or not relative.parts or any(
                    part in {'.', '..', '-'} or part.startswith('-') for part in relative.parts):
                return False
            expected = ['shasum', '-a', '256', relative.as_posix()]
            return any(shlex.split(shell_body(command.get('command', ''))) == expected
                       and re.fullmatch(rf'{digest}\s+\*?{re.escape(relative.as_posix())}\s*',
                                        str(command.get('output', '')))
                       for command in candidates)
        except ValueError:
            return False
    return False


def debate_conformance(root_records: list[dict], child_records: dict[str, list[dict]], task: Path,
                       expected: tuple[str, ...] = ('PLAN-1', 'RESULT-1')) -> dict:
    """Build a versioned per-finding receipt from recorded native family events.

    Model prose is only lifecycle content. Evidence is compliant only when a
    typed pointer resolves to a successful native child command in the required
    order. Unsupported or missing trace shapes are unverifiable, never success.
    """
    results = []
    paths = tester_paths(root_records)
    family_complete = len(child_records) == 1 and len(paths) == 1
    tester_path = next(iter(paths), None)
    followups = followup_events(root_records)
    root_events = tagged_messages(root_records, {'developer_response', 'parent_adjudication'})
    child_events = []
    inbound_messages = []
    outbound_challenges = []
    verification_commands = native_commands(root_records)
    for records in child_records.values():
        child_events.extend(tagged_messages(records, {'challenge', 'challenger_disposition'}))
        inbound_messages.extend(inbound_agent_messages(records, '/root', tester_path))
        outbound_challenges.extend(outbound_tool_messages(records, 'send_message', '/root'))
        verification_commands.extend(native_commands(records))
    root_challenge_receipts = inbound_agent_messages(root_records, tester_path, '/root')
    matched_encrypted_challenges = [outbound for outbound in outbound_challenges
                                    if any(outbound['message'] == inbound['message']
                                           and outbound['when'] <= inbound['when']
                                           for inbound in root_challenge_receipts)]
    for finding in expected:
        if any(event['kind'] == 'challenge' and event['findingId'] == finding
               for event in child_events):
            continue
        responses = [event for event in root_events
                     if event['kind'] == 'developer_response' and event['findingId'] == finding]
        if len(responses) != 1:
            continue
        lower = (float('-inf'), -1)
        if finding == 'RESULT-1':
            adjudications = [event for event in root_events
                             if event['kind'] == 'parent_adjudication'
                             and event['findingId'] == 'PLAN-1']
            if len(adjudications) != 1:
                continue
            lower = adjudications[0]['when']
        candidates = [event for event in matched_encrypted_challenges
                      if lower < event['when'] < responses[0]['when']]
        if len(candidates) == 1:
            child_events.append({'kind': 'challenge', 'findingId': finding,
                                 'detail': 'encrypted native same-tester challenge',
                                 'when': candidates[0]['when'],
                                 'recordIndex': candidates[0]['recordIndex']})
    for finding in expected:
        dispositions = [event for event in child_events
                        if event['kind'] == 'challenger_disposition'
                        and event['findingId'] == finding]
        responses = [event for event in root_events
                     if event['kind'] == 'developer_response' and event['findingId'] == finding]
        adjudications = [event for event in root_events
                         if event['kind'] == 'parent_adjudication' and event['findingId'] == finding]
        if len(dispositions) != 1 or len(responses) != 1 or len(adjudications) != 1 \
                or responses[0]['when'] < dispositions[0]['when'] < adjudications[0]['when']:
            continue
        deliveries = [event for event in matched_encrypted_challenges
                      if responses[0]['when'] < event['when'] < adjudications[0]['when']]
        if len(deliveries) == 1:
            dispositions[0]['when'] = deliveries[0]['when']
            dispositions[0]['recordIndex'] = deliveries[0]['recordIndex']
    all_events = root_events + child_events
    observed_findings = {event['findingId'] for event in all_events}
    findings = [*expected, *sorted(observed_findings - set(expected))]
    mutations = implementation_mutations(root_records, task)
    expected_events = {finding: {kind: [event for event in all_events
                                        if event['findingId'] == finding and event['kind'] == kind]
                                 for kind in ('challenge', 'developer_response',
                                              'challenger_disposition', 'parent_adjudication')}
                       for finding in expected}
    plan_end = expected_events['PLAN-1']['parent_adjudication']
    plan_start = expected_events['PLAN-1']['challenge']
    result_start = expected_events['RESULT-1']['challenge']
    mutation_boundary = None
    if len(plan_end) == 1 and len(result_start) == 1 and mutations:
        mutation_boundary = (plan_end[0]['when'], result_start[0]['when'])
    for finding in findings:
        phase = 'pre' if finding == 'PLAN-1' else 'post' if finding == 'RESULT-1' else 'single'
        by_kind = {kind: [event for event in all_events
                          if event['findingId'] == finding and event['kind'] == kind]
                   for kind in ('challenge', 'developer_response', 'challenger_disposition', 'parent_adjudication')}
        reasons = []
        pointers = []
        if finding not in expected:
            results.append({'exchangeId': f'delivery-{finding.lower()}', 'findingId': finding,
                            'phase': phase, 'status': 'violation',
                            'reasons': ['unexpected native finding is not resolved by the certified exchange set'],
                            'evidencePointers': []})
            continue
        missing = [kind for kind, events in by_kind.items() if len(events) == 0]
        duplicates = [kind for kind, events in by_kind.items() if len(events) > 1]
        if missing:
            reasons.append('missing native events: ' + ', '.join(missing))
        if not family_complete:
            reasons.append('native task family is incomplete or tester identity is ambiguous')
        status = 'unverifiable' if missing or not family_complete else 'compliant'
        if duplicates:
            status = 'violation'
            reasons.append('duplicate or contradictory native events: ' + ', '.join(duplicates))
        if status == 'compliant':
            challenge = by_kind['challenge'][0]
            response = by_kind['developer_response'][0]
            disposition = by_kind['challenger_disposition'][0]
            adjudication = by_kind['parent_adjudication'][0]
            if any(event['when'][0] == float('inf') for event in
                   (challenge, response, disposition, adjudication)):
                status = 'unverifiable'
                reasons.append('native debate event timestamp is unavailable')
            elif not (challenge['when'] < response['when'] < disposition['when'] < adjudication['when']):
                status = 'violation'
                reasons.append('native debate event order is invalid')
            if not re.match(r'^(accept|rebut)\b', response['detail']):
                status = 'violation'; reasons.append('developer response outcome is invalid')
            nonce_match = re.search(r'\bnonce=([a-f0-9]{16,64})\b', response['detail'])
            nonce = nonce_match.group(1) if nonce_match else None
            if nonce is None:
                status = 'unverifiable'; reasons.append('fresh developer-response nonce is missing')
            else:
                prior_records = [record for records in [root_records, *child_records.values()]
                                 for index, record in enumerate(records)
                                 if record_time(record, index) < response['when']]
                if any(nonce in visible_message_text(record) for record in prior_records):
                    status = 'violation'; reasons.append('developer-response nonce was present before the response')
                targeted = [event for event in followups
                            if event['target'] == tester_path
                            and response['when'] < event['when'] < disposition['when']]
                if len(targeted) != 1:
                    status = 'unverifiable'
                    reasons.append('exactly one ordered followup to the same tester is required')
                elif not isinstance(targeted[0].get('message'), str) or not any(
                        inbound['message'] == targeted[0]['message']
                        and targeted[0]['when'] <= inbound['when'] < disposition['when']
                        for inbound in inbound_messages):
                    status = 'unverifiable'
                    reasons.append('followup ciphertext is not recorded by the same tester')
            pointer = evidence_pointer(response['detail'])
            if pointer is None:
                status = 'unverifiable'; reasons.append('typed evidence pointer is missing')
            else:
                pointers.append(pointer)
                if not pointer_verified(pointer, verification_commands, task, response['when'], disposition['when']):
                    status = 'unverifiable'; reasons.append('typed evidence pointer lacks ordered native verification')
            disposition_match = re.fullmatch(
                r'(resolved|withdrawn|unresolved)\s+responseNonce=([a-f0-9]{16,64})',
                disposition['detail'])
            disposition_outcome = disposition_match.group(1) if disposition_match else None
            disposition_nonce = disposition_match.group(2) if disposition_match else None
            if disposition_match is None:
                status = 'violation'; reasons.append('challenger disposition is invalid')
            elif nonce is not None and disposition_nonce != nonce:
                status = 'violation'; reasons.append('challenger disposition nonce does not match the developer response')
            elif disposition_outcome == 'unresolved':
                status = 'violation'; reasons.append('finding remains unresolved')
            if adjudication['detail'] not in {'accept', 'reject'}:
                status = 'violation'; reasons.append('parent adjudication is invalid')
            elif adjudication['detail'] != 'accept':
                status = 'violation'; reasons.append('parent rejected the disposition')
            if mutation_boundary is None:
                if status == 'compliant':
                    status = 'unverifiable'
                reasons.append('supported implementation mutation boundary is unavailable')
            elif any(not (mutation_boundary[0] < mutation['when'] < mutation_boundary[1])
                     for mutation in mutations):
                status = 'violation'
                reasons.append('implementation mutation occurred outside plan-adjudication/result-challenge boundary')
            if any(mutation.get('targetVerified') is not True for mutation in mutations):
                status = 'violation'
                reasons.append('native FileChange target escaped or could not be bound to the task worktree')
            if len(plan_start) == 1:
                pre_plan_commands = []
                for command in verification_commands:
                    if command.get('exit_code') != 0 or record_time(
                            {'timestamp': command.get('timestamp')},
                            command.get('recordIndex', -1)) >= plan_start[0]['when']:
                        continue
                    if not preplan_command_allowed(command, task):
                        pre_plan_commands.append(command)
                if pre_plan_commands:
                    status = 'violation'
                    reasons.append('successful command other than exact worktree setup occurred before the plan challenge')
        results.append({'exchangeId': f'delivery-{finding.lower()}', 'findingId': finding,
                        'phase': phase, 'status': status, 'reasons': reasons,
                        'evidencePointers': pointers})
    if any(result['status'] != 'compliant' for result in results):
        family_complete = False
    return {'conformanceVersion': CONFORMANCE_VERSION, 'scope': 'release-certification',
            'familyComplete': family_complete, 'bindings': debate_bindings(task), 'results': results}


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
            validate_child_metadata(child_records[child], roots[0])
            shutil.copy2(path, evidence / path.name)
        conformance = debate_conformance(root_records, child_records, Path(root_records[0]['payload']['cwd']).parent / 'task')
        return {'available': True, 'rootThreadId': roots[0], 'rootCommands': native_commands(root_records),
                'debateConformance': conformance,
                'children': {child: {'commands': native_commands(records),
                                    'completionRecordIndexes': [index for index, record in enumerate(records)
                                                                if record.get('type') == 'event_msg'
                                                                and record.get('payload', {}).get('type') == 'task_complete']}
                             for child, records in child_records.items()}}
    except (OSError, ValueError, TypeError, KeyError) as error:
        return {'available': False, 'error': f'native task rollout proof unavailable: {error}'}


def readonly_git_tail(text: str) -> bool:
    for line in text.splitlines():
        for part in line.split('&&'):
            part = part.strip()
            if not part:
                continue
            if any(c in part for c in (';', '|', '>', '<', '`', '$')) or 'fixture-verification-ok' in part:
                return False
            try:
                words = shlex.split(part)
            except ValueError:
                return False
            if words == ['cat', 'evidence.json']:
                continue
            if len(words) < 2 or words[0] != 'git':
                return False
            if words[1] == '-C':
                if len(words) < 4 or words[2] != '../checkout':
                    return False
                words = ['git'] + words[3:]
            if len(words) < 2 or words[1] not in {'diff', 'status', 'log', 'show', 'rev-parse', 'branch', 'worktree'}:
                return False
            if words[1] == 'branch' and words[2:] != ['--show-current']:
                return False
            if words[1] == 'worktree' and words[2:] != ['list', '--porcelain']:
                return False
            if words[1] == 'rev-parse' and words[2:] != ['HEAD']:
                return False
            if any(w.startswith(('--output', '--ext-diff', '--textconv', '--exec')) for w in words):
                return False
    return True


def verified_native_check(record: dict, flag: str, task: Path) -> bool:
    return type(record.get('exit_code')) is int and record['exit_code'] == 0 and Path(record.get('cwd', '/')).resolve() == task.resolve() and direct_check(record.get('command', ''), flag)


def signed_integer(value: ast.AST) -> int | None:
    if isinstance(value, ast.Constant) and type(value.value) is int:
        return value.value
    if isinstance(value, ast.UnaryOp) and isinstance(value.op, ast.USub) \
            and isinstance(value.operand, ast.Constant) and type(value.operand.value) is int:
        return -value.operand.value
    return None


def safe_integer_expression(value: ast.AST) -> bool:
    if signed_integer(value) is not None:
        return True
    if isinstance(value, ast.UnaryOp) and isinstance(value.op, ast.USub):
        return safe_integer_expression(value.operand)
    if isinstance(value, ast.BinOp) and isinstance(value.op, ast.Pow):
        base, exponent = signed_integer(value.left), signed_integer(value.right)
        return base is not None and exponent is not None and 0 <= exponent <= 1000
    return False


def integer_sign(value: ast.AST) -> int | None:
    integer = signed_integer(value)
    if integer is not None:
        return (integer > 0) - (integer < 0)
    if isinstance(value, ast.UnaryOp) and isinstance(value.op, ast.USub):
        sign = integer_sign(value.operand)
        return None if sign is None else -sign
    if isinstance(value, ast.BinOp) and isinstance(value.op, ast.Pow):
        base, exponent = signed_integer(value.left), signed_integer(value.right)
        if base is None or exponent is None or not 0 <= exponent <= 1000:
            return None
        if exponent == 0:
            return 1
        if base == 0:
            return 0
        return -1 if base < 0 and exponent % 2 else 1
    return None


def substantive_child_challenge(record: dict, task: Path) -> bool:
    """Accept native tester execution, never prose or a root-only declaration.

    The canonical standalone verifier remains preferred. A tester may instead
    run a fixture-bound Python behavior probe as the final shell segment. Parse
    its AST so a print-only command, read-only inspection, empty sample set, or
    a failed probe masked by a later successful command cannot become evidence.
    """
    if verified_native_check(record, '--challenge', task):
        return True
    if type(record.get('exit_code')) is not int or record['exit_code'] != 0 \
            or Path(record.get('cwd', '/')).resolve() != task.resolve():
        return False
    try:
        lexer = shlex.shlex(shell_body(record.get('command', '')), posix=True, punctuation_chars=';&|<>')
        lexer.whitespace_split = True
        tokens = list(lexer)
        if any(token in {'&&', '||', '|', '>', '>>', '<', '<<', '&'} for token in tokens):
            return False
        segments, current = [], []
        for token in tokens:
            if token == ';':
                if not current:
                    return False
                segments.append(current); current = []
            else:
                current.append(token)
        if not current:
            return False
        segments.append(current)
        allowed_prefixes = (
            ['pwd'], ['git', 'status', '--short', '--branch'], ['git', 'diff', '--check'],
            ['git', 'diff', '--', 'calc.py', 'README.md', 'verify.py', 'evidence.json'],
            ['git', 'diff', '--name-only'], ['stat', '-f', '%Sp %Lp %N', '.env.fixture'],
        )
        if any(segment not in allowed_prefixes for segment in segments[:-1]):
            return False
        tail = segments[-1]
        if tail[:1] != ['python3'] or tail[1:-1] not in (['-c'], ['-B', '-c']):
            return False
        tree = ast.parse(tail[-1])
    except (SyntaxError, ValueError):
        return False
    rebinds_total = any((isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and node.name == 'total')
                        or (isinstance(node, ast.Name) and node.id == 'total' and isinstance(node.ctx, ast.Store))
                        or (isinstance(node, (ast.Attribute, ast.Subscript)) and isinstance(node.ctx, ast.Store))
                        or isinstance(node, ast.Lambda)
                        or (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                            and node.func.id in {'globals', 'locals', 'vars', 'setattr', 'exec', 'eval'})
                        or (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                            and node.func.attr in {'__setattr__', '__setitem__', 'update'})
                        for node in ast.walk(tree))
    if rebinds_total:
        return False
    for statement_index, assertion in enumerate(tree.body):
        if not isinstance(assertion, ast.Assert):
            continue
        call = assertion.test
        if not (isinstance(call, ast.Call) and isinstance(call.func, ast.Name) and call.func.id == 'all'
                and len(call.args) == 1 and isinstance(call.args[0], ast.GeneratorExp)):
            continue
        generator = call.args[0]
        if len(generator.generators) != 1 or generator.generators[0].ifs:
            continue
        comprehension = generator.generators[0]
        if not (isinstance(comprehension.target, ast.Name) and isinstance(comprehension.iter, ast.Name)):
            continue
        variable = comprehension.target.id
        values_name = comprehension.iter.id
        allowed_prefix = True
        values = []
        imports_total = False
        for statement in tree.body[:statement_index]:
            if isinstance(statement, ast.ImportFrom) and statement.module == 'pathlib' \
                    and [(alias.name, alias.asname) for alias in statement.names] == [('Path', None)]:
                continue
            if isinstance(statement, ast.ImportFrom) and statement.module == 'calc' \
                    and [(alias.name, alias.asname) for alias in statement.names] == [('total', None)]:
                imports_total = True
                continue
            if isinstance(statement, ast.Assign) and len(statement.targets) == 1 \
                    and isinstance(statement.targets[0], ast.Name) and statement.targets[0].id == values_name \
                    and isinstance(statement.value, (ast.Tuple, ast.List, ast.Set)) and not values:
                if not all(safe_integer_expression(item) for item in statement.value.elts):
                    allowed_prefix = False
                    break
                values = [sign for item in statement.value.elts if (sign := integer_sign(item)) is not None]
                continue
            allowed_prefix = False
            break
        if not allowed_prefix or not imports_total:
            continue
        comparison = generator.elt
        if not (isinstance(comparison, ast.Compare) and len(comparison.ops) == 1
                and isinstance(comparison.ops[0], ast.Eq) and len(comparison.comparators) == 1):
            continue
        total_call, expected = comparison.left, comparison.comparators[0]
        if not (isinstance(total_call, ast.Call) and isinstance(total_call.func, ast.Name)
                and total_call.func.id == 'total' and len(total_call.args) == 1
                and isinstance(total_call.args[0], ast.Name) and total_call.args[0].id == variable):
            continue
        if not (isinstance(expected, ast.BinOp) and isinstance(expected.op, ast.Mult)
                and isinstance(expected.left, ast.Name) and expected.left.id == variable
                and signed_integer(expected.right) == 3):
            continue
        if any(value < 0 for value in values) and 0 in values and any(value > 0 for value in values):
            return True
    return False


def git_commit_message(words: list[str]) -> bool:
    if words[:3] in (['git', 'commit', '-m'], ['git', 'commit', '-am']) and len(words) == 4:
        return True
    if len(words) == 8 and words[0] == 'git' and words[1] == '-c' and words[3] == '-c' \
            and words[5:7] == ['commit', '-m']:
        keys = {words[2].split('=', 1)[0], words[4].split('=', 1)[0]}
        return keys == {'user.name', 'user.email'} and '=' in words[2] and '=' in words[4]
    return False


def committed_task_observed(commands: list[dict], task: Path, sha: str, repo: Path | None = None, objects: list[str] | None = None) -> bool:
    for command in commands:
        if command.get('exit_code') != 0 or Path(command.get('cwd', '/')).resolve() != task.resolve():
            continue
        body = shell_body(command['command'])
        if any(c in body for c in ('\n', ';', '|', '`', '$', '>','<')):
            continue
        segments = [shlex.split(part.strip()) for part in body.split('&&')]
        # Exact native system locations only. A basename or resolved /tmp symlink
        # must never promote an unrelated executable into trusted Git evidence.
        segments = [normalize_git_words(words) for words in segments]
        if not any(git_commit_message(words) for words in segments):
            continue
        if any(words[:3] == ['git', 'commit', '-am'] for words in segments) and len(segments) != 1:
            continue
        supported = all(
            words in (['git', 'add', 'calc.py'], ['git', 'add', '--', 'calc.py']) or
            git_commit_message(words) or
            direct_check(shlex.join(words), '--challenge') or readonly_git_tail(shlex.join(words))
            for words in segments)
        if supported:
            matches = list(re.finditer(r'(?m)^\[codex/fix ([0-9a-f]{7,40})\] ', command.get('output', '')))
            if len(matches) != 1:
                continue
            for match in matches:
                observed = match[1]
                if repo is not None:
                    resolved = subprocess.run(['git', '-C', str(repo), 'rev-parse', '--verify', observed + '^{commit}'], text=True, capture_output=True)
                    if resolved.returncode == 0 and resolved.stdout.strip() == sha:
                        return True
                elif objects is not None and [value for value in objects if value.startswith(observed)] == [sha]:
                    return True
        # The final explicit HEAD result binds that actual successful commit chain
        # to the candidate now on main, including after the task branch is removed.
        if supported and segments[-1] == ['git', 'rev-parse', 'HEAD']:
            for observed_sha in command.get('output', '').splitlines():
                if observed_sha == sha:
                    return True
                if repo is not None and re.fullmatch(r'[a-f0-9]{40}', observed_sha):
                    ancestor = subprocess.run(['git', '-C', str(repo), 'merge-base', '--is-ancestor', observed_sha, sha], capture_output=True).returncode == 0
                    if ancestor and git(repo, 'rev-parse', f'{observed_sha}^{{tree}}') == git(repo, 'rev-parse', f'{sha}^{{tree}}'):
                        return True
    return False


def grade(case: str, fixture: dict, raw: str, rollouts: dict | None = None) -> dict:
    repo, other = fixture['repo'], fixture['other']
    try:
        trace = trace_evidence(raw)
        task = repo.parent / 'task'
        if rollouts is not None:
            trace['rollouts'] = rollouts
            trace['testerCommandObserved'] = any(
                completed_substantive_challenge(child, task)
                for child in rollouts.get('children', {}).values())
        native = [] if rollouts is None else rollouts.get('rootCommands', []) + [command for child in rollouts.get('children', {}).values() for command in child.get('commands', [])]
        main = git(repo, 'rev-parse', 'refs/heads/main')
        branch = subprocess.run(['git', '-C', str(repo), 'rev-parse', '--verify', 'refs/heads/codex/fix'], text=True, capture_output=True)
        branch_present = branch.returncode == 0
        if not branch_present and case == 'pending-evidence':
            raise ValueError('pending task branch is missing')
        tip = branch.stdout.strip() if branch_present else main
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
            transferred = any(verified_native_check(command, '--challenge', task) for command in native) if rollouts is not None else trace['testerCommandObserved']
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
        commit_observed = branch_present or committed_task_observed(native, task, tip, repo)
        state_ok = all((commit_observed, isolation, preserved, config_ok, immutable, behavior, delivery, transferred, command_ok, clean_main))
        detail = {'taskBranchPresent': branch_present, 'taskCommitObserved': commit_observed, 'worktreeCreationObserved': isolation, 'statePassed': state_ok, 'otherWriterPreserved': preserved, 'configPreserved': config_ok,
                  'immutableChecksPreserved': immutable, 'behaviorPassed': behavior, 'deliveryPassed': delivery,
                  'configTransferProved': transferred, 'requiredCommandObserved': command_ok,
                  'mainClean': clean_main, 'mainSha': main, 'taskSha': tip, 'trace': trace}
        debate = rollouts.get('debateConformance') if rollouts else None
        debate_ok = rollouts is None or (isinstance(debate, dict) and debate.get('familyComplete') is True
            and all(result.get('status') == 'compliant' for result in debate.get('results', [])))
        detail['debateConformance'] = debate
        status = 'passed' if state_ok and trace['testerCommandObserved'] and debate_ok else 'failed'
        if not trace['testerCommandObserved']:
            status = 'unavailable'
            detail['unavailableReason'] = (rollouts.get('error') if rollouts and not rollouts.get('available') else 'native trace lacks a completed tester challenge command in the task cwd; child prose is insufficient')
        elif rollouts is not None and not debate_ok:
            status = 'unavailable' if not debate or any(
                result.get('status') == 'unverifiable' for result in debate.get('results', [])) else 'failed'
            detail['unavailableReason'] = 'native debate conformance is incomplete or non-compliant'
        return {'case': case, 'status': status, **detail}
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        return {'case': case, 'status': 'failed', 'error': str(error)}


def save_state_attestation(fixture: dict, output: Path) -> None:
    """Persist measured fixture state before any grader can fail on a missing ref."""
    repo, task = fixture['repo'], fixture['repo'].parent / 'task'
    branch = subprocess.run(['git', '-C', str(repo), 'rev-parse', '--verify', 'refs/heads/codex/fix'], text=True, capture_output=True)
    main = git(repo, 'rev-parse', 'main')
    tip = branch.stdout.strip() if branch.returncode == 0 else main
    state = {'sourceDigest': fixture['sourceDigest'], 'scope': 'independent final fixture state; not a model success declaration',
             'initialCommit': fixture['initial'], 'mainCommit': main,
             'taskCommit': branch.stdout.strip() if branch.returncode == 0 else None,
             'commitObjects': git(repo, 'rev-list', '--all').splitlines(),
             'mainTree': git(repo, 'rev-parse', f'{main}^{{tree}}'),
             'candidateAncestorOfMain': subprocess.run(['git', '-C', str(repo), 'merge-base', '--is-ancestor', tip, main], capture_output=True).returncode == 0,
             'candidateCommit': tip, 'candidateTree': git(repo, 'rev-parse', f'{tip}^{{tree}}'),
             'candidateSource': subprocess.check_output(['git', '-C', str(repo), 'show', f'{tip}:calc.py']).decode(),
             'candidateDiff': git(repo, 'diff', fixture['initial'], tip),
             'expectedOtherWriter': fixture['otherSnapshot'], 'actualOtherWriter': snapshot(fixture['other']),
             'expectedCheckout': fixture['baseSnapshot'], 'actualCheckout': snapshot(repo),
             'actualTask': snapshot(task) if task.is_dir() else None,
             'checkoutConfigMode': (repo / '.env.fixture').stat().st_mode & 0o777,
             'taskConfigMode': (task / '.env.fixture').stat().st_mode & 0o777 if (task / '.env.fixture').exists() else None,
             'worktrees': git(repo, 'worktree', 'list', '--porcelain'),
             'checkoutStatus': git(repo, 'status', '--porcelain')}
    (output / 'state-attestation.json').write_text(json.dumps(state, indent=2) + '\n')


def validate_case_artifacts(directory: Path, case: str, source: Path, runtime: str,
                            require_session_store: bool = True) -> dict:
    """Validate collector files and native recordings, never summary verdicts.

    State files are trusted collector output outside the candidate write root.
    Native archives must match the native session store when a receipt is issued.
    Hashes preserve integrity afterward; they are not administrator-proof signing.
    """
    import datetime as dt
    events = read_records(directory / 'events.jsonl')
    roots = [e['thread_id'] for e in events if e.get('type') == 'thread.started']
    if len(roots) != 1:
        raise ValueError('missing unique native root identity')
    archives = directory / 'native-rollouts'
    files = [directory / 'events.jsonl', directory / 'state-attestation.json', directory / 'grade.json']

    def native_archive(thread: str) -> list[dict]:
        matches = list(archives.glob(f'rollout-*-{thread}.jsonl'))
        if len(matches) != 1:
            raise ValueError('missing unique native archive: ' + thread)
        path = matches[0]
        records = read_records(path)
        meta = records[0].get('payload', {})
        if records[0].get('type') != 'session_meta' or meta.get('id') != thread or meta.get('cli_version') != runtime:
            raise ValueError('native archive identity/runtime mismatch')
        when = dt.datetime.fromisoformat(meta['timestamp'].replace('Z', '+00:00'))
        dates = [(when + dt.timedelta(days=i)).strftime('%Y/%m/%d') for i in (-1, 0, 1)]
        if require_session_store:
            sessions = Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))) / 'sessions'
            original = rollout_for(thread, sessions, dates)
            if not original.read_bytes().startswith(path.read_bytes()):
                raise ValueError('archive is not an exact recorded native session prefix')
        files.append(path)
        return records

    root = native_archive(roots[0])
    meta = root[0]['payload']
    repo = Path(meta['cwd'])
    task = repo.parent / 'task'
    commands = native_commands(root)
    child_checks = []
    child_record_map = {}
    for child in spawned_testers(root):
        records = native_archive(child)
        child_record_map[child] = records
        validate_child_metadata(records, roots[0])
        observed = native_commands(records)
        proof = {'commands': observed,
                 'completionRecordIndexes': [index for index, record in enumerate(records)
                                             if record.get('type') == 'event_msg'
                                             and record.get('payload', {}).get('type') == 'task_complete']}
        child_checks.append(completed_substantive_challenge(proof, task))
        commands.extend(observed)
    if not any(child_checks):
        raise ValueError('no recorded standalone completed tester challenge')
    conformance = debate_conformance(root, child_record_map, task)
    if conformance.get('familyComplete') is not True or any(
            result.get('status') != 'compliant' for result in conformance.get('results', [])):
        raise ValueError('native debate conformance is incomplete or non-compliant: '
                         + json.dumps(conformance, sort_keys=True))
    flag = '--rebuttal' if case == 'false-positive' else '--ci' if case == 'ci-repair' else '--challenge'
    if not any(verified_native_check(c, flag, task) for c in commands):
        raise ValueError('required standalone native verification missing')
    if not any(c.get('exit_code') == 0 and any((Path(c['cwd']) / arg).resolve() == task.resolve() for arg in worktree_add(c['command']) if not arg.startswith('-')) for c in commands):
        raise ValueError('task worktree creation not observed')
    state = json.loads((directory / 'state-attestation.json').read_text())
    execution = json.loads((directory / 'grade.json').read_text())
    if type(execution.get('nativeExitCode')) is not int or execution['nativeExitCode'] != 0:
        raise ValueError('native execution did not exit successfully')
    if execution.get('debateConformance') != conformance:
        raise ValueError('recorded debate conformance differs from raw native family')
    if state.get('initialCommit') != meta.get('git', {}).get('commit_hash'):
        raise ValueError('state initial commit is not native-session bound')
    for key in ('initialCommit', 'mainCommit', 'candidateCommit', 'candidateTree', 'mainTree'):
        if not re.fullmatch('[a-f0-9]{40}', str(state.get(key))):
            raise ValueError('state Git identity missing: ' + key)
    with tempfile.TemporaryDirectory(prefix='delivery-artifact-state-check-') as temporary:
        expected = seed(Path(temporary), source, case)
        if state.get('sourceDigest') != expected['sourceDigest']:
            raise ValueError('collector state source digest mismatch')
        normalize = lambda values: {k: list(v) for k, v in values.items() if '__pycache__' not in Path(k).parts}
        baseline = normalize(expected['baseSnapshot'])
        other = normalize(expected['otherSnapshot'])
        if state.get('expectedOtherWriter') != other or state.get('actualOtherWriter') != other or state.get('expectedCheckout') != baseline:
            raise ValueError('state does not preserve trusted fixture/other-writer content')
        calc_source = state.get('candidateSource')
        if not isinstance(calc_source, str):
            raise ValueError('candidate source missing')
        candidate = {**baseline, 'calc.py': ['file', hashlib.sha256(calc_source.encode()).hexdigest()]}
        checkout = normalize(state.get('actualCheckout', {}))
        if state.get('checkoutStatus') != '' or state.get('checkoutConfigMode') != 0o640:
            raise ValueError('checkout is dirty or runtime config permissions changed')
        if case == 'pending-evidence':
            if checkout != baseline or normalize(state.get('actualTask') or {}) != candidate or state.get('taskConfigMode') != 0o640 or state.get('mainCommit') != state['initialCommit'] or state.get('taskCommit') != state['candidateCommit'] or str(task) not in state.get('worktrees', ''):
                raise ValueError('pending evidence delivery/state boundary failed')
        elif checkout != candidate or state.get('actualTask') is not None or str(task) in state.get('worktrees', '') or state.get('mainCommit') == state['initialCommit'] or state.get('candidateAncestorOfMain') is not True or state.get('mainTree') != state.get('candidateTree'):
            raise ValueError('merged delivery or cleanup state failed')
        check = Path(temporary) / 'independent'
        check.mkdir()
        (check / 'calc.py').write_text(calc_source)
        result = subprocess.run([sys.executable, '-I', '-c', "import runpy; f=runpy.run_path('calc.py')['total']; assert [f(x) for x in (-9,0,1,17)] == [-27,0,3,51]"], cwd=check, capture_output=True, timeout=10)
        if result.returncode:
            raise ValueError('archived candidate fails independent behavior check')
    objects = state.get('commitObjects')
    if not isinstance(objects, list) or len(set(objects)) != len(objects) or not all(isinstance(value, str) and re.fullmatch('[a-f0-9]{40}', value) for value in objects) or state['candidateCommit'] not in objects:
        raise ValueError('collector commit-object identity evidence missing')
    if not committed_task_observed(commands, task, state['candidateCommit'], objects=objects):
        raise ValueError('candidate commit not bound to native Git execution')
    return {'case': case, 'verdict': 'passed', 'rootThreadId': roots[0], 'cliVersion': runtime,
            'debateConformance': conformance,
            'artifacts': [{'path': str(p.relative_to(directory)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'bytes': p.stat().st_size} for p in sorted(set(files))]}


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
        profile = ('permissions.framework_delivery={extends=":read-only",filesystem={'
                   + json.dumps(str(area)) + '="write"},network={enabled=false}}')
        command = ['codex', '-a', 'never', 'exec', '--json', '--color', 'never',
                   '--disable', 'memories', '-c', 'default_permissions="framework_delivery"',
                   '-c', profile, '--cd', str(fixture['repo']), prompt_for(area, case)]
        started = time.time()
        try:
            with (output / 'events.jsonl').open('w') as stdout, (output / 'stderr.txt').open('w') as stderr:
                process = subprocess.Popen(command, stdout=stdout, stderr=stderr, start_new_session=True)
                try:
                    code = process.wait(timeout=timeout)
                except (subprocess.TimeoutExpired, KeyboardInterrupt):
                    terminate_group(process)
                    return {'case': case, 'status': 'unavailable', 'error': 'native execution interrupted or timed out'}
            save_state_attestation(fixture, output)
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
    def test_versioned_debate_conformance_is_per_finding_and_fail_closed(self):
        task = Path('/fixture/task')
        plan_nonce = '0123456789abcdef'
        result_nonce = 'fedcba9876543210'
        def assistant(at, text):
            return {'timestamp': at, 'type': 'response_item', 'payload': {
                'type': 'message', 'role': 'assistant',
                'content': [{'type': 'output_text', 'text': text}]}}
        def response(at, finding, pointer, nonce):
            return assistant(at, f'[developer_response:{finding}] accept evidence={pointer}; nonce={nonce}')
        def followup(at, message, target='/root/challenge'):
            return {'timestamp': at, 'type': 'response_item', 'payload': {
                'type': 'function_call', 'name': 'followup_task',
                'arguments': json.dumps({'target': target, 'message': message})}}
        def inbound(at, message):
            return {'timestamp': at, 'type': 'response_item', 'payload': {
                'type': 'agent_message', 'author': '/root', 'recipient': '/root/challenge',
                'content': [{'type': 'encrypted_content', 'encrypted_content': message}]}}
        def command(at, command, output='ok'):
            return [
                {'timestamp': at, 'type': 'response_item', 'payload': {
                    'type': 'function_call', 'name': 'exec_command', 'call_id': at,
                    'arguments': json.dumps({'cmd': command, 'workdir': str(task)})}},
                {'timestamp': at, 'type': 'response_item', 'payload': {
                    'type': 'function_call_output', 'call_id': at,
                    'output': {'exit_code': 0, 'output': output}}},
            ]
        def mutation(at):
            return {'timestamp': at, 'type': 'event_msg', 'payload': {
                'type': 'item_completed', 'item': {'type': 'FileChange', 'status': 'completed',
                    'changes': {'/fixture/task/calc.py': {'type': 'update'}}}}}
        root = [
            {'timestamp': '2026-09-21T00:00:00.500Z', 'type': 'event_msg',
             'payload': {'type': 'item_completed', 'item': {'type': 'SubAgentActivity',
                'kind': 'started', 'agent_path': '/root/challenge'}}},
            response('2026-09-21T00:00:02Z', 'PLAN-1', 'file:README.md@sha256:' + 'a' * 64, plan_nonce),
            *command('2026-09-21T00:00:03Z', 'shasum -a 256 README.md', 'a' * 64 + '  README.md\n'),
            followup('2026-09-21T00:00:03.250Z', 'cipher-plan'),
            assistant('2026-09-21T00:00:04Z', '[parent_adjudication:PLAN-1] accept'),
            mutation('2026-09-21T00:00:04.500Z'),
            response('2026-09-21T00:00:06Z', 'RESULT-1', 'command:python3 verify.py --challenge', result_nonce),
            *command('2026-09-21T00:00:07Z', 'python3 verify.py --challenge'),
            followup('2026-09-21T00:00:07.250Z', 'cipher-result'),
            assistant('2026-09-21T00:00:08Z', '[parent_adjudication:RESULT-1] accept'),
        ]
        child = [
            assistant('2026-09-21T00:00:01Z', '[challenge:PLAN-1]\n\nmissing behavior\nwith evidence scope'),
            inbound('2026-09-21T00:00:03.300Z', 'cipher-plan'),
            assistant('2026-09-21T00:00:03.500Z',
                      f'[challenger_disposition:PLAN-1] resolved responseNonce={plan_nonce}'),
            assistant('2026-09-21T00:00:05Z', '[challenge:RESULT-1] failure path'),
            inbound('2026-09-21T00:00:07.300Z', 'cipher-result'),
            assistant('2026-09-21T00:00:07.500Z',
                      f'[challenger_disposition:RESULT-1] resolved responseNonce={result_nonce}'),
        ]
        receipt = debate_conformance(root, {'child': child}, task)
        self.assertEqual(receipt['conformanceVersion'], 3)
        self.assertTrue(receipt['familyComplete'])
        self.assertTrue(all(row['status'] == 'compliant' for row in receipt['results']))
        wrong_content = copy.deepcopy(root)
        wrong_content[1] = response('2026-09-21T00:00:02Z', 'PLAN-1',
                                    'file:README.md@sha256:' + 'b' * 64, plan_nonce)
        self.assertNotEqual(debate_conformance(wrong_content, {'child': child}, task)['results'][0]['status'],
                            'compliant')
        self.assertFalse(pointer_verified({'source': 'file', 'pointer': '-@sha256:' + 'a' * 64},
                                         [{'timestamp': '2026-09-21T00:00:03Z', 'recordIndex': 5,
                                           'exit_code': 0, 'cwd': str(task), 'command': 'shasum -a 256 -',
                                           'output': 'a' * 64 + '  -\n'}],
                                         task, (0, 0), (float('inf'), 0)))
        self.assertEqual(receipt['bindings']['environmentScope'], 'disposable-local-no-network')
        self.assertEqual(evidence_pointer(
            'accept evidence=file:README.md@sha256:' + 'a' * 64 + '; verify-now=shasum -a 256 README.md'),
            {'source': 'file', 'pointer': 'README.md@sha256:' + 'a' * 64})

        missing = debate_conformance(root, {}, task)
        self.assertFalse(missing['familyComplete'])
        self.assertTrue(all(row['status'] == 'unverifiable' for row in missing['results']))
        duplicate = debate_conformance(root + [root[1]], {'child': child}, task)
        self.assertEqual(duplicate['results'][0]['status'], 'violation')
        unordered = copy.deepcopy(child)
        unordered[-1]['timestamp'] = '2026-09-21T00:00:06.500Z'
        receipt = debate_conformance(root, {'child': unordered}, task)
        self.assertNotEqual(receipt['results'][1]['status'], 'compliant')
        unexpected = child + [assistant('2026-09-21T00:00:04.700Z',
                                        '[challenge:SECURITY-2] open defect')]
        receipt = debate_conformance(root, {'child': unexpected}, task)
        self.assertFalse(receipt['familyComplete'])
        self.assertEqual(next(row for row in receipt['results']
                              if row['findingId'] == 'SECURITY-2')['status'], 'violation')
        quoted_root = copy.deepcopy(root)
        quoted_root[1] = assistant('2026-09-21T00:00:02Z',
            '```text\n[developer_response:PLAN-1] accept evidence=file:README.md\n```\nQuoted hypothetical transcript; not my decision')
        receipt = debate_conformance(quoted_root, {'child': child}, task)
        self.assertNotEqual(receipt['results'][0]['status'], 'compliant')
        for moved in ('2026-09-21T00:00:00.500Z', '2026-09-21T00:00:08.500Z'):
            moved_root = copy.deepcopy(root)
            next(record for record in moved_root
                 if record.get('payload', {}).get('item', {}).get('type') == 'FileChange')['timestamp'] = moved
            receipt = debate_conformance(moved_root, {'child': child}, task)
            self.assertFalse(receipt['familyComplete'])
            self.assertTrue(any(row['status'] == 'violation' for row in receipt['results']))
        no_followup = [record for record in root
                       if record.get('payload', {}).get('name') != 'followup_task']
        self.assertNotEqual(debate_conformance(no_followup, {'child': child}, task)['results'][0]['status'],
                            'compliant')
        wrong_target = copy.deepcopy(root)
        next(record for record in wrong_target
             if record.get('payload', {}).get('name') == 'followup_task')['payload']['arguments'] = \
            json.dumps({'target': '/root/other', 'message': 'cipher-plan'})
        self.assertNotEqual(debate_conformance(wrong_target, {'child': child}, task)['results'][0]['status'],
                            'compliant')
        wrong_nonce = copy.deepcopy(child)
        wrong_nonce[2] = assistant('2026-09-21T00:00:03.500Z',
                                   '[challenger_disposition:PLAN-1] resolved responseNonce=aaaaaaaaaaaaaaaa')
        self.assertEqual(debate_conformance(root, {'child': wrong_nonce}, task)['results'][0]['status'],
                         'violation')
        pre_plan_command = copy.deepcopy(root)
        pre_plan_command[1:1] = command('2026-09-21T00:00:00.750Z', "git commit -am 'premature'")
        self.assertEqual(debate_conformance(pre_plan_command, {'child': child}, task)['results'][0]['status'],
                         'violation')
        cross_cwd_command = copy.deepcopy(root)
        cross_cwd_command[1:1] = [{**record, 'payload': {**record['payload'],
            'arguments': json.dumps({'cmd': "python3 -c \"open('/fixture/task/calc.py','w').write('bad')\"",
                                     'workdir': '/fixture/checkout'})}}
            if record.get('payload', {}).get('type') == 'function_call' else record
            for record in command('2026-09-21T00:00:00.750Z', 'placeholder')]
        self.assertEqual(debate_conformance(cross_cwd_command, {'child': child}, task)['results'][0]['status'],
                         'violation')
        self.assertTrue(preplan_command_allowed({
            'command': "/bin/zsh -lc \"pwd && rg --files -g 'README.md' && git status --short --branch && stat -f '%Lp %N' .env.fixture 2>/dev/null || true\"",
            'cwd': '/fixture/checkout'}, task))
        for read in ('gh auth status', 'gh repo view NepipenkoIgor/Property --json nameWithOwner',
                     'gh pr view 367 -R NepipenkoIgor/Property --json state,mergeCommit',
                     'codex --version', 'rg -n booking src', 'git rev-parse HEAD'):
            self.assertTrue(preplan_command_allowed({'command': read, 'cwd': str(task)}, task), read)
        for unsafe in ('gh pr merge 367', 'gh repo view NepipenkoIgor/Property --web',
                       "gh repo view NepipenkoIgor/Property --json nameWithOwner --jq 'env.GH_TOKEN'",
                       'gh pr view 367 -R NepipenkoIgor/Property -w --json state',
                       'rg --pre sh pattern .', 'rg pattern . | sh',
                       'git commit -am premature', 'sed -i s/a/b/ README.md',
                       'sed -n "1w /tmp/early-write" README.md'):
            self.assertFalse(preplan_command_allowed({'command': unsafe, 'cwd': str(task)}, task), unsafe)
        self.assertFalse(preplan_command_allowed({
            'command': "python3 -c \"open('/fixture/task/calc.py','w').write('bad')\"",
            'cwd': '/fixture/checkout'}, task))
        encrypted_root = copy.deepcopy(root)
        encrypted_root.extend([
            {'timestamp': '2026-09-21T00:00:01.200Z', 'type': 'response_item', 'payload': {
                'type': 'agent_message', 'author': '/root/challenge', 'recipient': '/root',
                'content': [{'type': 'encrypted_content', 'encrypted_content': 'cipher-challenge-plan'}]}},
            {'timestamp': '2026-09-21T00:00:05.200Z', 'type': 'response_item', 'payload': {
                'type': 'agent_message', 'author': '/root/challenge', 'recipient': '/root',
                'content': [{'type': 'encrypted_content', 'encrypted_content': 'cipher-challenge-result'}]}},
            {'timestamp': '2026-09-21T00:00:03.450Z', 'type': 'response_item', 'payload': {
                'type': 'agent_message', 'author': '/root/challenge', 'recipient': '/root',
                'content': [{'type': 'encrypted_content', 'encrypted_content': 'cipher-disposition-plan'}]}},
            {'timestamp': '2026-09-21T00:00:07.450Z', 'type': 'response_item', 'payload': {
                'type': 'agent_message', 'author': '/root/challenge', 'recipient': '/root',
                'content': [{'type': 'encrypted_content', 'encrypted_content': 'cipher-disposition-result'}]}},
        ])
        encrypted_child = [record for record in copy.deepcopy(child)
                           if '[challenge:' not in (assistant_text(record) or '')]
        encrypted_child.extend([
            {'timestamp': '2026-09-21T00:00:01.100Z', 'type': 'response_item', 'payload': {
                'type': 'function_call', 'name': 'send_message',
                'arguments': json.dumps({'target': '/root', 'message': 'cipher-challenge-plan'})}},
            {'timestamp': '2026-09-21T00:00:05.100Z', 'type': 'response_item', 'payload': {
                'type': 'function_call', 'name': 'send_message',
                'arguments': json.dumps({'target': '/root', 'message': 'cipher-challenge-result'})}},
            {'timestamp': '2026-09-21T00:00:03.400Z', 'type': 'response_item', 'payload': {
                'type': 'function_call', 'name': 'send_message',
                'arguments': json.dumps({'target': '/root', 'message': 'cipher-disposition-plan'})}},
            {'timestamp': '2026-09-21T00:00:07.400Z', 'type': 'response_item', 'payload': {
                'type': 'function_call', 'name': 'send_message',
                'arguments': json.dumps({'target': '/root', 'message': 'cipher-disposition-result'})}},
        ])
        next(record for record in encrypted_child
             if '[challenger_disposition:PLAN-1]' in (assistant_text(record) or ''))['timestamp'] = \
            '2026-09-21T00:00:04.200Z'
        next(record for record in encrypted_child
             if '[challenger_disposition:RESULT-1]' in (assistant_text(record) or ''))['timestamp'] = \
            '2026-09-21T00:00:08.200Z'
        encrypted_receipt = debate_conformance(encrypted_root, {'child': encrypted_child}, task)
        self.assertTrue(encrypted_receipt['familyComplete'], encrypted_receipt)
        self.assertTrue(all(row['status'] == 'compliant' for row in encrypted_receipt['results']))

    def test_native_v2_spawn_activity_proves_tester_identity_without_tool_output(self):
        records = [
            {'type': 'response_item', 'payload': {
                'type': 'function_call', 'name': 'spawn_agent', 'call_id': 'spawn-1',
                'arguments': json.dumps({'agent_type': 'tester', 'task_name': 'challenge'}),
            }},
            {'type': 'event_msg', 'payload': {'type': 'item_completed', 'item': {
                'type': 'SubAgentActivity', 'kind': 'started', 'id': 'spawn-1',
                'agent_thread_id': 'child-1', 'agent_path': '/root/challenge',
            }}},
        ]
        self.assertEqual(spawned_testers(records), ['child-1'])
        wrong_path = copy.deepcopy(records)
        wrong_path[1]['payload']['item']['agent_path'] = '/root/other'
        with self.assertRaises(ValueError):
            spawned_testers(wrong_path)
        wrong_role = copy.deepcopy(records)
        wrong_role[0]['payload']['arguments'] = json.dumps({'agent_type': 'worker', 'task_name': 'challenge'})
        self.assertEqual(spawned_testers(wrong_role), [])
        for task_name in ('', '../other'):
            malformed = copy.deepcopy(records)
            malformed[0]['payload']['arguments'] = json.dumps({'agent_type': 'tester', 'task_name': task_name})
            with self.assertRaises(ValueError):
                spawned_testers(malformed)
        missing_call = copy.deepcopy(records)
        del missing_call[0]['payload']['call_id']
        with self.assertRaises(ValueError):
            spawned_testers(missing_call)
        multiple = copy.deepcopy(records) + [copy.deepcopy(records[1])]
        multiple[-1]['payload']['item']['agent_thread_id'] = 'child-2'
        with self.assertRaises(ValueError):
            spawned_testers(multiple)
        conflict = copy.deepcopy(records)
        conflict.insert(1, {'type': 'response_item', 'payload': {
            'type': 'function_call_output', 'call_id': 'spawn-1',
            'output': json.dumps({'agent_id': 'child-output', 'task_name': '/root/challenge'}),
        }})
        with self.assertRaises(ValueError):
            spawned_testers(conflict)

    def test_trace_negatives(self):
        self.assertFalse(trace_evidence(json.dumps({'type': 'agent_message', 'text': 'tester passed'}))['testerCommandObserved'])
        self.assertTrue(trace_evidence(parser_trace())['testerCommandObserved'])
        for command in ("echo 'python3 verify.py --challenge'", 'true || python3 verify.py --challenge',
                        'python3 verify.py --challenge || true', 'false && python3 verify.py --challenge',
                        'exit 0 && python3 verify.py --challenge'):
            self.assertFalse(direct_check(command, '--challenge'))

    def test_substantive_child_challenge_is_executable_and_ordered(self):
        task = Path('/fixture/task')
        probe = "from calc import total; values=(0,1,-1); assert all(total(v)==v*3 for v in values); print('result-challenge-ok')"
        record = {'command': f"git status --short --branch; python3 -c {shlex.quote(probe)}",
                  'cwd': str(task), 'exit_code': 0, 'recordIndex': 4}
        self.assertTrue(substantive_child_challenge(record, task))
        self.assertTrue(substantive_child_challenge(
            {**record, 'command': f"python3 -B -c {shlex.quote(probe)}"}, task))
        self.assertTrue(completed_substantive_challenge(
            {'commands': [record], 'completionRecordIndexes': [5]}, task))
        self.assertFalse(completed_substantive_challenge(
            {'commands': [record], 'completionRecordIndexes': [3]}, task))
        self.assertFalse(substantive_child_challenge({**record, 'cwd': '/fixture/root'}, task))
        self.assertFalse(substantive_child_challenge({**record, 'exit_code': 1}, task))
        self.assertFalse(substantive_child_challenge(
            {**record, 'command': "python3 -c 'print(\"result-challenge-ok\")'"}, task))
        vacuous = "from calc import total; values=(-1,0,1); assert (total(0)==0) or True or (3*-1)"
        self.assertFalse(substantive_child_challenge(
            {**record, 'command': f"python3 -c {shlex.quote(vacuous)}"}, task))
        rebound = "from calc import total; total=lambda v:v*3; values=(-1,0,1); assert all(total(v)==v*3 for v in values)"
        self.assertFalse(substantive_child_challenge(
            {**record, 'command': f"python3 -c {shlex.quote(rebound)}"}, task))
        module_rebound = "import calc; calc.total=lambda v:v*3; from calc import total; values=(-1,0,1); assert all(total(v)==v*3 for v in values)"
        self.assertFalse(substantive_child_challenge(
            {**record, 'command': f"python3 -c {shlex.quote(module_rebound)}"}, task))
        global_rebound = "from calc import total; globals()['total']=lambda v:v*3; values=(-1,0,1); assert all(total(v)==v*3 for v in values)"
        self.assertFalse(substantive_child_challenge(
            {**record, 'command': f"python3 -c {shlex.quote(global_rebound)}"}, task))
        stdlib_rebound = ("import calc; from operator import setitem, mul; from functools import partial; "
                          "setitem(calc.__dict__, 'total', partial(mul,3)); from calc import total; "
                          "values=(-1,0,1); assert all(total(v)==v*3 for v in values)")
        self.assertFalse(substantive_child_challenge(
            {**record, 'command': f"python3 -c {shlex.quote(stdlib_rebound)}"}, task))
        value_rebound = ("values=(-1,0,1,(__import__('operator').setitem(__import__('calc').__dict__,'total',"
                         "__import__('functools').partial(__import__('operator').mul,3)) or 7)); "
                         "from calc import total; assert all(total(v)==v*3 for v in values)")
        self.assertFalse(substantive_child_challenge(
            {**record, 'command': f"python3 -c {shlex.quote(value_rebound)}"}, task))
        dead_import = "if False: from calc import total\ntotal=lambda v:v*3\nvalues=(-1,0,1)\nassert all(total(v)==v*3 for v in values)"
        self.assertFalse(substantive_child_challenge(
            {**record, 'command': f"python3 -c {shlex.quote(dead_import)}"}, task))
        for command in (f"python3 -c {shlex.quote(probe)}; true",
                        f"true || python3 -c {shlex.quote(probe)}",
                        f"/tmp/python3 -c {shlex.quote(probe)}",
                        f"python3 -O -c {shlex.quote(probe)}",
                        f"export PYTHONOPTIMIZE=1; python3 -c {shlex.quote(probe)}",
                        f"PYTHONOPTIMIZE=1; export PYTHONOPTIMIZE; python3 -c {shlex.quote(probe)}"):
            self.assertFalse(substantive_child_challenge({**record, 'command': command}, task))

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
        self.assertFalse(verified_native_check(command, '--challenge', Path('/fixture/task')))
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


    def test_native_v2_task_and_command_identity(self):
        records = [
            {'type': 'response_item', 'payload': {'type': 'function_call', 'name': 'spawn_agent', 'call_id': 'spawn', 'arguments': '{"agent_type":"tester"}'}},
            {'type': 'response_item', 'payload': {'type': 'function_call_output', 'call_id': 'spawn', 'output': '{"task_name":"/root/challenge"}'}},
            {'type': 'event_msg', 'payload': {'type': 'item_completed', 'item': {'type': 'SubAgentActivity', 'kind': 'started', 'id': 'spawn', 'agent_path': '/root/challenge', 'agent_thread_id': 'child'}}},
        ]
        self.assertEqual(spawned_testers(records), ['child'])
        item = records[-1]['payload']['item']
        item['agent_path'] = '/root/unrelated'
        with self.assertRaises(ValueError):
            spawned_testers(records)
        item['agent_path'] = '/root/challenge'
        item['id'] = 'other-call'
        self.assertEqual(spawned_testers(records), [])
        metadata = [{'payload': {'parent_thread_id': 'parent', 'agent_role': 'tester'}}]
        validate_child_metadata(metadata, 'parent')
        with self.assertRaises(ValueError):
            validate_child_metadata(metadata, 'unrelated')
        metadata[0]['payload']['agent_role'] = 'worker'
        with self.assertRaises(ValueError):
            validate_child_metadata(metadata, 'parent')
        command = {'type': 'event_msg', 'payload': {'type': 'item_completed', 'item': {
            'type': 'CommandExecution', 'id': 'native-command', 'status': 'completed', 'command': ['/bin/zsh', '-lc', 'PYTHONDONTWRITEBYTECODE=1 python3 verify.py --challenge'],
            'cwd': 'file:///fixture/task%20space', 'exit_code': 0, 'stdout': 'fixture-verification-ok:--challenge\n'}}}
        proof = native_commands([command])[0]
        self.assertTrue(verified_native_check(proof, '--challenge', Path('/fixture/task space')))
        self.assertFalse(verified_native_check(proof, '--challenge', Path('/fixture/other')))
        self.assertTrue(worktree_add('git worktree add -b codex/fix ../task;'))
        self.assertFalse(worktree_add('git worktree add -b codex/fix ../task; true'))
        executable = '/Library/Developer/CommandLineTools/usr/bin/git'
        actual = f"/bin/zsh -lc 'ls -l {executable}; git worktree add -b codex/fix /fixture/task main'"
        self.assertEqual(worktree_add(actual), ['-b', 'codex/fix', '/fixture/task', 'main'])
        self.assertTrue(worktree_add(f'{executable} worktree add -b codex/fix ../task'))
        chained = 'git worktree add -b codex/fix /fixture/task main && cp -p ../checkout/.env.fixture /fixture/task/.env.fixture && git worktree list --porcelain'
        self.assertEqual(worktree_add(chained), ['-b', 'codex/fix', '/fixture/task', 'main'])
        env_chained = 'env TMPDIR=/fixture git worktree add -b codex/fix /fixture/task main && cp -p ../checkout/.env.fixture /fixture/task/.env.fixture'
        self.assertEqual(worktree_add(env_chained), ['-b', 'codex/fix', '/fixture/task', 'main'])
        guarded = 'test ! -e /fixture/task && git show-ref --verify --quiet refs/heads/codex/fix; rc=$?; if [ "$rc" -eq 0 ]; then exit 2; fi; git worktree add -b codex/fix /fixture/task main'
        self.assertEqual(worktree_add(guarded), ['-b', 'codex/fix', '/fixture/task', 'main'])
        for impostor in ('/tmp/git', '/usr/local/bin/git'):
            self.assertFalse(worktree_add(f'{impostor} worktree add -b codex/fix ../task'))
            self.assertFalse(worktree_add(actual.replace(executable, impostor)))
        self.assertFalse(worktree_add(actual.replace('ls -l', 'touch')))
        self.assertFalse(worktree_add(actual[:-1] + "; true'"))


    def test_compound_verifiers_are_never_proof(self):
        command = 'git log -1 --format=fixture-verification-%x6fk:--challenge && PYTHONDONTWRITEBYTECODE=1 python3 verify.py --challenge\ngit status --porcelain'
        proof = {'command': command, 'cwd': '/fixture/task', 'exit_code': 0, 'output': 'fixture-verification-ok:--challenge\n'}
        self.assertFalse(verified_native_check(proof, '--challenge', Path('/fixture/task')))
        for command in ('python3 verify.py --challenge && true', 'python3 verify.py --challenge || true', 'cd /fixture/task && python3 verify.py --challenge', 'echo fixture-verification-ok:--challenge'):
            self.assertFalse(verified_native_check({**proof, 'command': command}, '--challenge', Path('/fixture/task')))

    def test_merged_branch_deletion_and_state_attestation(self):
        with tempfile.TemporaryDirectory() as temporary:
            area = Path(temporary)
            f = seed(area, ROOT, 'merge-cleanup')
            repo, task = f['repo'], area / 'task'
            git(repo, 'worktree', 'add', '-q', '-b', 'codex/fix', str(task))
            (task / 'calc.py').write_text('def total(value):\n    return value * 3\n')
            git(task, 'add', 'calc.py'); git(task, 'commit', '-qm', 'fix')
            sha = git(task, 'rev-parse', 'HEAD')
            git(repo, 'merge', '--ff-only', 'codex/fix')
            git(repo, 'worktree', 'remove', str(task)); git(repo, 'branch', '-d', 'codex/fix')
            native = {'available': True, 'rootCommands': [
                {'command': 'git worktree add -b codex/fix ../task', 'cwd': str(repo), 'exit_code': 0},
                {'command': "env TMPDIR=/fixture git add calc.py && env TMPDIR=/fixture git commit -m 'fix' && git rev-parse HEAD && git status --short --branch", 'cwd': str(task), 'exit_code': 0, 'output': f'[codex/fix {sha[:7]}] fix\n{sha}\n## codex/fix\n'},
            ], 'children': {'child': {'completionRecordIndexes': [2], 'commands': [
                {'command': 'python3 verify.py --challenge', 'cwd': str(task), 'exit_code': 0, 'recordIndex': 1}]}},
                'debateConformance': {'conformanceVersion': 3, 'scope': 'release-certification',
                    'familyComplete': True, 'bindings': debate_bindings(task), 'results': [
                        {'exchangeId': 'delivery-plan-1', 'findingId': 'PLAN-1', 'phase': 'pre',
                         'status': 'compliant', 'reasons': [], 'evidencePointers': [{'source': 'file', 'pointer': 'README.md'}]},
                        {'exchangeId': 'delivery-result-1', 'findingId': 'RESULT-1', 'phase': 'post',
                         'status': 'compliant', 'reasons': [], 'evidencePointers': [{'source': 'command', 'pointer': 'python3 verify.py --challenge'}]},
                    ]}}
            self.assertEqual(grade('merge-cleanup', f, parser_trace(task=task), native)['status'], 'passed')
            configured_commit = {**native['rootCommands'][1],
                'command': "git add calc.py && git -c user.name=Codex -c user.email=codex@local commit -m 'fix'",
                'output': f'[codex/fix {sha[:7]}] fix\n'}
            self.assertTrue(committed_task_observed([configured_commit], task, sha, repo))
            amend_tracked = {**configured_commit, 'command': "git commit -am 'fix'"}
            self.assertTrue(committed_task_observed([amend_tracked], task, sha, repo))
            for command in ("git commit -am 'fix' && git status --short --branch",
                            "git commit -am 'fix' && git rev-parse HEAD",
                            "git commit -am 'fix' && python3 verify.py --challenge"):
                self.assertFalse(committed_task_observed([{**amend_tracked, 'command': command}], task, sha, repo))
            ambiguous = {**amend_tracked, 'output': amend_tracked['output'] + '[codex/fix deadbee] other\n'}
            self.assertFalse(committed_task_observed([ambiguous], task, sha, repo))
            native['rootCommands'][1]['output'] = 'f' * 40
            self.assertNotEqual(grade('merge-cleanup', f, parser_trace(task=task), native)['status'], 'passed')
            save_state_attestation(f, area)
            state = json.loads((area / 'state-attestation.json').read_text())
            self.assertIsNone(state['taskCommit'])
            self.assertEqual(state['candidateCommit'], sha)
            self.assertEqual(state['expectedOtherWriter'], state['actualOtherWriter'])


    def test_raw_artifact_validation_rejects_claims_and_tampering(self):
        with tempfile.TemporaryDirectory() as temporary:
            area = Path(temporary).resolve()
            workspace = area / 'workspace'; workspace.mkdir()
            f = seed(workspace, ROOT, 'pending-evidence')
            repo, task = f['repo'], workspace / 'task'
            git(repo, 'worktree', 'add', '-q', '-b', 'codex/fix', str(task))
            (task / '.env.fixture').write_bytes(f['config']); (task / '.env.fixture').chmod(0o640)
            (task / 'calc.py').write_text('def total(value):\n    return value * 3\n')
            git(task, 'add', 'calc.py'); git(task, 'commit', '-qm', 'fix')
            sha = git(task, 'rev-parse', 'HEAD')
            evidence = area / 'evidence'; evidence.mkdir()
            save_state_attestation(f, evidence)
            root_id, child_id = '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'
            (evidence / 'events.jsonl').write_text(json.dumps({'type': 'thread.started', 'thread_id': root_id}))
            def meta(identity, **extra):
                return {'type':'session_meta','payload':{'id':identity,'cli_version':'0.154.0','timestamp':'2026-09-16T00:00:00+00:00','cwd':str(repo),'git':{'commit_hash':f['initial']},**extra}}
            def execution(at, command, cwd, output=''):
                return {'timestamp':at,'type':'event_msg','payload':{'type':'item_completed','item':{'type':'CommandExecution','status':'completed','command':['/bin/zsh','-lc',command],'cwd':str(cwd),'exit_code':0,'stdout':output}}}
            def assistant(at, text):
                return {'timestamp':at,'type':'response_item','payload':{'type':'message','role':'assistant','content':[{'type':'output_text','text':text}]}}
            def followup(at, text):
                return {'timestamp':at,'type':'response_item','payload':{'type':'function_call','name':'followup_task','arguments':json.dumps({'target':'/root/challenge','message':text})}}
            def inbound(at, text):
                return {'timestamp':at,'type':'response_item','payload':{'type':'agent_message','author':'/root','recipient':'/root/challenge','content':[{'type':'encrypted_content','encrypted_content':text}]}}
            def mutation(at):
                return {'timestamp':at,'type':'event_msg','payload':{'type':'item_completed','item':{
                    'type':'FileChange','status':'completed','changes':{str(task / 'calc.py'):{'type':'update'}}}}}
            plan_nonce, result_nonce = '0123456789abcdef', 'fedcba9876543210'
            readme_digest = hashlib.sha256((task / 'README.md').read_bytes()).hexdigest()
            roots = [meta(root_id), execution('2026-09-16T00:00:00.500+00:00','git worktree add -b codex/fix ../task',repo),
                     {'type':'response_item','payload':{'type':'function_call','name':'spawn_agent','call_id':'spawn','arguments':'{"agent_type":"tester"}'}},
                     {'type':'response_item','payload':{'type':'function_call_output','call_id':'spawn','output':json.dumps({'agent_id':child_id})}},
                     {'timestamp':'2026-09-16T00:00:00.750+00:00','type':'event_msg','payload':{'type':'item_completed','item':{'type':'SubAgentActivity','kind':'started','agent_path':'/root/challenge'}}},
                     assistant('2026-09-16T00:00:02+00:00',f'[developer_response:PLAN-1] accept evidence=file:README.md@sha256:{readme_digest}; nonce={plan_nonce}'),
                     followup('2026-09-16T00:00:03.250+00:00','cipher-plan'),
                     assistant('2026-09-16T00:00:04+00:00','[parent_adjudication:PLAN-1] accept'),
                     mutation('2026-09-16T00:00:04.500+00:00'),
                     execution('2026-09-16T00:00:04.600+00:00',"git add calc.py && git commit -m 'fix'",task,f'[codex/fix {sha[:7]}] fix\n'),
                     assistant('2026-09-16T00:00:06+00:00',f'[developer_response:RESULT-1] accept evidence=command:python3 verify.py --challenge; nonce={result_nonce}'),
                     followup('2026-09-16T00:00:07.250+00:00','cipher-result'),
                     assistant('2026-09-16T00:00:08+00:00','[parent_adjudication:RESULT-1] accept')]
            children = [meta(child_id,parent_thread_id=root_id,agent_role='tester'),
                        assistant('2026-09-16T00:00:01+00:00','[challenge:PLAN-1] contract gap'),
                        execution('2026-09-16T00:00:03+00:00','shasum -a 256 README.md',task,
                                  f'{readme_digest}  README.md\n'),
                        inbound('2026-09-16T00:00:03.300+00:00','cipher-plan'),
                        assistant('2026-09-16T00:00:03.500+00:00',f'[challenger_disposition:PLAN-1] resolved responseNonce={plan_nonce}'),
                        assistant('2026-09-16T00:00:05+00:00','[challenge:RESULT-1] verify behavior'),
                        execution('2026-09-16T00:00:07+00:00','python3 verify.py --challenge',task),
                        inbound('2026-09-16T00:00:07.300+00:00','cipher-result'),
                        assistant('2026-09-16T00:00:07.500+00:00',f'[challenger_disposition:RESULT-1] resolved responseNonce={result_nonce}'),
                        {'type':'event_msg','payload':{'type':'task_complete'}}]
            conformance = debate_conformance(roots, {child_id: children}, task)
            (evidence / 'grade.json').write_text(json.dumps({'nativeExitCode':0,'debateConformance':conformance}))
            home = area / 'native-home'; sessions = home / 'sessions/2026/09/16'; sessions.mkdir(parents=True)
            archives = evidence / 'native-rollouts'; archives.mkdir()
            for identity, records in ((root_id,roots),(child_id,children)):
                content = '\n'.join(json.dumps(r) for r in records)
                name = f'rollout-test-{identity}.jsonl'
                (sessions/name).write_text(content); (archives/name).write_text(content)
            original_home = os.environ.get('CODEX_HOME')
            os.environ['CODEX_HOME'] = str(home)
            try:
                receipt = validate_case_artifacts(evidence,'pending-evidence',ROOT,'0.154.0')
                self.assertEqual(receipt['verdict'],'passed')
                commit_command = {'command':"git add calc.py && git commit -m 'fix'",'cwd':str(task),'exit_code':0,'output':f'[codex/fix {sha[:7]}] fix\n'}
                self.assertTrue(committed_task_observed([commit_command],task,sha,repo))
                self.assertFalse(committed_task_observed([commit_command],task,sha,objects=[sha,sha[:7]+'f'*33]))
                with self.assertRaises(ValueError):
                    validate_case_artifacts(evidence,'pending-evidence',ROOT,'0.153.0')
                state_path = evidence/'state-attestation.json'
                state = json.loads(state_path.read_text())
                state['actualOtherWriter']['sentinel.txt'] = ['file','0'*64]
                state_path.write_text(json.dumps(state))
                with self.assertRaises(ValueError):
                    validate_case_artifacts(evidence,'pending-evidence',ROOT,'0.154.0')
                save_state_attestation(f,evidence)
                child_path = archives/f'rollout-test-{child_id}.jsonl'
                child_path.write_text(child_path.read_text().replace('python3 verify.py --challenge','echo fake success'))
                with self.assertRaises(ValueError):
                    validate_case_artifacts(evidence,'pending-evidence',ROOT,'0.154.0')
            finally:
                if original_home is None: os.environ.pop('CODEX_HOME',None)
                else: os.environ['CODEX_HOME'] = original_home


    def test_exact_system_git_commit_executable(self):
        sha = '3bd14cf' + '1' * 33
        executable = '/Library/Developer/CommandLineTools/usr/bin/git'
        command = {'cwd': '/fixture/task', 'exit_code': 0,
                   'command': f"{executable} add calc.py && {executable} commit -m 'Fix total to triple signed integers'",
                   'output': '[codex/fix 3bd14cf] Fix total to triple signed integers\n'}
        self.assertTrue(committed_task_observed([command], Path('/fixture/task'), sha, objects=[sha]))
        for impostor in ('/tmp/git', '/tmp/Developer/CommandLineTools/usr/bin/git', '/usr/local/bin/git'):
            self.assertFalse(committed_task_observed([{**command, 'command': command['command'].replace(executable, impostor)}], Path('/fixture/task'), sha, objects=[sha]))



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
    def interrupted(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
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
