#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_FILE="${1:-}"

if [ -z "$REPORT_FILE" ]; then
  REPORT_FILE="${TMPDIR:-/tmp}/codex-skill-corpus-audit.tsv"
fi

score_skill() {
  local file="$1"
  local rel="${file#$ROOT/}"
  local lines score=0
  local has_frontmatter=0 has_metadata=0 has_workflow=0 has_constraints=0
  local has_verification=0 has_output=0 has_domain_depth=0 has_quality=0
  local has_safety=0 has_tooling=0 has_context=0
  lines="$(wc -l < "$file" | tr -d ' ')"

  grep -q '^---$' "$file" && has_frontmatter=1
  grep -Eq '^name: |^description: ' "$file" && has_metadata=1
  grep -Eiq 'argument-hint|metadata:' "$file" && has_metadata=1
  grep -Eiq 'workflow|process|method|steps|implementation workflow|audit process|diagnostic workflow|migration workflow' "$file" && has_workflow=1
  grep -Eiq 'constraint|anti-pattern|anti pattern|never|do not|avoid|rules' "$file" && has_constraints=1
  grep -Eiq 'verification|verify|test|diagnostic|checks?|done criteria|quality gate' "$file" && has_verification=1
  grep -Eiq 'output|deliverable|report format|structured output|done criteria|status:' "$file" && has_output=1
  if [ "$lines" -ge 80 ] || grep -Eiq 'example|```|table|matrix|checklist|references/' "$file"; then
    has_domain_depth=1
  fi
  grep -Eiq 'existing pattern|convention|reuse|duplication|duplicate|DRY|KISS|simple|over-engineer|maintainability|clarity|component|contract|boundary' "$file" && has_quality=1
  grep -Eiq 'security|validation|auth|permission|privacy|secret|hardcode|hardcoded|performance|observability|logging|metric|accessibility|rollback|idempot|transaction|migration|rate limit|timeout|retry' "$file" && has_safety=1
  grep -Eiq 'tool integration|diagnostics|browser automation|docs lookup|official docs|ast-grep|rg |grep |EXPLAIN|playwright|gh |github' "$file" && has_tooling=1
  grep -Eiq 'repo|repository|codebase|project|local pattern|nearby|existing' "$file" && has_context=1

  [ "$has_frontmatter" -eq 1 ] && score=$((score + 10))
  [ "$has_metadata" -eq 1 ] && score=$((score + 10))
  [ "$has_workflow" -eq 1 ] && score=$((score + 10))
  [ "$has_constraints" -eq 1 ] && score=$((score + 10))
  [ "$has_verification" -eq 1 ] && score=$((score + 10))
  [ "$has_output" -eq 1 ] && score=$((score + 10))
  [ "$has_domain_depth" -eq 1 ] && score=$((score + 10))
  [ "$has_quality" -eq 1 ] && score=$((score + 10))
  [ "$has_safety" -eq 1 ] && score=$((score + 10))
  [ "$has_tooling" -eq 1 ] && score=$((score + 5))
  [ "$has_context" -eq 1 ] && score=$((score + 5))

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$score" "$lines" "$rel" \
    "$has_frontmatter" "$has_metadata" "$has_workflow" "$has_constraints" \
    "$has_verification" "$has_output" "$has_domain_depth" "$has_quality" \
    "$has_safety" "$has_tooling:$has_context"
}

{
  printf 'score\tlines\tfile\tfrontmatter\tmetadata\tworkflow\tconstraints\tverification\toutput\tdepth\tquality\tsafety\ttooling_context\n'
  while IFS= read -r file; do
    score_skill "$file"
  done < <(find "$ROOT/skills" -name SKILL.md | sort)
} > "$REPORT_FILE"

awk -F '\t' '
  NR == 1 { next }
  {
    count++
    score=$1 + 0
    sum += score
    if (score >= 85) excellent++
    else if (score >= 70) good++
    else if (score >= 50) thin++
    else critical++
    if ($4 == 1) frontmatter++
    if ($5 == 1) metadata++
    if ($6 == 1) workflow++
    if ($7 == 1) constraints++
    if ($8 == 1) verification++
    if ($9 == 1) output++
    if ($10 == 1) depth++
    if ($11 == 1) quality++
    if ($12 == 1) safety++
    split($13, tc, ":")
    if (tc[1] == 1) tooling++
    if (tc[2] == 1) context++
  }
  END {
    if (count == 0) exit 1
    printf "skill corpus audit report: %s\n", report
    printf "skills: %d\n", count
    printf "average_score: %.1f\n", sum / count
    printf "excellent_85_plus: %d\n", excellent + 0
    printf "good_70_84: %d\n", good + 0
    printf "thin_50_69: %d\n", thin + 0
    printf "critical_below_50: %d\n", critical + 0
    printf "coverage_frontmatter: %.0f%%\n", frontmatter * 100 / count
    printf "coverage_metadata: %.0f%%\n", metadata * 100 / count
    printf "coverage_workflow: %.0f%%\n", workflow * 100 / count
    printf "coverage_constraints: %.0f%%\n", constraints * 100 / count
    printf "coverage_verification: %.0f%%\n", verification * 100 / count
    printf "coverage_output: %.0f%%\n", output * 100 / count
    printf "coverage_domain_depth: %.0f%%\n", depth * 100 / count
    printf "coverage_quality_principles: %.0f%%\n", quality * 100 / count
    printf "coverage_safety_runtime: %.0f%%\n", safety * 100 / count
    printf "coverage_tooling: %.0f%%\n", tooling * 100 / count
    printf "coverage_repo_context: %.0f%%\n", context * 100 / count
  }
' report="$REPORT_FILE" "$REPORT_FILE"

printf '\nlowest_scoring_skills:\n'
awk -F '\t' 'NR > 1 { print $0 }' "$REPORT_FILE" | sort -t $'\t' -k1,1n -k2,2n | head -n 25 | awk -F '\t' '{ printf "%3d  %4d lines  %s\n", $1, $2, $3 }'

printf '\nmissing_by_category:\n'
for spec in \
  "workflow:6" \
  "constraints:7" \
  "verification:8" \
  "output:9" \
  "depth:10" \
  "quality:11" \
  "safety:12"
do
  name="${spec%%:*}"
  col="${spec##*:}"
  printf '%s:\n' "$name"
  awk -F '\t' -v col="$col" 'NR > 1 && $col == 0 { print "  " $3 }' "$REPORT_FILE" | head -n 20
done
