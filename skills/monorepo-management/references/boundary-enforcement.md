# Package Boundary Enforcement (without Nx)

## ESLint Restricted Imports

For Turborepo / pnpm workspaces without Nx module boundaries:

```json
// apps/web/.eslintrc.json
{
  "rules": {
    "no-restricted-imports": ["error", {
      "patterns": [
        { "group": ["@acme/api", "@acme/api/*"], "message": "Web app cannot import from API app" },
        { "group": ["../../apps/*"], "message": "Do not use relative imports to other apps" },
        { "group": ["../**/node_modules/**"], "message": "Do not import from nested node_modules" }
      ]
    }]
  }
}
```

## Dependency Cruiser

Standalone boundary enforcement for any monorepo:

```bash
npx depcruise --config .dependency-cruiser.cjs apps/ packages/
```

Config (`.dependency-cruiser.cjs`):
```js
module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
    {
      name: 'no-app-to-app',
      severity: 'error',
      comment: 'Apps must not import from other apps',
      from: { path: '^apps/([^/]+)' },
      to: { path: '^apps/(?!\\1)', pathNot: 'node_modules' },
    },
    {
      name: 'no-feature-cross-import',
      severity: 'error',
      comment: 'Feature packages must not import from other feature packages',
      from: { path: '^packages/feature-([^/]+)' },
      to: { path: '^packages/feature-(?!\\1)', pathNot: 'node_modules' },
    },
    {
      name: 'shared-no-feature-import',
      severity: 'error',
      comment: 'Shared packages must not import from feature packages',
      from: { path: '^packages/shared-' },
      to: { path: '^packages/feature-' },
    },
  ],
};
```

Run in CI:
```yaml
- name: Check dependency boundaries
  run: npx depcruise --output-type err-only --config .dependency-cruiser.cjs apps/ packages/
```

## Circular Dependency Detection

```bash
# madge -- fast circular dependency detection
npx madge --circular --extensions ts,tsx apps/ packages/

# Nx -- built-in cycle detection
nx graph  # cycles highlighted in red

# dependency-cruiser
npx depcruise --output-type err-only --config .dependency-cruiser.cjs .
```

Run circular detection in CI as a blocking check. Cycles between packages indicate a design problem -- extract shared code to a new package.

## Plop.js (Framework-Agnostic Generators)

Works with any monorepo -- no Nx or Turborepo required:

```bash
pnpm add -Dw plop
```

`plopfile.cjs`:
```js
module.exports = function (plop) {
  plop.setGenerator('package', {
    description: 'Create a new workspace package',
    prompts: [
      { type: 'input', name: 'name', message: 'Package name:' },
      { type: 'list', name: 'type', choices: ['lib', 'app'], message: 'Type:' },
    ],
    actions: (data) => {
      const dest = data.type === 'lib' ? 'packages' : 'apps';
      return [
        { type: 'addMany', destination: `${dest}/{{name}}/`, base: 'templates/package', templateFiles: 'templates/package/**/*' },
      ];
    },
  });
};
```
