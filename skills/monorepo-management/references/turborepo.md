# Turborepo Configuration and Patterns

## turbo.json Configuration

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "globalEnv": ["NODE_ENV", "CI"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "!.next/cache/**"],
      "env": ["NEXT_PUBLIC_API_URL"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": ["coverage/**"],
      "env": ["CI"]
    },
    "lint": {
      "outputs": []
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "typecheck": {
      "dependsOn": ["^build"],
      "outputs": []
    }
  }
}
```

## Package-based Monorepo Structure (Turborepo-style)

```
monorepo/
  package.json              # root package.json with workspaces config
  turbo.json                # task pipeline config
  pnpm-workspace.yaml       # workspace package locations
  packages/
    shared-types/            # Shared TypeScript types
      package.json
      src/
      tsconfig.json
    ui-components/           # Shared UI library
      package.json
      src/
      tsconfig.json
    api-client/              # Generated API client
      package.json
      src/
  apps/
    web/                     # Frontend app
      package.json
      src/
    api/                     # Backend API
      package.json
      src/
    admin/                   # Admin panel
      package.json
      src/
  tools/
    scripts/                 # Build/deploy scripts
    generators/              # Code generators
  config/
    eslint/                  # Shared ESLint config
    tsconfig/                # Shared TypeScript config
    prettier/                # Shared Prettier config
```

## Affected Commands

```bash
# Filter by changes since main
turbo run build --filter=...[main]
turbo run test --filter=...[main]
```

## Turborepo Remote Cache

```bash
# Link to Vercel Remote Cache
npx turbo login
npx turbo link

# Or self-hosted with custom API
# turbo.json
{
  "remoteCache": {
    "signature": true  // verify cache integrity
  }
}
```

## Task Graph Visualization

```bash
# Dry run shows task graph
turbo run build --graph

# Output graph as dot format
turbo run build --graph=graph.dot

# Dry run with JSON output
turbo run build --dry-run=json
```

## Cache Debugging

```bash
# Check cache status
turbo run build --dry-run  # shows which tasks would hit cache
turbo run build --force    # bypass cache, run everything
```

## Turborepo Generators (turbo gen)

```bash
# Initialize generators
turbo gen workspace
```

Create a custom generator in `turbo/generators/config.ts`:

```typescript
import type { PlopTypes } from '@turbo/gen';

export default function generator(plop: PlopTypes.NodePlopAPI): void {
  plop.setGenerator('package', {
    description: 'Create a new workspace package',
    prompts: [
      { type: 'input', name: 'name', message: 'Package name (without @acme/ prefix):' },
      { type: 'list', name: 'type', choices: ['lib', 'app'], message: 'Package type:' },
      { type: 'list', name: 'scope', choices: ['shared', 'feature'], message: 'Scope:', when: (a) => a.type === 'lib' },
    ],
    actions: (answers) => {
      const dest = answers?.type === 'app' ? 'apps' : 'packages';
      return [
        { type: 'addMany', destination: `${dest}/{{name}}/`, base: 'templates/package', templateFiles: 'templates/package/**/*' },
        { type: 'append', path: 'tsconfig.base.json', pattern: /"paths": \{/, template: '      "@acme/{{name}}": ["{{dest}}/{{name}}/src/index.ts"],' },
      ];
    },
  });
}
```

Usage:
```bash
turbo gen run package
```
