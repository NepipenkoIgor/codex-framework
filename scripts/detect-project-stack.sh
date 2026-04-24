#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$PWD}"
STACK=()

add_stack() {
  local value="$1"
  local existing
  for existing in ${STACK[*]-}; do
    [ "$existing" = "$value" ] && return 0
  done
  STACK+=("$value")
}

has_file() {
  [ -f "$ROOT/$1" ]
}

has_csproj() {
  find "$ROOT" -maxdepth 1 \( -name '*.csproj' -o -name '*.sln' \) | grep -q .
}

pkg_has_dep() {
  local pattern="$1"
  search_file_regex "$pattern" "$ROOT/package.json"
}

if has_file package.json || has_file tsconfig.json; then
  add_stack "typescript"
fi

if has_csproj; then
  add_stack "dotnet"
fi

if has_file go.mod; then
  add_stack "go"
fi

if has_file Cargo.toml; then
  add_stack "rust"
fi

if has_file pubspec.yaml; then
  add_stack "flutter"
fi

if has_file package.json; then
  if pkg_has_dep '"tailwindcss"'; then
    add_stack "tailwind"
  fi
  if pkg_has_dep '"(react|react-dom)"'; then
    add_stack "react"
  fi
  if pkg_has_dep '"next"'; then
    add_stack "nextjs"
  fi
  if pkg_has_dep '"vue"'; then
    add_stack "vue"
  fi
  if pkg_has_dep '"@angular/core"'; then
    add_stack "angular"
  fi
  if pkg_has_dep '"@nestjs/core"'; then
    add_stack "nestjs"
  fi
  if pkg_has_dep '"(react-native|expo)"'; then
    add_stack "react-native"
  fi
  if pkg_has_dep '"(@playwright/test|playwright)"'; then
    add_stack "playwright"
  fi
  if pkg_has_dep '"(vitest|jest)"'; then
    add_stack "unit-test"
  fi
  if pkg_has_dep '"(@testing-library/react|@testing-library/vue|@testing-library/jest-dom)"'; then
    add_stack "testing-library"
  fi
  if pkg_has_dep '"(stripe|@stripe/[^"]+)"'; then
    add_stack "stripe"
  fi
  if pkg_has_dep '"(@supabase/supabase-js|supabase)"'; then
    add_stack "supabase"
  fi
  if pkg_has_dep '"(firebase|firebase-admin)"'; then
    add_stack "firebase"
  fi
fi

if find "$ROOT" -maxdepth 2 \( -name 'tailwind.config.js' -o -name 'tailwind.config.cjs' -o -name 'tailwind.config.mjs' -o -name 'tailwind.config.ts' \) | grep -q .; then
  add_stack "tailwind"
fi

if find "$ROOT" -type f -name '*.razor' | grep -q .; then
  add_stack "blazor"
fi

if [ "${#STACK[@]}" -eq 0 ]; then
  echo "unknown"
  exit 0
fi

printf '%s\n' "${STACK[@]}" | paste -sd "," -
