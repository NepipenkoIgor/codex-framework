#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0
total=0

check() {
  local label="$1"
  shift
  total=$((total + 1))
  if "$@"; then
    printf 'ok %02d %s\n' "$total" "$label"
  else
    printf 'not ok %02d %s\n' "$total" "$label"
    failures=$((failures + 1))
  fi
}

bootstrap_preserves_native_config() {
  local fixture before after
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/codex-bootstrap-native.XXXXXX")"
  mkdir -p "$fixture/.codex"
  printf '%s\n' '[agents]' 'max_concurrent_threads_per_session = 2' > "$fixture/.codex/config.toml"
  before="$(shasum -a 256 "$fixture/.codex/config.toml")"
  bash "$ROOT/scripts/bootstrap-project.sh" "$fixture" >/dev/null || return 1
  after="$(shasum -a 256 "$fixture/.codex/config.toml")"
  [ "$before" = "$after" ] && [ ! -e "$fixture/.codex/hooks" ]
  local result=$?
  rm -rf -- "$fixture"
  return "$result"
}

native_agent_valid() {
  local name="$1" file="$ROOT/.codex/agents/$1.toml"
  [ -f "$file" ] || return 1
  grep -q "^name = \"$name\"$" "$file" \
    && grep -q '^description = ' "$file" \
    && grep -q '^developer_instructions = ' "$file"
}

reasoning_overrides_are_bounded() {
  grep -q '^model_reasoning_effort = "high"$' "$ROOT/.codex/agents/architect.toml" \
    && grep -q '^model_reasoning_effort = "high"$' "$ROOT/.codex/agents/reviewer.toml" \
    && ! grep -q '^model_reasoning_effort = ' "$ROOT/.codex/agents/tester.toml"
}

reviewer_safety_contract() {
  grep -q '^sandbox_mode = "read-only"$' "$ROOT/.codex/agents/reviewer.toml" \
    && grep -q 'Do not edit files, recursively delegate' "$ROOT/.codex/agents/reviewer.toml"
}

project_config_is_source_owned() {
  [ -f "$ROOT/.codex/config.toml" ] || return 1
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$ROOT" check-ignore -q .codex/config.toml; then
      return 1
    fi
  fi
}

setup_collision_safety() {
  local fixture case_dir skill_before skill_after guidance_before guidance_after state_before state_after external_before external_after
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-setup-eval.XXXXXX")"
  for kind in nonempty empty symlink; do
    case_dir="$fixture/$kind"
    mkdir -p "$case_dir/.agents/skills"
    case "$kind" in
      nonempty) printf '%s\n' 'user-owned guidance' > "$case_dir/AGENTS.md" ;;
      empty) : > "$case_dir/AGENTS.md" ;;
      symlink)
        printf '%s\n' 'user-owned linked guidance' > "$case_dir/guidance-source.md"
        ln -s "$case_dir/guidance-source.md" "$case_dir/AGENTS.md"
        ;;
    esac
    if [ -L "$case_dir/AGENTS.md" ]; then
      guidance_before="link:$(readlink "$case_dir/AGENTS.md")"
    else
      guidance_before="file:$(shasum -a 256 "$case_dir/AGENTS.md")"
    fi
    CODEX_HOME="$case_dir/.codex" CODEX_SKILLS_HOME="$case_dir/.agents/skills" bash "$ROOT/scripts/setup.sh" --development --pack frontend >/dev/null
    if [ -L "$case_dir/AGENTS.md" ]; then
      guidance_after="link:$(readlink "$case_dir/AGENTS.md")"
    else
      guidance_after="file:$(shasum -a 256 "$case_dir/AGENTS.md")"
    fi
    [ "$guidance_before" = "$guidance_after" ] || return 1
    [ -L "$case_dir/.agents/skills/framework-management" ] || return 1
    for profile in architect reviewer tester; do
      [ -f "$case_dir/.codex/agents/codex-framework-$profile.toml" ] || return 1
      [ ! -L "$case_dir/.codex/agents/codex-framework-$profile.toml" ] || return 1
      cmp -s "$case_dir/.codex/agents/codex-framework-$profile.toml" "$ROOT/.codex/agents/$profile.toml" || return 1
    done
    state_before="$(shasum -a 256 "$case_dir/.agents/skills/.codex-framework-install.json")"
    CODEX_HOME="$case_dir/.codex" CODEX_SKILLS_HOME="$case_dir/.agents/skills" bash "$ROOT/scripts/setup.sh" --development --pack frontend >/dev/null
    state_after="$(shasum -a 256 "$case_dir/.agents/skills/.codex-framework-install.json")"
    [ "$state_before" = "$state_after" ] || return 1
  done

  case_dir="$fixture/collision"
  mkdir -p "$case_dir/.agents/skills/framework-management"
  printf '%s\n' 'user-owned-skill' > "$case_dir/.agents/skills/framework-management/SKILL.md"
  skill_before="$(shasum -a 256 "$case_dir/.agents/skills/framework-management/SKILL.md")"
  if CODEX_HOME="$case_dir/.codex" CODEX_SKILLS_HOME="$case_dir/.agents/skills" bash "$ROOT/scripts/setup.sh" --development >/dev/null 2>&1; then
    return 1
  fi
  skill_after="$(shasum -a 256 "$case_dir/.agents/skills/framework-management/SKILL.md")"
  [ "$skill_before" = "$skill_after" ] || return 1
  [ ! -e "$case_dir/.agents/skills/.codex-framework-install.json" ] || return 1

  case_dir="$fixture/same-target-collision"
  mkdir -p "$case_dir/.agents/skills"
  ln -s "$ROOT/skills/framework-management" "$case_dir/.agents/skills/framework-management"
  if CODEX_HOME="$case_dir/.codex" CODEX_SKILLS_HOME="$case_dir/.agents/skills" bash "$ROOT/scripts/setup.sh" --development >/dev/null 2>&1; then
    return 1
  fi
  [ "$(readlink "$case_dir/.agents/skills/framework-management")" = "$ROOT/skills/framework-management" ] || return 1
  [ ! -e "$case_dir/.agents/skills/.codex-framework-install.json" ] || return 1

  case_dir="$fixture/auxiliary-collision"
  mkdir -p "$case_dir/.codex/agents" "$case_dir/.agents/skills"
  printf '%s\n' 'user-owned-reviewer' > "$case_dir/user-reviewer.toml"
  ln -s "$case_dir/user-reviewer.toml" "$case_dir/.codex/agents/codex-framework-reviewer.toml"
  if CODEX_HOME="$case_dir/.codex" CODEX_SKILLS_HOME="$case_dir/.agents/skills" bash "$ROOT/scripts/setup.sh" --development >/dev/null 2>&1; then
    return 1
  fi
  [ "$(readlink "$case_dir/.codex/agents/codex-framework-reviewer.toml")" = "$case_dir/user-reviewer.toml" ] || return 1
  [ ! -e "$case_dir/.agents/skills/.codex-framework-install.json" ] || return 1

  case_dir="$fixture/legacy"
  mkdir -p "$case_dir/.codex/skills/codex-framework-core" "$case_dir/.codex/skills/codex-framework-packs/frontend"
  ln -s "$ROOT/skills/framework-management" "$case_dir/.codex/skills/codex-framework-core/framework-management"
  ln -s "$ROOT/skills/retired-skill" "$case_dir/.codex/skills/codex-framework-core/retired-skill"
  ln -s "$ROOT/skills/frontend-implement" "$case_dir/.codex/skills/codex-framework-packs/frontend/frontend-implement"
  CODEX_HOME="$case_dir/.codex" CODEX_SKILLS_HOME="$case_dir/.agents/skills" bash "$ROOT/scripts/setup.sh" --development >/dev/null
  [ ! -e "$case_dir/.codex/skills/codex-framework-core" ] || return 1
  [ ! -e "$case_dir/.codex/skills/codex-framework-packs" ] || return 1

  case_dir="$fixture/legacy-root-symlink"
  mkdir -p "$case_dir/.codex/skills" "$case_dir/.agents/skills" "$case_dir/external"
  ln -s "$ROOT/skills/framework-management" "$case_dir/external/framework-management"
  printf '%s\n' 'user-owned' > "$case_dir/external/user.txt"
  external_before="$(tar -cf - -C "$case_dir/external" . | shasum -a 256)"
  ln -s "$case_dir/external" "$case_dir/.codex/skills/codex-framework-core"
  if CODEX_HOME="$case_dir/.codex" CODEX_SKILLS_HOME="$case_dir/.agents/skills" bash "$ROOT/scripts/setup.sh" --development >/dev/null 2>&1; then
    return 1
  fi
  external_after="$(tar -cf - -C "$case_dir/external" . | shasum -a 256)"
  [ "$external_before" = "$external_after" ] || return 1
  [ -L "$case_dir/.codex/skills/codex-framework-core" ] || return 1
  [ ! -e "$case_dir/.agents/skills/.codex-framework-install.json" ] || return 1
  rm -rf -- "$fixture"
}

managed_profile_copy_safety() {
  local fixture state source destination before after external legacy_target
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-profile-copy.XXXXXX")"
  state="$fixture/state.json"
  source="$fixture/reviewer-source.toml"
  destination="$fixture/agents/reviewer.toml"
  mkdir -p "$fixture/agents"

  printf '%s\n' 'name = "reviewer-v1"' > "$source"
  python3 "$ROOT/scripts/framework-link-install.py" \
    --state "$state" --file "$destination=$source" >/dev/null || return 1
  [ -f "$destination" ] && [ ! -L "$destination" ] && cmp -s "$destination" "$source" || return 1

  printf '%s\n' 'name = "reviewer-v2"' > "$source"
  python3 "$ROOT/scripts/framework-link-install.py" \
    --state "$state" --file "$destination=$source" >/dev/null || return 1
  cmp -s "$destination" "$source" || return 1

  printf '%s\n' 'user-owned-change' > "$destination"
  printf '%s\n' 'name = "reviewer-v3"' > "$source"
  before="$(shasum -a 256 "$destination" "$state")"
  if python3 "$ROOT/scripts/framework-link-install.py" \
    --state "$state" --preflight --file "$destination=$source" >/dev/null 2>&1; then
    return 1
  fi
  after="$(shasum -a 256 "$destination" "$state")"
  [ "$before" = "$after" ] || return 1

  external="$fixture/user-owned.txt"
  printf '%s\n' 'must-remain-unchanged' > "$external"
  ln -s "$external" "$destination.tmp.12345"
  mkdir "$destination.tmp.54321"
  ln -s "$external" "$fixture/.state.json.tmp.12345"
  printf '%s\n' 'name = "reviewer-v4"' > "$source"
  printf '%s\n' 'name = "reviewer-v3"' > "$destination"
  python3 - "$state" "$destination" "$source" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

state, destination, source = map(Path, sys.argv[1:])
content = destination.read_bytes()
state.write_text(json.dumps({
    "schemaVersion": 1,
    "managed": {},
    "managedFiles": {
        str(destination): {
            "source": str(source.resolve()),
            "sha256": hashlib.sha256(content).hexdigest(),
        },
    },
}) + "\n")
PY
  python3 "$ROOT/scripts/framework-link-install.py" \
    --state "$state" --file "$destination=$source" >/dev/null || return 1
  [ "$(cat "$external")" = 'must-remain-unchanged' ] || return 1
  [ -L "$destination.tmp.12345" ] && [ -d "$destination.tmp.54321" ] || return 1
  [ -f "$destination" ] && [ ! -L "$destination" ] && cmp -s "$destination" "$source" || return 1

  rm -rf -- "$fixture"
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-profile-migration.XXXXXX")"
  state="$fixture/state.json"
  source="$fixture/reviewer-source.toml"
  destination="$fixture/reviewer.toml"
  printf '%s\n' 'name = "reviewer"' > "$source"
  ln -s "$source" "$destination"
  legacy_target="$(readlink "$destination")"
  python3 - "$state" "$destination" "$source" <<'PY'
import json
import sys
from pathlib import Path

state, destination, source = map(Path, sys.argv[1:])
state.write_text(json.dumps({
    "schemaVersion": 1,
    "managed": {str(destination): str(source.resolve())},
}) + "\n")
PY
  chmod u-w "$fixture"
  if python3 "$ROOT/scripts/framework-link-install.py" \
    --state "$state" --file "$destination=$source" >/dev/null 2>&1; then
    chmod u+w "$fixture"
    return 1
  fi
  chmod u+w "$fixture"
  [ -L "$destination" ] && [ "$(readlink "$destination")" = "$legacy_target" ] || return 1
  python3 "$ROOT/scripts/framework-link-install.py" \
    --state "$state" --file "$destination=$source" >/dev/null || return 1
  [ -f "$destination" ] && [ ! -L "$destination" ] && cmp -s "$destination" "$source" || return 1
  rm -rf -- "$fixture"
}

project_pack_sync_safety() {
  local fixture project user_before user_after worktree
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-project-pack-eval.XXXXXX")"
  project="$fixture/project"
  mkdir -p "$project/.codex" "$project/.agents/skills/team-owned"
  git -C "$fixture" init -q project
  printf '%s\n' 'team-owned' > "$project/.agents/skills/team-owned/SKILL.md"
  user_before="$(shasum -a 256 "$project/.agents/skills/team-owned/SKILL.md")"
  printf '%s\n' frontend-frameworks > "$project/.codex/skill-packs.txt"
  bash "$ROOT/scripts/framework-skill-sync.sh" "$project" >/dev/null
  bash "$ROOT/scripts/framework-skill-sync.sh" --check "$project" >/dev/null
  [ -L "$project/.agents/skills/frontend-implement-react" ] || return 1

  printf '%s\n' fullstack > "$project/.codex/skill-packs.txt"
  bash "$ROOT/scripts/framework-skill-sync.sh" "$project" >/dev/null
  bash "$ROOT/scripts/framework-skill-sync.sh" --check "$project" >/dev/null
  [ ! -e "$project/.agents/skills/frontend-implement-react" ] || return 1
  user_after="$(shasum -a 256 "$project/.agents/skills/team-owned/SKILL.md")"
  [ "$user_before" = "$user_after" ] || return 1

  project="$fixture/collision"
  git -C "$fixture" init -q collision
  mkdir -p "$project/.codex" "$project/.agents/skills/nextjs-development"
  printf '%s\n' fullstack > "$project/.codex/skill-packs.txt"
  printf '%s\n' 'user-owned' > "$project/.agents/skills/nextjs-development/SKILL.md"
  user_before="$(shasum -a 256 "$project/.agents/skills/nextjs-development/SKILL.md")"
  if bash "$ROOT/scripts/framework-skill-sync.sh" "$project" >/dev/null 2>&1; then
    return 1
  fi
  user_after="$(shasum -a 256 "$project/.agents/skills/nextjs-development/SKILL.md")"
  [ "$user_before" = "$user_after" ] || return 1

  project="$fixture/malformed"
  git -C "$fixture" init -q malformed
  mkdir -p "$project/.codex"
  printf '%s\n' 'frontend fullstack' > "$project/.codex/skill-packs.txt"
  if bash "$ROOT/scripts/framework-skill-sync.sh" "$project" >/dev/null 2>&1; then
    return 1
  fi
  [ ! -e "$project/.agents/skills" ] || return 1
  [ ! -e "$project/.git/codex-framework/project-skills.json" ] || return 1

  project="$fixture/linked-source"
  worktree="$fixture/linked-worktree"
  git -C "$fixture" init -q linked-source
  git -C "$project" config user.email fixture@example.com
  git -C "$project" config user.name fixture
  mkdir -p "$project/.codex"
  printf '%s\n' '# fixture' > "$project/README.md"
  git -C "$project" add README.md
  git -C "$project" commit -qm initial
  git -C "$project" worktree add -q "$worktree"
  mkdir -p "$worktree/.codex"
  printf '%s\n' frontend > "$worktree/.codex/skill-packs.txt"
  bash "$ROOT/scripts/framework-skill-sync.sh" "$worktree" >/dev/null
  [ -z "$(git -C "$worktree" status --short --untracked-files=all -- .agents/skills)" ] || return 1
  rm -rf -- "$fixture"
}

visible_orchestration_contract() {
  local instructions="$1"
  grep -q '^## Visible orchestration$' "$instructions" \
    && grep -q 'Announce a subagent only after spawning it' "$instructions" \
    && grep -q 'profile — model / effort — bounded responsibility' "$instructions" \
    && grep -q 'Skills are workflows, not agents' "$instructions" \
    && grep -q 'Never manufacture plan files' "$instructions"
}

falsification_review_contract() {
  # Backticks below are literal Markdown contract text.
  # shellcheck disable=SC2016
  grep -q '^## Agent profiles and review$' "$ROOT/AGENTS.md" \
    && grep -q 'run exactly one independent read-only falsification pass' "$ROOT/AGENTS.md" \
    && grep -q 'no inherited conversation turns or prior-agent history' "$ROOT/AGENTS.md" \
    && grep -q 'only a neutral evidence bundle' "$ROOT/AGENTS.md" \
    && grep -q 'cannot prove the no-history boundary' "$ROOT/AGENTS.md" \
    && grep -q 'at most one revision cycle unless the user requests a deeper audit' "$ROOT/AGENTS.md" \
    && grep -q 'Act as an independent falsifier' "$ROOT/.codex/agents/reviewer.toml" \
    && grep -q 'fresh context with no prior conversation or agent history' "$ROOT/.codex/agents/reviewer.toml" \
    && grep -q 'report the independence contract as invalid instead of certifying' "$ROOT/.codex/agents/reviewer.toml" \
    && grep -q 'Every actionable finding must include severity, concrete evidence' "$ROOT/.codex/agents/reviewer.toml" \
    && grep -q 'no inherited conversation turns or prior-agent history' "$ROOT/templates/global/AGENTS.md" \
    && grep -q 'avoid recursive debate loops' "$ROOT/templates/global/AGENTS.md" \
    && python3 "$ROOT/scripts/framework-review-context-check.py"
}

interactive_development_contract() {
  local instructions="$ROOT/templates/global/AGENTS.md"
  grep -Eqi 'repository-native development server.*early|start or attach.*repository-native development server' "$instructions" \
    && grep -Eqi 'visible.*in-app Browser|in-app Browser.*visible' "$instructions" \
    && grep -Eqi 'reuse.*Browser binding|reuse the browser binding' "$instructions" \
    && grep -Eqi 'headless.*supplement|headless E2E.*supplement' "$instructions" \
    && grep -Eqi 'task-owned.*(tab|process|resource)' "$instructions" \
    && grep -Eqi 'separate worktrees.*,? ports.*,? (servers|development servers).*(tabs|Browser)' "$instructions" \
    && grep -Eqi 'visible repository-configured simulator, emulator, or device' "$instructions" \
    || return 1
  grep -q '^# Interactive development contract$' "$ROOT/docs/interactive-development.md" \
    && grep -q 'A missing, stale, or closed tab does not invalidate the browser' "$ROOT/docs/interactive-development.md" \
    && grep -q 'Never enumerate localhost tabs and close them broadly' "$ROOT/docs/interactive-development.md"
}

native_feature_adoption_contract() {
  local instructions="$ROOT/templates/global/AGENTS.md"
  grep -Eqi 'Scheduled tasks/automations' "$instructions" \
    && grep -Eqi 'recurring execution.*,? monitoring|monitoring.*,? reminders' "$instructions" \
    && grep -Eqi 'task names.*,? pins.*,? sections.*,? handoff.*,? forks' "$instructions" \
    && python3 "$ROOT/scripts/framework-task-topology-check.py" "$instructions" \
    && grep -Eqi 'GitHub integration.*codex review|codex review.*GitHub integration' "$instructions" \
    && grep -Eqi 'Record & Replay.*user-demonstrated|Record & Replay.*demonstrated.*workflow' "$instructions" \
    && grep -Eqi 'plugin trust/install.*explicit native user gates|never bypass.*plugin trust/install' "$instructions"
}

runtime_efficiency_contract() {
  local instructions="$ROOT/templates/global/AGENTS.md"
  grep -Fq 'Automatically use evidence-based challenge' "$instructions" \
    && grep -Fq 'continue waiting on the same live handle' "$instructions" \
    && grep -Fq 'Reuse a check while its code SHA, command/config, environment' "$instructions" \
    && grep -Fq 'never authorized fixes for later CI failures' "$instructions" \
    && test -s "$ROOT/docs/runtime-efficiency.md" \
    && python3 -m json.tool "$ROOT/evals/runtime-efficiency-output.schema.json" >/dev/null
}

project_environment_authority_contract() {
  local contract_root="${1:-$ROOT}"
  local instructions="$contract_root/templates/global/AGENTS.md"
  grep -Eqi 'compact project contract.*repository shape.*manifest/lockfile-owned stack.*authoritative commands.*environment map.*release or mutation boundaries' "$instructions" \
      && grep -Eqi 'exact target environment.*,? account or project.*,? authority source.*,? actor or credential class.*,? mutation boundary.*,? verification path.*repository and provider-visible evidence' "$instructions" \
      && grep -Fqi 'A failed local readiness or status check proves only that the local path is unavailable' "$instructions" \
      && grep -Eqi 'does not authorize substitute infrastructure.*,? a different environment.*,? or a weaker verification path' "$instructions" \
      && grep -Eqi 'target authority remains ambiguous.*,? stop before mutation or substitute creation' "$instructions" \
      || return 1
  if grep -Erqi 'failed local (readiness|status)( check| command)?.*(authorizes|allows|permits).*(substitute infrastructure|different environment|weaker verification)' "$contract_root/AGENTS.md" "$contract_root/templates"; then return 1; fi
  grep -Fqi 'A failed local readiness or status command is scoped evidence about that local path only' "$contract_root/README.md" \
    && grep -Eqi 'provider- and project-neutral' "$contract_root/README.md"
}

project_environment_authority_counterexample() {
  local fixture_root
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-environment-contract.XXXXXX")"
  mkdir -p "$fixture_root/templates/global" "$fixture_root/templates/project"
  cp "$ROOT/AGENTS.md" "$fixture_root/AGENTS.md"
  cp "$ROOT/README.md" "$fixture_root/README.md"
  cp "$ROOT/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.md"
  cp "$ROOT/templates/project/AGENTS.md" "$fixture_root/templates/project/AGENTS.md"
  printf '\nA failed local readiness check authorizes creating substitute infrastructure and mutating it before target authority is resolved.\n' >> "$fixture_root/AGENTS.md"
  if project_environment_authority_contract "$fixture_root"; then
    rm -rf -- "$fixture_root"
    return 1
  fi
  rm -rf -- "$fixture_root"
}

project_environment_authority_omission_counterexamples() {
  local fixture_root required
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-environment-omissions.XXXXXX")"
  mkdir -p "$fixture_root/templates/global" "$fixture_root/templates/project"
  cp "$ROOT/README.md" "$fixture_root/README.md"
  cp "$ROOT/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.md"
  cp "$ROOT/templates/project/AGENTS.md" "$fixture_root/templates/project/AGENTS.md"
  for required in \
    'repository shape' \
    'release or mutation boundaries' \
    'actor or credential class' \
    'mutation boundary' \
    'verification path' \
    'repository and provider-visible evidence'; do
    cp "$ROOT/AGENTS.md" "$fixture_root/AGENTS.md"
    sed "s|$required||g" "$fixture_root/templates/global/AGENTS.md" > "$fixture_root/templates/global/AGENTS.next"
    mv "$fixture_root/templates/global/AGENTS.next" "$fixture_root/templates/global/AGENTS.md"
    if project_environment_authority_contract "$fixture_root"; then
      rm -rf -- "$fixture_root"
      return 1
    fi
  done
  rm -rf -- "$fixture_root"
}

fallback_policy_contract() {
  local contract_root="${1:-$ROOT}"
  local instructions="$contract_root/templates/global/AGENTS.md"
  grep -q '^## Failure visibility and fallback policy$' "$instructions" \
      && grep -Fqi 'Fail closed.' "$instructions" \
      && grep -Fqi 'Never hide failure' "$instructions" \
      && grep -Fqi 'placeholder/mock/synthetic data' "$instructions" \
      && grep -Fqi 'stale-cache/default/empty success' "$instructions" \
      && grep -Fqi 'provider/model downgrades or swallowed errors' "$instructions" \
      && grep -Fqi 'original cause at the responsible boundary' "$instructions" \
      && grep -Fqi 'typed/structured errors' "$instructions" \
      && grep -Fqi 'safe actionable diagnostics and observability' "$instructions" \
      && grep -Fqi 'never report apparent success' "$instructions" \
      && grep -Fqi 'explicit prior user/project contract' "$instructions" \
      && grep -Fqi 'trigger, semantics, provenance, visible degraded state, observability and recovery/removal' "$instructions" \
      && grep -Fqi 'Test primary, authorized degraded and total-failure paths' "$instructions" \
      && grep -Fqi 'Without this contract fallback is prohibited' "$instructions" \
      && grep -Fqi 'in-scope undocumented fallback as a defect' "$instructions" \
      || return 1
  if grep -Erqi '(^|[^[:alnum:]_])(return|serve|use)([^[:alnum:]_]).*(placeholder|mock|sample|synthetic|fabricated|stale|cached|default).*(HTTP 200|success|normal|available|no degraded-state|no error)|(^|[^[:alnum:]_])(return|respond with)([^[:alnum:]_]).*(empty array|\[\]|empty result).*(HTTP 200|success|no error)|(^|[^[:alnum:]_])fallback([^[:alnum:]_]).*(requires no|without|does not require|no).*explicit.*(authorization|contract)' "$contract_root/AGENTS.md" "$contract_root/templates"; then return 1; fi
  grep -q '^## Fail-closed behavior by default$' "$contract_root/README.md" \
    && grep -Eqi 'implicit behavioral fallbacks as defects.*,? not resilience' "$contract_root/README.md" \
    && grep -Eqi 'absence of that evidence.*,? Codex fails closed' "$contract_root/README.md"
}

fallback_policy_counterexample() {
  local fixture_root counterexample
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-fallback-contract.XXXXXX")"
  mkdir -p "$fixture_root/templates/global" "$fixture_root/templates/project"
  cp "$ROOT/README.md" "$fixture_root/README.md"
  cp "$ROOT/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.md"
  cp "$ROOT/templates/project/AGENTS.md" "$fixture_root/templates/project/AGENTS.md"
  for counterexample in \
    'If live lookup fails, return cached sample data with HTTP 200 and no degraded-state marker.' \
    'If search throws, catch it and return an empty array with HTTP 200 and no error field.'; do
    cp "$ROOT/AGENTS.md" "$fixture_root/AGENTS.md"
    printf '\n%s\n' "$counterexample" >> "$fixture_root/AGENTS.md"
    if fallback_policy_contract "$fixture_root"; then
      rm -rf -- "$fixture_root"
      return 1
    fi
  done
  rm -rf -- "$fixture_root"
}

fallback_policy_omission_counterexamples() {
  local fixture_root required
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-fallback-omissions.XXXXXX")"
  mkdir -p "$fixture_root/templates/global" "$fixture_root/templates/project"
  cp "$ROOT/README.md" "$fixture_root/README.md"
  cp "$ROOT/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.md"
  cp "$ROOT/templates/project/AGENTS.md" "$fixture_root/templates/project/AGENTS.md"
  for required in \
    'Never hide failure' \
    'original cause' \
    'typed/structured errors' \
    'safe actionable diagnostics' \
    'visible degraded state' \
    'recovery/removal' \
    'total-failure' \
    'in-scope undocumented fallback as a defect'; do
    cp "$ROOT/AGENTS.md" "$fixture_root/AGENTS.md"
    cp "$ROOT/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.md"
    sed "s|$required||g" "$fixture_root/templates/global/AGENTS.md" > "$fixture_root/templates/global/AGENTS.next"
    mv "$fixture_root/templates/global/AGENTS.next" "$fixture_root/templates/global/AGENTS.md"
    if fallback_policy_contract "$fixture_root"; then
      rm -rf -- "$fixture_root"
      return 1
    fi
  done
  rm -rf -- "$fixture_root"
}

capability_discovery_contract() {
  local contract_root="${1:-$ROOT}"
  local instructions="$contract_root/templates/global/AGENTS.md"
  grep -q '^## Capability discovery and tool selection$' "$instructions" \
      && grep -Eqi 'inventory repository commands.*,? PATH CLIs.*,? plugins/connectors.*,? and native tools' "$instructions" \
      && grep -Eqi 'CLI presence/version/help.*,? safe identity/auth/status' "$instructions" \
      && grep -Eqi 'plugin catalogs never prove unavailability' "$instructions" \
      && grep -Eqi 'Use authenticated CLI automatically' "$instructions" \
      && grep -Eqi 'Never assume API parity' "$instructions" \
      && grep -Fqi 'CLI success is not provider truth' "$instructions" \
      && grep -Eqi 'verify account/org/project/environment/time/filter scope.*,? complete parseable output' "$instructions" \
      && grep -Eqi 'Empty or mixed-warning/truncated/unsupported results are inconclusive' "$instructions" \
      && grep -Eqi 'same-scope authenticated connector/API' "$instructions" \
      && grep -Fqi 'Before target-dependent provider use' "$instructions" \
      && grep -Eqi 'flags.*,? env.*,? repo config.*,? credential/profile.*,? and link/cache selectors to agree' "$instructions" \
      && grep -Eqi 'Missing/stale/conflicting selectors block' "$instructions" \
      && grep -Eqi 'Browser requires a stated CLI/API gap.*,? UI-only evidence/action' "$instructions" \
      && grep -Eqi 'Missing plugins do not block working tools' "$instructions" \
      && grep -Eqi 'Request only a user-named plugin after tool/CLI discovery is exhausted and it uniquely supplies the capability' "$instructions" \
      && grep -Eqi 'otherwise report the exact unsupported operation' "$instructions" \
      && grep -Eqi 'Before target-dependent provider use' "$instructions" \
      && grep -Eqi 'Never assume API parity.*,? fabricate access or switch a failed authorized path to another Browser/account' "$instructions" \
      || return 1
  if grep -Erqi 'request (plugin )?installation before checking.*(PATH|local CLI)|service is unavailable even though.*CLI is installed|missing plugin means.*service.*unavailable|plugin installation is a mandatory gate.*(before|without).*(CLI|local tool)|(integration|connector|extension).*(not installed|not configured|missing).*(stop|ask|cannot|unavailable).*(without inspecting|skip discovery|without checking).*(executable|command|tool)|No (integration|connector|extension).*configured.*(cannot|unavailable).*skip discovery.*(command|tool)|(CLI|command|tool).*authenticated.*(some|unknown|unconfirmed) (account|workspace|project).*(run|perform|execute).*(mutation|write|deploy).*without (confirming|verifying).*(target|account|workspace|project|environment)|CLI exited 0.*empty.*authoritative|link files disagree.*continue|CLI lacks.*open.*Browser.*without.*API|mixed.*output.*pipe.*jq.*ignore.*stderr' "$contract_root/AGENTS.md" "$contract_root/templates"; then return 1; fi
  grep -q '^## Capability discovery: local CLI before plugin gate$' "$contract_root/README.md" \
    && grep -Eqi 'uninstalled optional plugin is not evidence that a service is unavailable' "$contract_root/README.md" \
    && grep -Eqi 'uses that CLI automatically when it provides the exact required operation' "$contract_root/README.md"
}

capability_discovery_counterexamples() {
  local fixture_root counterexample
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-capability-contract.XXXXXX")"
  mkdir -p "$fixture_root/templates/global" "$fixture_root/templates/project"
  cp "$ROOT/README.md" "$fixture_root/README.md"
  cp "$ROOT/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.md"
  cp "$ROOT/templates/project/AGENTS.md" "$fixture_root/templates/project/AGENTS.md"
  for counterexample in \
    'The service plugin is available but not installed, so request installation before checking PATH or any local CLI.' \
    'The optional plugin is missing; the service is unavailable even though an authenticated provider CLI is installed.' \
    'Because the optional integration is not installed, stop and ask the user to add it without inspecting executable tools.' \
    'No connector is configured, therefore this operation cannot be performed; skip discovery of commands already on the machine.' \
    'The CLI is authenticated to some account, so run the mutation without confirming its target workspace.' \
    'The CLI exited 0 with an empty list, so treat that empty result as authoritative without checking scope or completeness.' \
    'The provider link files disagree, but continue with whichever target the CLI happens to select.' \
    'The CLI lacks this subcommand, so open the provider in Browser without trying its authenticated API.' \
    'The provider emitted mixed warning and JSON output; pipe it to jq and ignore stderr.'; do
    cp "$ROOT/AGENTS.md" "$fixture_root/AGENTS.md"
    printf '\n%s\n' "$counterexample" >> "$fixture_root/AGENTS.md"
    if capability_discovery_contract "$fixture_root"; then
      rm -rf -- "$fixture_root"
      return 1
    fi
  done
  rm -rf -- "$fixture_root"
}

capability_discovery_omission_counterexamples() {
  local fixture_root required
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-capability-omissions.XXXXXX")"
  mkdir -p "$fixture_root/templates/global" "$fixture_root/templates/project"
  cp "$ROOT/README.md" "$fixture_root/README.md"
  cp "$ROOT/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.md"
  cp "$ROOT/templates/project/AGENTS.md" "$fixture_root/templates/project/AGENTS.md"
  for required in \
    'inventory repository commands' \
    'PATH CLIs' \
    'CLI presence' \
    'safe identity/auth/status' \
    'Use authenticated CLI automatically' \
    'API parity' \
    'CLI success is not provider truth' \
    'Empty or mixed-warning' \
    'target-dependent provider use' \
    'link/cache selectors' \
    'Missing/stale/conflicting selectors' \
    'same-scope authenticated connector/API' \
    'Browser requires a stated CLI/API gap' \
    'Missing plugins do not block working tools' \
    'user-named plugin' \
    'uniquely supplies the capability' \
    'exact unsupported operation' \
    'switch a failed authorized path'; do
    cp "$ROOT/AGENTS.md" "$fixture_root/AGENTS.md"
    cp "$ROOT/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.md"
    sed "s|$required||g" "$fixture_root/templates/global/AGENTS.md" > "$fixture_root/templates/global/AGENTS.next"
    if cmp -s "$fixture_root/templates/global/AGENTS.md" "$fixture_root/templates/global/AGENTS.next"; then
      rm -rf -- "$fixture_root"
      return 1
    fi
    mv "$fixture_root/templates/global/AGENTS.next" "$fixture_root/templates/global/AGENTS.md"
    if capability_discovery_contract "$fixture_root"; then
      rm -rf -- "$fixture_root"
      return 1
    fi
  done
  rm -rf -- "$fixture_root"
}

native_capability_currency_contract() {
  grep -q '^## Native capability currency$' "$ROOT/AGENTS.md" \
    && grep -Eqi 'official.*manual.*changelog.*latest stable release|manual.*,? the full changelog delta.*,? and the latest stable release' "$ROOT/AGENTS.md" \
    && grep -q 'native-capability-ledger.json' "$ROOT/AGENTS.md" \
    && grep -Eqi 'apply the safe cleanup in the same (framework )?task' "$ROOT/AGENTS.md" \
    && grep -q 'native-capability-ledger.json' "$ROOT/skills/framework-management/SKILL.md" \
    && grep -q 'Daybreak Blue never implies Daybreak Red authorization' "$ROOT/AGENTS.md" \
    && test -s "$ROOT/docs/native-capability-review.md" \
    && python3 -m json.tool "$ROOT/docs/native-capability-ledger.schema.json" >/dev/null \
    && python3 -m json.tool "$ROOT/docs/native-capability-ledger.json" >/dev/null \
    && python3 -c 'import json, pathlib, sys; ledger=json.loads(pathlib.Path(sys.argv[1]).read_text()); expected={"external-agent-import":"adopted","computer-history":"permission-gated","linux-desktop-preview":"retained"}; actual={item["id"]:item["decision"] for item in ledger["capabilities"]}; sys.exit(0 if ledger["changelogReviewedThrough"] >= "2026-08-13" and all(actual.get(key) == value for key, value in expected.items()) else 1)' "$ROOT/docs/native-capability-ledger.json" \
    && python3 "$ROOT/scripts/framework-native-capability-check.py" \
    && python3 "$ROOT/scripts/framework-native-capability-check.py" --self-test
}

token_hygiene_contract() {
  # Byte budgets have one owner: framework-token-budget-check.py.
  grep -q 'Generic cross-repository behavior.*owned once by the global working agreement' "$ROOT/AGENTS.md" \
    && grep -q 'global working agreement installed by the Codex framework owns generic' "$ROOT/templates/project/AGENTS.md" \
    && ! grep -Eq '^## (Project and environment context|Failure visibility and fallback policy|Capability discovery and tool selection|Native task ergonomics and automation|Interactive development)$' "$ROOT/AGENTS.md" "$ROOT/templates/project/AGENTS.md"
}

check 'native AGENTS instruction file exists' test -f "$ROOT/AGENTS.md"
check 'visible native planning and delegation contract exists' visible_orchestration_contract "$ROOT/AGENTS.md"
check 'bounded falsification-review contract exists' falsification_review_contract
check 'interactive Browser and mobile device lifecycle is automatic and task-owned' interactive_development_contract
check 'current native task and automation features have explicit adoption boundaries' native_feature_adoption_contract
check 'bounded goal, wait, verification, and reviewer efficiency contracts exist' runtime_efficiency_contract
check 'project and environment authority fails closed before substitute infrastructure' project_environment_authority_contract
check 'project and environment authority rejects contradictory fallback authorization' project_environment_authority_counterexample
check 'project and environment authority rejects required-field omissions' project_environment_authority_omission_counterexamples
check 'fail-closed instruction structure is present' fallback_policy_contract
check 'behavioral fallback policy rejects hidden-success counterexamples' fallback_policy_counterexample
check 'behavioral fallback policy rejects required-field omissions' fallback_policy_omission_counterexamples
check 'capability discovery uses an existing local CLI before a plugin gate' capability_discovery_contract
check 'capability discovery rejects premature plugin-install counterexamples' capability_discovery_counterexamples
check 'capability discovery rejects required-field omissions' capability_discovery_omission_counterexamples
check 'service-operation live cases cover CLI truth, target conflicts, API escalation, and visual Browser use' bash -c "python3 -m json.tool '$ROOT/evals/service-operation-output.schema.json' >/dev/null && [ \"\$(wc -l < '$ROOT/evals/service-operation-cases.tsv' | tr -d ' ')\" -eq 4 ] && rg -q '^sentry_empty_conflict[[:space:]]+connector_or_api[[:space:]]+false[[:space:]]+false' '$ROOT/evals/service-operation-cases.tsv' && rg -q '^supabase_link_conflict[[:space:]]+stop[[:space:]]+false[[:space:]]+false' '$ROOT/evals/service-operation-cases.tsv' && rg -q '^exact_cli_json[[:space:]]+cli[[:space:]]+false[[:space:]]+false' '$ROOT/evals/service-operation-cases.tsv' && rg -q '^provider_visual_ui[[:space:]]+browser[[:space:]]+false[[:space:]]+true' '$ROOT/evals/service-operation-cases.tsv'"
check 'framework maintenance automatically checks current native capability deltas' native_capability_currency_contract
check 'generic policy is single-owned without duplicate startup payloads' token_hygiene_contract
check 'token budgets preserve native optimization defaults' python3 "$ROOT/scripts/framework-token-budget-check.py" --self-test
check 'global guidance template exists' test -s "$ROOT/templates/global/AGENTS.md"
check 'global guidance prefers native capabilities' grep -q 'Prefer native Codex capabilities' "$ROOT/templates/global/AGENTS.md"
check 'native config parses strictly' bash -c "codex app-server --strict-config --stdio </dev/null >/dev/null 2>&1"
check 'strict native config rejects an unknown agent key' bash -c "! codex app-server --strict-config -c agents.definitely_not_real=1 --stdio </dev/null >/dev/null 2>&1"
check 'project config is present and not ignored from source control' project_config_is_source_owned
check 'agent architect profile is valid' native_agent_valid architect
check 'agent reviewer profile is valid' native_agent_valid reviewer
check 'reviewer remains read-only and non-recursive' reviewer_safety_contract
check 'agent tester profile is valid' native_agent_valid tester
check 'built-in explorer is not shadowed' test ! -e "$ROOT/.codex/agents/explorer.toml"
check 'built-in worker is not duplicated' test ! -e "$ROOT/.codex/agents/builder.toml"
check 'current agent concurrency key is used' grep -Eq '^max_concurrent_threads_per_session = 4$' "$ROOT/.codex/config.toml"
check 'native Codex owns agent delegation depth' bash -c "! grep -Eq '^max_depth[[:space:]]*=' '$ROOT/.codex/config.toml'"
check 'reasoning overrides are limited to judgment-heavy profiles' reasoning_overrides_are_bounded
check 'config has no context-injection or lifecycle routing' bash -c "! grep -Eq 'SessionStart|UserPromptSubmit|PostToolUse' '$ROOT/.codex/config.toml'"
check 'custom profiles inherit the native model catalog' bash -c "! rg -q '^model = ' '$ROOT/.codex/agents'"
check 'project config paths are portable' bash -c "! rg -q '/Users/|/home/' '$ROOT/.codex/config.toml'"
check 'repo plugin marketplace is valid JSON' bash -c "python3 -m json.tool '$ROOT/.agents/plugins/marketplace.json' >/dev/null"
check 'frontend design plugin manifest is valid JSON' bash -c "python3 -m json.tool '$ROOT/plugins/codex-frontend-design/.codex-plugin/plugin.json' >/dev/null"
check 'legacy duplicate hooks plugin is absent' bash -c "[ ! -e '$ROOT/plugins/ai-codex-framework' ]"
check 'native destructive-command rules exist' test -s "$ROOT/.codex/rules/safety.rules"
check 'obsolete runtime wrappers are absent' bash -c "! find '$ROOT' -path '$ROOT/.git' -prune -o -type f \\( -name 'codex-fw.sh' -o -name 'routing-skills.sh' -o -name 'agent-registry.sh' -o -name 'framework-maturity.sh' -o -name 'framework-benchmark.sh' -o -name 'browser-verify.sh' -o -name 'work.sh' -o -name 'issue-worktrees.sh' \\) -print | grep -q ."
check 'native workflow wrapper skills are absent' bash -c "for skill in spec re-spec status verify commit ci-status pr-review pr-fix-comments playwright-reset process-hygiene; do [ ! -f '$ROOT/skills/'\"\$skill\"'/SKILL.md' ] || exit 1; done"
check 'universal core remains at most 25 skills' bash -c "[ \"\$(sed '/^#/d;/^$/d' '$ROOT/skills/core.txt' | wc -l | tr -d ' ')\" -le 25 ]"
check 'skill governance passes' bash "$ROOT/scripts/framework-skill-governance.sh"
check 'dynamic version resolvers and numeric scaffold guard pass' bash "$ROOT/scripts/framework-version-drift-check.sh"
check 'version drift counterexamples are rejected' bash "$ROOT/scripts/framework-version-drift-check.sh" --self-test
check 'every skill has a strict quality and routing contract' python3 "$ROOT/scripts/framework-skill-quality.py" check
check 'quality evaluator rejects its counterexamples' python3 "$ROOT/scripts/framework-skill-quality.py" self-test
check 'release evidence rejects fabricated attestations' python3 "$ROOT/scripts/framework-release-evidence.py" self-test
check 'release interruption owns and terminates evaluator children' grep -q 'terminate_active_processes' "$ROOT/scripts/framework-skill-quality.py"
check 'setup preserves colliding user skill and all existing guidance targets' setup_collision_safety
check 'managed agent copies update safely and migrate legacy symlinks' managed_profile_copy_safety
check 'project pack sync is declarative, idempotent, pruning, and collision-safe' project_pack_sync_safety
check 'bootstrap preserves native user config' bootstrap_preserves_native_config
check 'shell parsing wrapper is absent' test ! -e "$ROOT/scripts/hooks/pre-tool-use.sh"
check 'installation source isolation fixtures pass' python3 "$ROOT/scripts/framework-install-source-self-test.py"
check 'scoped token evidence fixtures pass' python3 "$ROOT/scripts/framework-token-budget-check-test.py"
check 'behavioral graders reject false acceptance' python3 "$ROOT/scripts/framework-project-behavior-eval.py" --self-test

printf 'framework eval: %d checks, %d failures\n' "$total" "$failures"
[ "$failures" -eq 0 ]
