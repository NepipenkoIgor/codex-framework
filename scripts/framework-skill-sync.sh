#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="sync"
PROJECT="$PWD"

usage() {
  printf 'usage: framework-skill-sync.sh [--check] [project-root]\n'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
    *) PROJECT="$1" ;;
  esac
  shift
done

PROJECT="$(cd "$PROJECT" && pwd)"
MANIFEST="$PROJECT/.codex/skill-packs.txt"
SKILLS_ROOT="$PROJECT/.agents/skills"
[ -f "$MANIFEST" ] || { printf 'missing project pack manifest: %s\n' "$MANIFEST" >&2; exit 1; }

if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
  git_dir="$(git -C "$PROJECT" rev-parse --git-dir)"
  case "$git_dir" in /*) ;; *) git_dir="$PROJECT/$git_dir" ;; esac
  STATE="$git_dir/codex-framework/project-skills.json"
else
  STATE="$PROJECT/.codex/project-skills.local.json"
fi

PACKS=""
while IFS= read -r pack; do
  case "$pack" in ''|'#'*) continue ;; esac
  case "$pack" in
    *[!a-z0-9-]*|-*|*-) printf 'invalid pack manifest entry (one lowercase name per line): %s\n' "$pack" >&2; exit 1 ;;
  esac
  PACKS="$PACKS $pack"
done < "$MANIFEST"

if [ "$MODE" = "sync" ]; then
  args=(--root "$ROOT" --skills-root "$SKILLS_ROOT" --state "$STATE")
  for pack in $PACKS; do args+=(--pack "$pack"); done
  python3 "$ROOT/scripts/framework-install.py" "${args[@]}"

  if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
    exclude="$(git -C "$PROJECT" rev-parse --git-path info/exclude)"
    case "$exclude" in /*) ;; *) exclude="$PROJECT/$exclude" ;; esac
    mkdir -p "$(dirname "$exclude")"
    touch "$exclude"
    temporary="$(mktemp "${TMPDIR:-/tmp}/codex-framework-exclude.XXXXXX")"
    trap 'rm -f "$temporary"' EXIT
    awk '
      $0 == "# codex-framework managed skills begin" { skip=1; next }
      $0 == "# codex-framework managed skills end" { skip=0; next }
      !skip { print }
    ' "$exclude" > "$temporary"
    {
      cat "$temporary"
      printf '%s\n' '# codex-framework managed skills begin'
      python3 - "$STATE" <<'PY'
import json
import sys
from pathlib import Path
state = json.loads(Path(sys.argv[1]).read_text())
for name in sorted(state["managed"]):
    print(f"/.agents/skills/{name}")
PY
      printf '%s\n' '# codex-framework managed skills end'
    } > "$exclude"
  fi
fi

python3 - "$ROOT" "$SKILLS_ROOT" "$STATE" "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
skills_root = Path(sys.argv[2]).resolve()
state_path = Path(sys.argv[3])
manifest_path = Path(sys.argv[4])
packs = sorted({
    line.strip()
    for line in manifest_path.read_text().splitlines()
    if line.strip() and not line.lstrip().startswith("#")
})
if not state_path.is_file():
    raise SystemExit(f"missing project skill state: {state_path}")
state = json.loads(state_path.read_text())
if state.get("sourceRoot") != str(root) or state.get("packs") != packs:
    raise SystemExit("project skill state does not match the source root or pack manifest")
expected = {}
for pack in packs:
    manifest = root / "skills" / "packs" / f"{pack}.txt"
    if not manifest.is_file():
        raise SystemExit(f"unknown project skill pack: {pack}")
    for line in manifest.read_text().splitlines():
        name = line.strip()
        if name and not name.startswith("#"):
            expected[name] = str((root / "skills" / name).resolve())
if state.get("managed") != dict(sorted(expected.items())):
    raise SystemExit("project skill state does not match expanded manifests")
for name, target in expected.items():
    path = skills_root / name
    if not path.is_symlink() or path.resolve(strict=False) != Path(target):
        raise SystemExit(f"missing, dangling, or wrong project skill link: {path}")
print(f"project skill packs are synchronized: {len(expected)} skills")
PY
