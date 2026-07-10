#!/bin/bash
set -euo pipefail

payload="$(cat)"
command -v jq >/dev/null 2>&1 || { printf 'Codex Framework hook guard: jq is required\n' >&2; exit 2; }

tool="$(printf '%s' "$payload" | jq -r '.tool // .tool_name // .toolName // .name // .payload.tool // .event.tool // empty' 2>/dev/null | head -n 1)"
command_text="$(printf '%s' "$payload" | jq -r '[.. | objects | to_entries[] | select(.key | test("^(cmd|command|shell_command|script)$")) | .value | if type == "array" then join(" ") else tostring end] | map(select(. != "null" and . != "")) | join("\\n")' 2>/dev/null)"
tool_lc="$(printf '%s' "$tool" | tr '[:upper:]' '[:lower:]')"
command_scan="$(printf '%s' "$command_text" | tr '[:upper:]' '[:lower:]' | tr -d "'\\\"")"

block() {
  printf 'Codex Framework hook guard: %s\n' "$1" >&2
  exit 2
}

creates_tool_revealing_branch() {
  printf '%s\n' "$1" | awk '
    function is_codex_branch(value) { return value ~ /^codex\// }
    function scan_create_flag(start, end,    j) {
      for (j = start; j <= end; j++) {
        if (($j == "-b" || $j == "-c" || $j == "--create" || $j == "--branch") && is_codex_branch($(j + 1))) return 1
      }
      return 0
    }
    {
      for (i = 1; i <= NF; i++) {
        if ($i != "git") continue
        if ($(i + 1) == "checkout" || $(i + 1) == "switch") if (scan_create_flag(i + 2, NF)) found = 1
        if ($(i + 1) == "worktree" && $(i + 2) == "add") if (scan_create_flag(i + 3, NF)) found = 1
        if ($(i + 1) == "branch") {
          rename = 0; first_name = ""; last_name = ""
          for (j = i + 2; j <= NF; j++) {
            if ($j == "-m") { rename = 1; continue }
            if ($j ~ /^-/) continue
            if (first_name == "") first_name = $j
            last_name = $j
          }
          if ((rename && is_codex_branch(last_name)) || (!rename && is_codex_branch(first_name))) found = 1
        }
      }
    }
    END { exit found ? 0 : 1 }
  '
}

case "$tool_lc" in
  *bash*|*shell*|*exec*|*terminal*|"")
    printf '%s\n' "$command_scan" | grep -Eq 'git[[:space:]]+commit([^[:alnum:]_-]|$).*--no-verify|--no-verify.*git[[:space:]]+commit' && block 'git commit --no-verify bypasses project policy'
    printf '%s\n' "$command_scan" | grep -Eq 'git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]].*-fdx' && block 'destructive git reset/clean requires explicit user intent'
    creates_tool_revealing_branch "$command_scan" && block 'tool-revealing codex/* branch creation is blocked; use feat/, fix/, chore/, docs/, or test/'
    printf '%s\n' "$command_scan" | grep -Eq 'rm[[:space:]].*-rf[[:space:]]+(/|\.git|~)|chmod[[:space:]]+-r[[:space:]]+777|curl[^|]*\|[[:space:]]*(sh|bash)|bash[[:space:]]+<\(curl' && block 'dangerous shell command pattern detected'
    ;;
esac

exit 0
