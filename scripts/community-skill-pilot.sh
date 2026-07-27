#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/skills/community-pilot.tsv"

usage() {
  printf 'usage: community-skill-pilot.sh list | verify | validate SKILL_DIRECTORY | fetch ID DESTINATION\n'
}

lookup() {
  awk -F '\t' -v id="$1" 'NR > 1 && $1 == id { print; found=1 } END { if (!found) exit 1 }' "$MANIFEST"
}

fetch_source() {
  repository="$1"
  commit="$2"
  checkout_dir="$3"
  git init -q "$checkout_dir"
  git -C "$checkout_dir" remote add origin "$repository"
  git -C "$checkout_dir" fetch -q --depth 1 origin "$commit"
  git -C "$checkout_dir" checkout -q --detach FETCH_HEAD
  actual="$(git -C "$checkout_dir" rev-parse HEAD)"
  [ "$actual" = "$commit" ] || { printf 'commit mismatch: expected %s, got %s\n' "$commit" "$actual" >&2; exit 1; }
}

validate_skill() {
  skill_dir="$1"
  [ -f "$skill_dir/SKILL.md" ] || { printf 'missing SKILL.md: %s\n' "$skill_dir" >&2; return 1; }
  awk 'NR == 1 && $0 == "---" { front=1; next } front && $0 == "---" { exit } front { print }' "$skill_dir/SKILL.md" | grep -q '^name: ' || return 1
  awk 'NR == 1 && $0 == "---" { front=1; next } front && $0 == "---" { exit } front { print }' "$skill_dir/SKILL.md" | grep -q '^description:' || return 1
  unsafe_pattern='find /tmp.*rm -rf|pkill -f|kill \$\(lsof|curl[^|]*\|[[:space:]]*(sh|bash)|wget[^|]*\|[[:space:]]*(sh|bash)|chmod[[:space:]]+(-R[[:space:]]+)?777|sudo[[:space:]]+(rm|sh|bash)'
  unsafe_matches="$(find "$skill_dir" -type f -print0 | xargs -0 grep -IEn "$unsafe_pattern" 2>/dev/null || true)"
  if [ -n "$unsafe_matches" ]; then
    printf 'unsafe command pattern requires manual review in %s:\n%s\n' "$skill_dir" "$unsafe_matches" >&2
    return 1
  fi
  if find "$skill_dir" -type l -print -quit | grep -q .; then
    printf 'symlink requires manual review in %s\n' "$skill_dir" >&2
    return 1
  fi
}

license_present() {
  checkout_dir="$1"
  skill_dir="$2"
  expected="$3"
  case "$expected" in
    UNVERIFIED) return 1 ;;
    MIT) pattern='MIT License' ;;
    Apache-2.0) pattern='Apache License' ;;
    *) return 1 ;;
  esac
  find "$skill_dir" "$checkout_dir" -maxdepth 2 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' \) -print0 2>/dev/null \
    | xargs -0 grep -Il "$pattern" 2>/dev/null | grep -q .
}

command_name="${1:-}"
case "$command_name" in
  list)
    column -t -s $'\t' "$MANIFEST"
    ;;
  verify)
    failures=0
    while IFS=$'\t' read -r id repository commit skill_path license status local_scope evaluated_on rationale; do
      checkout_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-community-skill.XXXXXX")"
      if fetch_source "$repository" "$commit" "$checkout_dir" && validate_skill "$checkout_dir/$skill_path" \
        && { license_present "$checkout_dir" "$checkout_dir/$skill_path" "$license" || [[ "$status" = hold-* || "$status" = reject-* ]]; }; then
        printf 'PASS %s %s license=%s status=%s evaluated=%s\n' "$id" "$commit" "$license" "$status" "$evaluated_on"
      else
        printf 'FAIL %s\n' "$id" >&2
        failures=$((failures + 1))
      fi
      rm -rf "$checkout_dir"
    done < <(tail -n +2 "$MANIFEST")
    [ "$failures" -eq 0 ]
    ;;
  validate)
    skill_dir="${2:-}"
    [ -n "$skill_dir" ] || { usage >&2; exit 1; }
    validate_skill "$skill_dir"
    printf 'validated %s\n' "$skill_dir"
    ;;
  fetch)
    id="${2:-}"
    destination="${3:-}"
    [ -n "$id" ] && [ -n "$destination" ] || { usage >&2; exit 1; }
    [ ! -e "$destination" ] || { printf 'destination already exists: %s\n' "$destination" >&2; exit 1; }
    row="$(lookup "$id")" || { printf 'unknown pilot id: %s\n' "$id" >&2; exit 1; }
    IFS=$'\t' read -r _ repository commit skill_path license status local_scope evaluated_on rationale <<< "$row"
    checkout_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-community-skill.XXXXXX")"
    trap 'rm -rf "$checkout_dir"' EXIT
    fetch_source "$repository" "$commit" "$checkout_dir"
    validate_skill "$checkout_dir/$skill_path"
    mkdir -p "$(dirname "$destination")"
    cp -R "$checkout_dir/$skill_path" "$destination"
    license_file="$(find "$checkout_dir/$skill_path" "$checkout_dir" -maxdepth 2 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' \) -print -quit 2>/dev/null || true)"
    [ -z "$license_file" ] || cp "$license_file" "$destination/UPSTREAM-LICENSE"
    printf 'repository=%s\ncommit=%s\nsource=%s\nlicense=%s\nstatus=%s\nlocal_scope=%s\nevaluated_on=%s\nrationale=%s\n' \
      "$repository" "$commit" "$skill_path" "$license" "$status" "$local_scope" "$evaluated_on" "$rationale" > "$destination/.codex-community-source"
    printf 'materialized %s at %s; review diff and license before installation\n' "$id" "$destination"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
