# Shared Configuration Management

## TypeScript Config

Base config at root, extended by each package:

```json
// tsconfig.base.json (root)
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "paths": {
      "@acme/shared-types": ["packages/shared-types/src/index.ts"],
      "@acme/ui": ["packages/ui/src/index.ts"],
      "@acme/utils": ["packages/utils/src/index.ts"]
    }
  }
}
```

```json
// apps/web/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "jsx": "react-jsx"
  },
  "include": ["src/**/*"],
  "references": [
    { "path": "../../packages/shared-types" },
    { "path": "../../packages/ui" }
  ]
}
```

## ESLint Config

Shared config package:

```json
// config/eslint/base.js
module.exports = {
  parser: '@typescript-eslint/parser',
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended', 'prettier'],
  rules: {
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
  },
};

// config/eslint/react.js
module.exports = {
  extends: ['./base.js', 'plugin:react/recommended', 'plugin:react-hooks/recommended'],
  // React-specific rules
};

// config/eslint/node.js
module.exports = {
  extends: ['./base.js', 'plugin:node/recommended'],
  // Node-specific rules
};
```

Consuming in packages:
```json
// apps/web/.eslintrc.json
{ "extends": ["../../config/eslint/react.js"] }

// apps/api/.eslintrc.json
{ "extends": ["../../config/eslint/node.js"] }
```

## Prettier Config

Single config at root -- all packages use it:

```json
// .prettierrc (root)
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2
}
```

## pnpm Workspace

```yaml
# pnpm-workspace.yaml
packages:
  - 'apps/*'
  - 'packages/*'
  - 'tools/*'
```
