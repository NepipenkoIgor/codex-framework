#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0
warnings=0
catalog_file="$(mktemp "${TMPDIR:-/tmp}/codex-skill-catalog.XXXXXX")"
registry_file="$(mktemp "${TMPDIR:-/tmp}/codex-skill-registry.XXXXXX")"
trap 'rm -f "$catalog_file" "$registry_file"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1"
  failures=$((failures + 1))
}

warn() {
  printf 'WARN: %s\n' "$1"
  warnings=$((warnings + 1))
}

for file in "$ROOT"/skills/*/SKILL.md; do
  [ -f "$file" ] && printf '%s\n' "$file"
done | sort > "$catalog_file"

while IFS= read -r file; do
  dir="$(basename "$(dirname "$file")")"
  rel="${file#"$ROOT"/}"
  frontmatter="$(awk 'NR == 1 && $0 == "---" { in_frontmatter=1; next } in_frontmatter && $0 == "---" { exit } in_frontmatter { print }' "$file")"
  name="$(printf '%s\n' "$frontmatter" | sed -n 's/^name: //p' | head -n 1)"
  description="$(printf '%s\n' "$frontmatter" | sed -n 's/^description: //p' | head -n 1)"
  lines="$(wc -l < "$file" | tr -d ' ')"

  [ "$name" = "$dir" ] || fail "$rel frontmatter name '$name' does not match directory '$dir'"
  [ -n "$description" ] || fail "$rel has no description"
  [ "${#description}" -le 1024 ] || fail "$rel description exceeds 1024 characters"
  printf '%s\n' "$description" | grep -Eiq 'use (when|for)|when the|when a |when an ' || fail "$rel description does not state when to use the skill"
  printf '%s\n' "$frontmatter" | grep -q '^metadata:' || fail "$rel has no metadata mapping"
  printf '%s\n' "$frontmatter" | grep -q '^  version:' || fail "$rel has no metadata.version"
  printf '%s\n' "$frontmatter" | grep -q '^  owner:' || fail "$rel has no metadata.owner"
  printf '%s\n' "$frontmatter" | grep -Eq '^  reviewed: "[0-9]{4}-[0-9]{2}-[0-9]{2}"$' || fail "$rel has no quoted YYYY-MM-DD metadata.reviewed"
  [ "$lines" -le 400 ] || fail "$rel has $lines lines; move optional detail to references (max 400)"
  [ "$lines" -le 380 ] || warn "$rel has $lines lines; progressive-disclosure review recommended"

  printf '%s\n' "$description" | grep -Eiq '\b(Node\.js|NestJS|Angular|React|Vue|Nuxt|Next\.js|Expo SDK|SDK) [0-9]' && fail "$rel pins a framework version in routing metadata"
  grep -q '^Pair with `' "$file" && fail "$rel requires a hidden multi-skill chain"
  if rg -l 'find /tmp.*rm -rf|pkill -f|kill \$\(lsof' "$(dirname "$file")" -g '*.md' >/dev/null; then
    fail "$rel or one of its references contains a broad process or temporary-directory cleanup recipe"
  fi

  if printf '%s\n' "$frontmatter" | grep -q '^  agents:'; then
    agents="$(printf '%s\n' "$frontmatter" | sed -n 's/^  agents: *\[\(.*\)\]/\1/p' | tr ',' ' ')"
    for agent in $agents; do
      agent="$(printf '%s' "$agent" | tr -d " '\"")"
      case "$agent" in explorer|worker|architect|reviewer|tester) ;; *) fail "$rel references unknown native profile '$agent'" ;; esac
    done
  fi

  if [ -d "$(dirname "$file")/references" ]; then
    while IFS= read -r reference; do
      reference_root="$(dirname "$file")"
      reference_rel="${reference#"$reference_root"/}"
      grep -Fq "$reference_rel" "$file" || fail "$rel does not route reference '$reference_rel'"
    done < <(find "$(dirname "$file")/references" -type f | sort)
  fi

  while IFS= read -r link; do
    case "$link" in references/*|SKILL.detail.md)
      [ -f "$(dirname "$file")/$link" ] || fail "$rel links missing resource '$link'"
      ;;
    esac
  done < <(sed -n 's/.*](\([^)]*\)).*/\1/p' "$file")
done < "$catalog_file"

retired_skills="spec re-spec status verify commit ci-status pr-review pr-fix-comments playwright-reset process-hygiene framework-orchestration-audit react-native-patterns fullstack-blazor-implement fullstack-blazor-debug fullstack-blazor-refactor fullstack-blazor-review fullstack-blazor-test fullstack-nextjs-implement fullstack-nextjs-review fullstack-nextjs-test graphql-design graphql-implement saas-billing-portal upgrade-downgrade-flows"
for forbidden in $retired_skills; do
  [ ! -f "$ROOT/skills/$forbidden/SKILL.md" ] || fail "native wrapper or consolidated skill still exists: $forbidden"
  if rg -l -F "\`$forbidden\`" "$ROOT/skills" -g 'SKILL.md' >/dev/null; then
    fail "maintained skill routes to retired skill '$forbidden'"
  fi
done

core_count="$(sed '/^#/d;/^$/d' "$ROOT/skills/core.txt" | wc -l | tr -d ' ')"
[ "$core_count" -le 25 ] || fail "skills/core.txt has $core_count entries; maximum is 25"

for manifest in "$ROOT/skills/core.txt" "$ROOT"/skills/packs/*.txt; do
  manifest_rel="${manifest#"$ROOT"/}"
  duplicates="$(sed '/^#/d;/^$/d' "$manifest" | sort | uniq -d)"
  [ -z "$duplicates" ] || fail "$manifest_rel has duplicate entries: $duplicates"
  while IFS= read -r skill; do
    case "$skill" in ''|'#'*) continue ;; esac
    [ -f "$ROOT/skills/$skill/SKILL.md" ] || fail "$manifest_rel references missing skill '$skill'"
    printf '%s\n' "$skill" >> "$registry_file"
  done < "$manifest"

  metadata_chars=0
  while IFS= read -r skill; do
    case "$skill" in ''|'#'*) continue ;; esac
    description="$(sed -n 's/^description: //p' "$ROOT/skills/$skill/SKILL.md" | head -n 1)"
    metadata_chars=$((metadata_chars + ${#skill} + ${#description} + 2))
  done < "$manifest"
  [ "$metadata_chars" -le 7000 ] \
    || warn "$manifest_rel routing name/description metadata is $metadata_chars characters; native catalogs share a bounded startup budget"
done

plugin_root="$ROOT/plugins/codex-frontend-design"
plugin_manifest="$ROOT/.agents/plugins/marketplace.json"
plugin_pack="$ROOT/skills/packs/frontend-design.txt"
if [ -d "$plugin_root" ]; then
  [ -f "$plugin_manifest" ] || fail 'frontend-design plugin marketplace is missing'
  [ -f "$plugin_root/.codex-plugin/plugin.json" ] || fail 'frontend-design plugin manifest is missing'
  plugin_members="$(find "$plugin_root/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
  pack_members="$(sed '/^#/d;/^$/d' "$plugin_pack" | sort)"
  [ "$plugin_members" = "$pack_members" ] || fail 'frontend-design plugin membership differs from its owning pack'
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    expected="../plugins/codex-frontend-design/skills/$skill"
    [ -L "$ROOT/skills/$skill" ] && [ "$(readlink "$ROOT/skills/$skill")" = "$expected" ] \
      || fail "frontend-design direct skill projection drifted: $skill"
    [ -f "$plugin_root/skills/$skill/agents/openai.yaml" ] \
      || fail "frontend-design plugin skill lacks native UI metadata: $skill"
    [ "${#skill}" -le 64 ] && [ $(( ${#skill} + 22 )) -le 64 ] \
      || fail "frontend-design plugin-qualified skill identity exceeds 64 characters: $skill"
  done <<< "$pack_members"
fi

while IFS= read -r file; do
  skill="$(basename "$(dirname "$file")")"
  grep -Fxq "$skill" "$registry_file" || fail "skill '$skill' is not registered in core or a domain pack"
done < "$catalog_file"

catalog_files=()
while IFS= read -r file; do
  catalog_files[${#catalog_files[@]}]="$file"
done < "$catalog_file"
overlap_output="$(awk '
  FILENAME != previous_file {
    file_count++
    files[file_count]=FILENAME
    previous_file=FILENAME
    in_frontmatter=0
    frontmatter_done=0
  }
  FNR == 1 && $0 == "---" { in_frontmatter=1; next }
  in_frontmatter && $0 == "---" { in_frontmatter=0; frontmatter_done=1; next }
  in_frontmatter || !frontmatter_done { next }
  {
    line=tolower($0)
    if (line ~ /^[[:space:]]*(#|```|$)/) next
    gsub(/`[^`]*`/, "", line)
    gsub(/[[:punct:][:digit:]]/, " ", line)
    gsub(/[[:space:]]+/, " ", line)
    sub(/^ /, "", line); sub(/ $/, "", line)
    if (length(line) < 32) next
    key=file_count SUBSEP line
    if (!seen[key]++) {
      unique_count[file_count]++
      line_files[line]=line_files[line] " " file_count
    }
  }
  END {
    for (line in line_files) {
      n=split(line_files[line], ids, " ")
      for (a=2; a<=n; a++) for (b=a+1; b<=n; b++) {
        i=ids[a]; j=ids[b]
        if (i > j) { t=i; i=j; j=t }
        common[i SUBSEP j]++
      }
    }
    for (key in common) {
      split(key, pair, SUBSEP); i=pair[1]; j=pair[2]
      union_count=unique_count[i]+unique_count[j]-common[key]
      score=union_count ? common[key]/union_count : 0
      if (common[key] >= 30 && score >= 0.28)
        printf "FAIL\t%.3f\t%d\t%s\t%s\n", score, common[key], files[i], files[j]
      else if (common[key] >= 20 && score >= 0.18)
        printf "WARN\t%.3f\t%d\t%s\t%s\n", score, common[key], files[i], files[j]
    }
  }
' "${catalog_files[@]}")"

if [ -n "$overlap_output" ]; then
  while IFS=$'\t' read -r level score common left right; do
    left="${left#"$ROOT"/}"; right="${right#"$ROOT"/}"
    if [ "$level" = FAIL ]; then
      fail "semantic overlap $score ($common shared lines): $left <> $right"
    else
      warn "semantic overlap $score ($common shared lines): $left <> $right"
    fi
  done <<< "$overlap_output"
fi

printf 'skill governance: %d failures, %d warnings, %d skills, %d core\n' "$failures" "$warnings" "$(wc -l < "$catalog_file" | tr -d ' ')" "$core_count"
[ "$failures" -eq 0 ]
