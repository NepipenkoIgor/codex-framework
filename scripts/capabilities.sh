#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$(project_root)}"
STACK="$(bash "$(framework_root)/scripts/detect-project-stack.sh" "$ROOT" 2>/dev/null || echo unknown)"

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

has_local_file() {
  [ -e "$ROOT/$1" ]
}

pkg_has_dep() {
  local pattern="$1"
  [ -f "$ROOT/package.json" ] || return 1
  search_file_regex "$pattern" "$ROOT/package.json"
}

bool() {
  if [ "$1" = true ]; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}

git_repo=false
git_remote=false
network_disabled=false
github_cli=false
github_auth_configured=false
github_auth_validated=false
github_auth_ready=false
github_structured=false
ts_diag=false
ts_diag_local=false
csharp_diag=false
csharp_diag_local=false
browser_automation=false
browser_checks_local=false
supabase_tools=false
supabase_cli=false
firebase_tools=false
firebase_cli=false
stripe_tools=false
stripe_cli=false

git rev-parse --show-toplevel >/dev/null 2>&1 && git_repo=true || true
if [ "$git_repo" = true ] && git remote get-url origin >/dev/null 2>&1; then
  git_remote=true
fi
if [ "${CODEX_SANDBOX_NETWORK_DISABLED:-0}" = "1" ]; then
  network_disabled=true
fi
has_cmd gh && github_cli=true || true

if [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-${GITHUB_PERSONAL_ACCESS_TOKEN:-}}}" ]; then
  github_auth_configured=true
fi

if [ "$github_cli" = true ] && gh auth status >/dev/null 2>&1; then
  github_auth_validated=true
fi

if [ "$github_auth_validated" = true ] || [ "$github_auth_configured" = true ]; then
  github_auth_ready=true
fi

if [ -n "${CODEX_HAS_GITHUB_STRUCTURED:-}" ]; then
  github_structured=true
fi
if [ -n "${CODEX_HAS_TS_DIAGNOSTICS:-}" ]; then
  ts_diag=true
fi
if has_cmd tsc || has_local_file node_modules/.bin/tsc || pkg_has_dep '"typescript"'; then
  ts_diag_local=true
fi
if [ -n "${CODEX_HAS_CSHARP_DIAGNOSTICS:-}" ]; then
  csharp_diag=true
fi
if (has_cmd dotnet || has_local_file .config/dotnet-tools.json) && { find "$ROOT" -maxdepth 2 \( -name '*.csproj' -o -name '*.sln' \) | grep -q .; }; then
  csharp_diag_local=true
fi
if [ -n "${CODEX_HAS_BROWSER_AUTOMATION:-}" ]; then
  browser_automation=true
fi
if [[ ",$STACK," == *,playwright,* ]] || pkg_has_dep '"(@playwright/test|playwright)"'; then
  browser_checks_local=true
fi
if [ -n "${CODEX_HAS_SUPABASE_TOOLS:-}" ]; then
  supabase_tools=true
fi
has_cmd supabase && supabase_cli=true || true
if [ -n "${CODEX_HAS_FIREBASE_TOOLS:-}" ]; then
  firebase_tools=true
fi
has_cmd firebase && firebase_cli=true || true
if [ -n "${CODEX_HAS_STRIPE_TOOLS:-}" ]; then
  stripe_tools=true
fi
has_cmd stripe && stripe_cli=true || true

desired=()
add_desired() {
  local item="$1"
  local existing
  for existing in ${desired[*]-}; do
    [ "$existing" = "$item" ] && return 0
  done
  desired+=("$item")
}

case ",$STACK," in
  *,typescript,*|*,react,*|*,nextjs,*|*,vue,*|*,angular,*)
    add_desired "ts-diagnostics"
    ;;
esac

case ",$STACK," in
  *,dotnet,*|*,blazor,*)
    add_desired "csharp-diagnostics"
    ;;
esac

case ",$STACK," in
  *,playwright,*|*,react,*|*,nextjs,*|*,vue,*|*,angular,*|*,blazor,*)
    add_desired "browser-automation"
    ;;
esac

case ",$STACK," in
  *,supabase,*) add_desired "supabase-tools" ;;
esac
case ",$STACK," in
  *,firebase,*) add_desired "firebase-tools" ;;
esac
case ",$STACK," in
  *,stripe,*) add_desired "stripe-tools" ;;
esac

if [ "$git_repo" = true ]; then
  add_desired "git"
  add_desired "github-cli"
fi

print_section "Capabilities"
info "stack=$STACK"
info "network_disabled=$(bool "$network_disabled")"
info "git=$(bool "$git_repo")"
info "git_remote=$(bool "$git_remote")"
info "github_cli=$(bool "$github_cli")"
info "github_auth_configured=$(bool "$github_auth_configured")"
info "github_auth_validated=$(bool "$github_auth_validated")"
info "github_auth_ready=$(bool "$github_auth_ready")"
info "github_structured=$(bool "$github_structured")"
info "ts_diagnostics=$(bool "$ts_diag")"
info "ts_diagnostics_local=$(bool "$ts_diag_local")"
info "csharp_diagnostics=$(bool "$csharp_diag")"
info "csharp_diagnostics_local=$(bool "$csharp_diag_local")"
info "browser_automation=$(bool "$browser_automation")"
info "browser_checks_local=$(bool "$browser_checks_local")"
info "supabase_tools=$(bool "$supabase_tools")"
info "supabase_cli=$(bool "$supabase_cli")"
info "firebase_tools=$(bool "$firebase_tools")"
info "firebase_cli=$(bool "$firebase_cli")"
info "stripe_tools=$(bool "$stripe_tools")"
info "stripe_cli=$(bool "$stripe_cli")"

print_section "Auto Path"
if [ "$ts_diag" = true ]; then
  info "ts_diagnostics_path=runtime diagnostics tools"
elif [ "$ts_diag_local" = true ]; then
  info "ts_diagnostics_path=local tsc/lint/test fallback"
else
  info "ts_diagnostics_path=none"
fi

if [ "$csharp_diag" = true ]; then
  info "csharp_diagnostics_path=runtime diagnostics tools"
elif [ "$csharp_diag_local" = true ]; then
  info "csharp_diagnostics_path=local dotnet build/test fallback"
else
  info "csharp_diagnostics_path=none"
fi

if [ "$browser_automation" = true ]; then
  info "browser_path=runtime browser automation"
elif [ "$browser_checks_local" = true ]; then
  info "browser_path=local Playwright/browser test fallback"
else
  info "browser_path=manual verification only"
fi

print_section "Desired"
if [ -n "${desired[*]-}" ]; then
  printf '%s\n' "${desired[@]}"
else
  info "none"
fi

print_section "GitHub Path"
if [ "$github_structured" = true ]; then
  info "preferred=structured GitHub tools"
  if [ "$github_cli" = true ] && [ "$github_auth_ready" = true ]; then
    info "fallback=gh CLI"
  elif [ "$git_repo" = true ]; then
    info "fallback=local git only"
  else
    info "fallback=none"
  fi
elif [ "$github_cli" = true ] && [ "$github_auth_ready" = true ]; then
  info "preferred=gh CLI"
  if [ "$github_auth_validated" = false ] && [ "$github_auth_configured" = true ]; then
    info "note=auth configured but not validated in current sandbox/session"
  fi
  if [ "$git_repo" = true ]; then
    info "fallback=local git only"
  else
    info "fallback=none"
  fi
elif [ "$git_repo" = true ]; then
  info "preferred=local git only"
  info "fallback=none"
else
  info "preferred=none"
  info "fallback=none"
fi
