#!/bin/bash
set -euo pipefail

payload="$(cat)"
if command -v jq >/dev/null 2>&1; then
  command_text="$(printf '%s' "$payload" | jq -r '[.. | objects | to_entries[] | select(.key | test("^(cmd|command|shell_command|script)$")) | .value | if type == "array" then join(" ") else tostring end] | map(select(. != "null" and . != "")) | join("\\n")' 2>/dev/null)"
else
  command_text="$payload"
fi
command_scan="$(printf '%s' "$command_text" | tr '[:upper:]' '[:lower:]' | tr -d "'\\\"")"

block() {
  printf 'Codex Framework hook guard: %s\n' "$1" >&2
  exit 2
}

printf '%s\n' "$command_scan" | grep -Eq 'git[[:space:]]+commit([^[:alnum:]_-]|$).*--no-verify|--no-verify.*git[[:space:]]+commit' && block 'git commit --no-verify bypasses project policy'
printf '%s\n' "$command_scan" | grep -Eq 'git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]].*-(fdx|xdf|dfx)' && block 'destructive git reset/clean requires explicit user intent'
printf '%s\n' "$command_scan" | grep -Eq 'git[[:space:]]+(checkout[[:space:]]+-b|switch[[:space:]]+-c|branch)[[:space:]]+(codex|agent|gpt|claude|ai)/' && block 'branch names must describe human intent, not the implementation agent or model'
unsafe_recursive_removal="$(printf '%s\n' "$command_text" | python3 -c '
import os
import pathlib
import posixpath
import shlex
import sys
import tempfile

text = sys.stdin.read().strip()
thread_id = os.environ.get("CODEX_THREAD_ID", "")
temp_roots = {pathlib.PurePosixPath(posixpath.normpath(value)) for value in (tempfile.gettempdir(), "/tmp", "/private/tmp")}
separators = {";", "&&", "&", "||", "|", "(", ")"}
redirections = {"<", ">", ">>", "<<"}

def tokenized(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|<>()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)

def owned_target(target):
    if not thread_id or not target.startswith("/") or ".." in pathlib.PurePosixPath(target).parts:
        return False
    if any(character in target for character in "$`*?[]{}~"):
        return False
    normalized = pathlib.PurePosixPath(posixpath.normpath(target))
    if ".git" in normalized.parts:
        return False
    for root in temp_roots:
        try:
            relative = normalized.relative_to(root)
        except ValueError:
            continue
        if relative.parts and (relative.parts[0] == f"codex-{thread_id}" or relative.parts[0].startswith(f"codex-{thread_id}-")):
            return True
    return False

def unsafe(command):
    try:
        tokens = tokenized(command)
    except ValueError:
        return "unparseable shell command"
    start = 0
    while start < len(tokens):
        while start < len(tokens) and tokens[start] in separators:
            start += 1
        end = start
        while end < len(tokens) and tokens[end] not in separators:
            end += 1
        segment = tokens[start:end]
        start = end + 1
        while segment and "=" in segment[0] and not segment[0].startswith("="):
            segment.pop(0)
        if not segment:
            continue
        executable = pathlib.PurePosixPath(segment[0]).name
        if executable in {"bash", "sh", "zsh"} and "-c" in segment:
            index = segment.index("-c")
            if index + 1 >= len(segment):
                return "shell -c command is missing"
            nested = unsafe(segment[index + 1])
            if nested:
                return nested
            continue
        if executable in {"eval", "trap"} and len(segment) > 1:
            nested = unsafe(" ".join(segment[1:]))
            if nested:
                return nested
            continue
        if executable != "rm":
            continue
        args = segment[1:]
        if any(any(marker in arg for marker in ("$", "`", "*", "?", "[", "]", "{", "}")) for arg in args):
            return "dynamic rm arguments cannot prove an exact target"
        option_letters = "".join(arg[1:] for arg in args if arg.startswith("-") and not arg.startswith("--"))
        long_options = {arg.split("=", 1)[0] for arg in args if arg.startswith("--")}
        recursive = "r" in option_letters.lower() or "--recursive" in long_options
        force = "f" in option_letters.lower() or "--force" in long_options
        if not (recursive and force):
            continue
        options_done = False
        targets = []
        for arg in args:
            if arg in redirections:
                break
            if not options_done and arg == "--":
                options_done = True
            elif options_done or not arg.startswith("-"):
                targets.append(arg)
        if not targets or not all(owned_target(target) for target in targets):
            return "recursive forced removal lacks exact current-task ownership"
    return ""

reason = unsafe(text)
if reason:
    print(reason)
    raise SystemExit(2)
')" || block "unproven recursive forced removal: $unsafe_recursive_removal"
printf '%s\n' "$command_scan" | grep -Eq 'chmod[[:space:]]+-r[[:space:]]+777|curl[^|]*\|[[:space:]]*(sh|bash)|bash[[:space:]]+<\(curl' && block 'dangerous shell command pattern detected'
# Waiting efficiency is evaluated from observed task evidence, not shell syntax.
exit 0
