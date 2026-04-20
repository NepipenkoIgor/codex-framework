# Nx Configuration and Patterns

## nx.json Configuration

```json
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "cache": true,
      "inputs": ["production", "^production"],
      "outputs": ["{projectRoot}/dist"]
    },
    "test": {
      "cache": true,
      "inputs": ["default", "^production", "{workspaceRoot}/jest.preset.js"]
    },
    "lint": {
      "cache": true,
      "inputs": ["default", "{workspaceRoot}/.eslintrc.json", "{workspaceRoot}/.eslintignore"]
    }
  },
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": ["default", "!{projectRoot}/**/*.spec.ts", "!{projectRoot}/tsconfig.spec.json"],
    "sharedGlobals": ["{workspaceRoot}/tsconfig.base.json"]
  },
  "affected": {
    "defaultBase": "main"
  }
}
```

## Integrated Monorepo Structure (Nx-style)

```
monorepo/
  nx.json                    # Nx configuration
  package.json
  tsconfig.base.json         # Base TypeScript config
  libs/
    shared/
      data-access/           # API clients, stores
      ui/                    # Shared components
      utils/                 # Utility functions
      types/                 # Shared TypeScript types
    feature/
      auth/                  # Auth feature library
      dashboard/             # Dashboard feature library
  apps/
    web/
    api/
  tools/
    generators/              # Nx generators for scaffolding
```

## Module Boundary Enforcement

```json
// nx.json or .eslintrc.json
{
  "rules": {
    "@nx/enforce-module-boundaries": ["error", {
      "depConstraints": [
        { "sourceTag": "type:app", "onlyDependOnLibsWithTags": ["type:feature", "type:shared"] },
        { "sourceTag": "type:feature", "onlyDependOnLibsWithTags": ["type:shared"] },
        { "sourceTag": "type:shared", "onlyDependOnLibsWithTags": ["type:shared"] },
        { "sourceTag": "scope:web", "notDependOnLibsWithTags": ["scope:api"] },
        { "sourceTag": "scope:api", "notDependOnLibsWithTags": ["scope:web"] }
      ]
    }]
  }
}
```

## Affected Commands

```bash
# Affected by changes since main
nx affected --target=build
nx affected --target=test
nx affected --target=lint
```

## Nx Cloud (Remote Caching)

```bash
# Setup
npx nx connect-to-nx-cloud

# nx.json -- automatically configured
{
  "nxCloudAccessToken": "..." // or set NX_CLOUD_ACCESS_TOKEN env var
}
```

Benefits:
- Free tier: 500 computation hours/month
- CI and local cache sharing -- build once, use everywhere
- Distributed task execution (DTE) -- split tasks across CI agents

## Distributed Task Execution (DTE)

For large monorepos where a single CI runner is too slow:

```yaml
# Split tasks across multiple CI agents
jobs:
  agents:
    strategy:
      matrix:
        agent: [1, 2, 3]
    steps:
      - run: npx nx-cloud start-agent

  main:
    steps:
      - run: npx nx-cloud start-ci-run --distribute-on="3 linux-medium-js"
      - run: npx nx affected --target=build --parallel=3
      - run: npx nx affected --target=test --parallel=3
      - run: npx nx-cloud stop-all-agents
```

## Task Graph Visualization

```bash
# Open interactive graph in browser
nx graph

# Focus on a specific project and its dependencies
nx graph --focus=web

# See what would run and in what order
nx run-many --target=build --all --verbose
```

## Nx Generators (Custom Workspace Plugin)

```
tools/workspace-plugin/
  src/
    generators/
      library/
        generator.ts
        schema.json
        schema.d.ts
        files/
          src/
            index.ts.template
            __name__.ts.template
          package.json.template
          tsconfig.json.template
          jest.config.ts.template
          README.md.template
```

Generator schema (`schema.json`):
```json
{
  "$schema": "https://json-schema.org/schema",
  "type": "object",
  "properties": {
    "name": { "type": "string", "description": "Library name", "$default": { "$source": "argv", "index": 0 } },
    "scope": { "type": "string", "enum": ["shared", "feature"], "description": "Library scope" },
    "platform": { "type": "string", "enum": ["web", "server", "universal"], "default": "universal" }
  },
  "required": ["name", "scope"]
}
```

Generator logic (`generator.ts`):
```typescript
import { Tree, formatFiles, generateFiles, names, joinPathFragments, updateJson } from '@nx/devkit';
import { LibraryGeneratorSchema } from './schema';

export default async function libraryGenerator(tree: Tree, options: LibraryGeneratorSchema) {
  const { className, propertyName, fileName } = names(options.name);
  const projectRoot = joinPathFragments('packages', `${options.scope}-${fileName}`);

  // Generate files from templates
  generateFiles(tree, joinPathFragments(__dirname, 'files'), projectRoot, {
    ...options, className, propertyName, fileName, tmpl: '',
  });

  // Add path alias to root tsconfig
  updateJson(tree, 'tsconfig.base.json', (json) => {
    json.compilerOptions.paths[`@acme/${options.scope}-${fileName}`] =
      [`${projectRoot}/src/index.ts`];
    return json;
  });

  await formatFiles(tree);
}
```

Usage:
```bash
nx generate @acme/workspace-plugin:library --name=payments --scope=feature --platform=server
```
