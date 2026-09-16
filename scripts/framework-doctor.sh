#!/bin/bash
set -euo pipefail

export PYTHONDONTWRITEBYTECODE=1
for dependency in python3 git; do
  command -v "$dependency" >/dev/null 2>&1 || { printf 'Required dependency missing: %s; install it using your OS package manager.\n' "$dependency" >&2; exit 1; }
done
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' || {
  printf 'Python 3.11 or newer must be available as python3 on PATH; select a compatible interpreter and rerun this command.\n' >&2
  exit 1
}
ROOT="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().parent.parent)' "$0")"
FRAMEWORK_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
USER_SKILLS_ROOT="${CODEX_SKILLS_HOME:-$HOME/.agents/skills}"
FRAMEWORK_CODEX_HOME="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve(strict=False))' "$FRAMEWORK_CODEX_HOME")"
USER_SKILLS_ROOT="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve(strict=False))' "$USER_SKILLS_ROOT")"
LEGACY_CORE="$FRAMEWORK_CODEX_HOME/skills/codex-framework-core"
LEGACY_PACKS="$FRAMEWORK_CODEX_HOME/skills/codex-framework-packs"
INSTALL_STATE="$USER_SKILLS_ROOT/.codex-framework-install.json"
LINK_STATE="$FRAMEWORK_CODEX_HOME/frameworks/.codex-framework-links.json"
RUN_NATIVE=1
CHECK_EVIDENCE=0
CHECK_PROMPT_INPUT=1
failures=0

usage() {
  printf 'usage: framework-doctor.sh [--framework-only] [--evidence] [--skip-evidence] [--skip-prompt-input]\n'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --framework-only) RUN_NATIVE=0 ;;
    --evidence) CHECK_EVIDENCE=1 ;;
    --skip-evidence) CHECK_EVIDENCE=0 ;;
    --skip-prompt-input) CHECK_PROMPT_INPUT=0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
  esac
  shift
done

ok() { printf 'ok framework doctor: %s\n' "$1"; }
fail() { printf 'FAIL framework doctor: %s\n' "$1" >&2; failures=$((failures + 1)); }
note() { printf 'note framework doctor: %s\n' "$1"; }

# Diagnose the installed source even when invoked from a repair checkout.
installed_root="$FRAMEWORK_CODEX_HOME/frameworks/codex-framework"
if [ -L "$installed_root" ] && [ -d "$installed_root" ]; then
  ROOT="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$installed_root")"
elif [ -L "$installed_root" ] || [ ! -e "$installed_root" ]; then
  fail "installation source missing: $installed_root"
  note 'recovery: run bash scripts/setup.sh from a clean detached framework checkout; default installation creates an independent durable release clone. Development installs require their source checkout to remain available.'
  note 'source identity: unavailable; certification: unverified; native runtime: not checked'
  exit 1
fi
note "installation source: $ROOT"
resolve_path() { python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$1"; }

native_json="$(mktemp "${TMPDIR:-/tmp}/codex-framework-native-doctor.XXXXXX")"
trap 'rm -f "$native_json"' EXIT

if [ -e "$LEGACY_CORE" ] || [ -L "$LEGACY_CORE" ] || [ -e "$LEGACY_PACKS" ] || [ -L "$LEGACY_PACKS" ]; then
  fail "legacy framework skill namespaces remain under $FRAMEWORK_CODEX_HOME/skills"
else
  ok 'legacy framework skill namespaces are absent'
fi

for profile in architect reviewer tester; do
  installed="$FRAMEWORK_CODEX_HOME/agents/codex-framework-$profile.toml"
  source="$ROOT/.codex/agents/$profile.toml"
  [ -f "$installed" ] && [ ! -L "$installed" ] \
    || { fail "installed profile is missing or still symlinked: $profile"; continue; }
  cmp -s "$installed" "$source" || fail "installed profile is stale: $profile"
done
rule_link="$FRAMEWORK_CODEX_HOME/rules/codex-framework-safety.rules"
if [ -L "$rule_link" ] && [ "$(resolve_path "$rule_link")" = "$ROOT/.codex/rules/safety.rules" ]; then
  ok 'profile copies and safety rule match this framework checkout'
else
  fail 'installed safety rule is missing or points to another checkout'
fi

for mapping in \
  "$FRAMEWORK_CODEX_HOME/frameworks/codex-framework|$ROOT" \
  "$FRAMEWORK_CODEX_HOME/bin/codex-framework-stack-context|$ROOT/scripts/framework-stack-context.py" \
  "$FRAMEWORK_CODEX_HOME/bin/codex-framework-doctor|$ROOT/scripts/framework-doctor.sh"; do
  link="${mapping%%|*}"
  target="${mapping#*|}"
  if [ ! -L "$link" ] || [ "$(resolve_path "$link" 2>/dev/null || true)" != "$target" ]; then
    fail "missing or stale framework install link: $link"
  fi
done
if python3 "$ROOT/scripts/framework-link-install.py" --check \
  --state "$LINK_STATE" \
  --source-root "$ROOT" \
  --guidance "$FRAMEWORK_CODEX_HOME/AGENTS.md=$ROOT/templates/global/AGENTS.md" \
  --link "$FRAMEWORK_CODEX_HOME/frameworks/codex-framework=$ROOT" \
  --link "$FRAMEWORK_CODEX_HOME/bin/codex-framework-stack-context=$ROOT/scripts/framework-stack-context.py" \
  --link "$FRAMEWORK_CODEX_HOME/bin/codex-framework-doctor=$ROOT/scripts/framework-doctor.sh" \
  --file "$FRAMEWORK_CODEX_HOME/agents/codex-framework-architect.toml=$ROOT/.codex/agents/architect.toml" \
  --file "$FRAMEWORK_CODEX_HOME/agents/codex-framework-reviewer.toml=$ROOT/.codex/agents/reviewer.toml" \
  --file "$FRAMEWORK_CODEX_HOME/agents/codex-framework-tester.toml=$ROOT/.codex/agents/tester.toml" \
  --link "$FRAMEWORK_CODEX_HOME/rules/codex-framework-safety.rules=$ROOT/.codex/rules/safety.rules"; then
  ok 'auxiliary framework links match explicit ownership state'
else
  fail "auxiliary framework link ownership is stale or malformed: $LINK_STATE"
fi

guidance="$FRAMEWORK_CODEX_HOME/AGENTS.md"
if [ -L "$guidance" ] && [ "$(resolve_path "$guidance" 2>/dev/null || true)" = "$ROOT/templates/global/AGENTS.md" ]; then
  ok 'global guidance is managed by this framework checkout'
elif [ -e "$guidance" ]; then
  note "preserved user-owned global guidance: $guidance"
else
  fail "missing global guidance: $guidance"
fi

if [ -f "$INSTALL_STATE" ]; then
  if python3 - "$INSTALL_STATE" "$ROOT" "$USER_SKILLS_ROOT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

state_path, root_text, skills_root_text = sys.argv[1:]
root = Path(root_text)
skills_root = Path(skills_root_text)
state = json.loads(Path(state_path).read_text())
assert state.get("schemaVersion") == 1
assert state.get("sourceRoot") == str(root)
assert state.get("skillsRoot") == str(skills_root)
packs = state.get("packs")
assert isinstance(packs, list) and all(isinstance(item, str) for item in packs)
manifests = [root / "skills" / "core.txt"]
expected = {}
for line in manifests[0].read_text().splitlines():
    line = line.strip()
    if line and not line.startswith("#"):
        expected[line] = str((root / "skills" / line).resolve())
for pack in packs:
    manifest = root / "skills" / "packs" / f"{pack}.txt"
    manifests.append(manifest)
    for line in manifest.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            expected[line] = str((root / "skills" / line).resolve())
assert state.get("managed") == dict(sorted(expected.items()))
digest = hashlib.sha256()
for manifest in manifests:
    digest.update(manifest.relative_to(root).as_posix().encode() + b"\0" + manifest.read_bytes() + b"\0")
assert state.get("manifestDigest") == digest.hexdigest()
for skill, target in expected.items():
    path = skills_root / skill
    assert path.is_symlink() and path.resolve(strict=False) == Path(target)
PY
  then
    ok 'canonical USER skills and intentionally global packs match install state'
  else
    fail "install state is stale or malformed: $INSTALL_STATE"
  fi
else
  fail "missing install state: $INSTALL_STATE"
fi

note 'installation and source identity checked; project validation belongs to framework-health.sh'

if [ "$CHECK_PROMPT_INPUT" -eq 1 ]; then
  prompt_json="$(mktemp "${TMPDIR:-/tmp}/codex-framework-prompt-input.XXXXXX")"
  if codex debug prompt-input 'Framework doctor metadata check' > "$prompt_json" \
  && python3 - "$prompt_json" <<'PY'
import json
import sys

items = json.load(open(sys.argv[1]))
text = "\n".join(
    block.get("text", block.get("input_text", ""))
    for item in items
    for block in item.get("content", [])
    if isinstance(block, dict)
)
assert text.count("- framework-management:") == 1
lower = text.lower()
assert "some skills were omitted" not in lower
assert "skills list was truncated" not in lower
for retired in (
    "framework-orchestration-audit",
    "fullstack-nextjs-implement",
    "fullstack-nextjs-review",
    "fullstack-nextjs-test",
    "process-hygiene",
):
    assert f"- {retired}:" not in text
PY
  then
    ok 'native prompt metadata contains one core skill and no retired framework skills'
  else
    fail 'native prompt metadata is stale, duplicated, or unavailable'
  fi
  rm -f "$prompt_json"
fi

if [ "$CHECK_EVIDENCE" -eq 0 ]; then
  note 'certification: not checked (use --evidence for release certification)'
fi
if [ "$RUN_NATIVE" -eq 0 ]; then
  note 'native runtime: not checked (--framework-only)'
fi
if [ "$CHECK_EVIDENCE" -eq 1 ]; then
  if python3 "$ROOT/scripts/framework-release-evidence.py" check; then
    ok 'certified release evidence matches the committed source digest'
  else
    fail 'certified release evidence is missing or stale even if linked development files are effective'
  fi
fi

if [ "$RUN_NATIVE" -eq 1 ]; then
  set +e
  codex doctor --summary --json > "$native_json"
  native_status=$?
  set -e
  if python3 "$ROOT/scripts/framework-doctor-native.py" "$native_json" "$native_status"
  then
    ok 'native codex doctor has no actionable failures'
  else
    fail 'native codex doctor reported an actionable failure'
  fi
fi

printf 'framework doctor: %d failures\n' "$failures"
[ "$failures" -eq 0 ]
