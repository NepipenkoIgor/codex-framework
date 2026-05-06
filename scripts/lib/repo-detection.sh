is_framework_repo_root() {
  local path="${1:-$(project_root)}"
  [ -f "$path/CODEX.concepts.md" ] \
    && [ -f "$path/ORCHESTRATOR_REFERENCE.md" ] \
    && [ -d "$path/skills" ] \
    && [ -d "$path/agents" ] \
    && [ -d "$path/scripts" ]
}

search_project_tree_regex() {
  local pattern="$1"
  local path="$2"
  local include_glob="${3:-}"
  if ! is_framework_repo_root "$path"; then
    search_tree_regex "$pattern" "$path" "$include_glob"
    return $?
  fi

  if has_command rg; then
    if [ -n "$include_glob" ]; then
      rg -n "$pattern" "$path" -g "$include_glob" \
        -g '!skills/**' -g '!agents/**' -g '!templates/**' -g '!scripts/**' \
        -g '!CODEX*.md' -g '!CONCEPTS.md' -g '!ORCHESTRATOR_REFERENCE.md' \
        -g '!README.md' -g '!SKILLS_MAP*.md' >/dev/null 2>&1
    else
      rg -n "$pattern" "$path" \
        -g '!skills/**' -g '!agents/**' -g '!templates/**' -g '!scripts/**' \
        -g '!CODEX*.md' -g '!CONCEPTS.md' -g '!ORCHESTRATOR_REFERENCE.md' \
        -g '!README.md' -g '!SKILLS_MAP*.md' >/dev/null 2>&1
    fi
  else
    if [ -n "$include_glob" ]; then
      grep -ERn --include="$include_glob" \
        --exclude-dir=skills --exclude-dir=agents --exclude-dir=templates --exclude-dir=scripts \
        --exclude='CODEX*.md' --exclude='CONCEPTS.md' --exclude='ORCHESTRATOR_REFERENCE.md' \
        --exclude='README.md' --exclude='SKILLS_MAP*.md' "$pattern" "$path" >/dev/null 2>&1
    else
      grep -ERn \
        --exclude-dir=skills --exclude-dir=agents --exclude-dir=templates --exclude-dir=scripts \
        --exclude='CODEX*.md' --exclude='CONCEPTS.md' --exclude='ORCHESTRATOR_REFERENCE.md' \
        --exclude='README.md' --exclude='SKILLS_MAP*.md' "$pattern" "$path" >/dev/null 2>&1
    fi
  fi
}
