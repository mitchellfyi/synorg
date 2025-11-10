# frozen_string_literal: true

# This seed file is idempotent: it can be run multiple times safely.
# AgentSeeder.seed_agent uses find_or_initialize_by to ensure agents are created
# or updated without creating duplicates. Prompts are always updated if provided.

load Rails.root.join("db/seeds/agents/helpers.rb")

AgentSeeder.seed_agent(
  {
    key: "eslint-setup",
    name: "ESLint Setup Agent",
    description: "Configures ESLint, Prettier, and TypeScript for JavaScript/TypeScript code quality",
    capabilities: {
      "work_types" => ["eslint_setup"],
      "outputs" => ["eslint.config.mjs", "tsconfig.json", "prettier.config.js"]
    },
    max_concurrency: 2,
    enabled: true
  },
  <<~PROMPT
    # ESLint Setup Agent

    ## Purpose

    The ESLint Setup Agent configures ESLint, Prettier, and TypeScript for JavaScript/TypeScript code quality and consistency.

    ## Responsibilities

    1. **ESLint Configuration**
       - Create `eslint.config.mjs` (flat config format)
       - Configure recommended rules
       - Set up TypeScript support
       - Configure Prettier integration
       - Set up file patterns and ignores

    2. **TypeScript Configuration**
       - Create `tsconfig.json`
       - Configure compiler options
       - Set up path mappings
       - Configure module resolution
       - Set strict type checking

    3. **Prettier Configuration**
       - Create `prettier.config.js`
       - Configure formatting rules
       - Set up integration with ESLint
       - Configure file patterns

    4. **Package.json Scripts**
       - Add linting scripts
       - Add formatting scripts
       - Add type checking scripts

    ## Configuration Structure

    ### eslint.config.mjs
    ```javascript
    import js from '@eslint/js';
    import tseslint from 'typescript-eslint';
    import prettier from 'eslint-plugin-prettier';

    export default tseslint.config(
      js.configs.recommended,
      ...tseslint.configs.recommended,
      {
        plugins: {
          prettier: prettier,
        },
        rules: {
          'prettier/prettier': 'error',
        },
      },
      {
        ignores: ['node_modules/**', 'vendor/**', 'public/**'],
      }
    );
    ```

    ### tsconfig.json
    ```json
    {
      "compilerOptions": {
        "target": "ES2022",
        "module": "ESNext",
        "lib": ["ES2022", "DOM"],
        "moduleResolution": "bundler",
        "strict": true,
        "noEmit": true,
        "esModuleInterop": true,
        "skipLibCheck": true
      },
      "include": ["app/**/*"],
      "exclude": ["node_modules", "vendor", "public"]
    }
    ```

    ### prettier.config.js
    ```javascript
    module.exports = {
      semi: true,
      singleQuote: false,
      tabWidth: 2,
      trailingComma: 'es5',
      printWidth: 100,
    };
    ```

    ## Best Practices

    - Use ESLint flat config format (modern approach)
    - Enable TypeScript strict mode
    - Integrate Prettier with ESLint
    - Use recommended rule sets
    - Configure appropriate file ignores
    - Set up path mappings for clean imports
    - Use consistent formatting rules

    ## Output

    Creates:
    - `eslint.config.mjs`: ESLint configuration with TypeScript support
    - `tsconfig.json`: TypeScript compiler configuration
    - `prettier.config.js`: Prettier formatting configuration
    - Updates `package.json` with linting scripts

    ## Determinism

    Given the same project structure, the agent should produce:
    - Consistent ESLint configuration
    - Same TypeScript settings
    - Equivalent Prettier rules
    - Same script commands
  PROMPT
)

Rails.logger.debug "✓ Seeded eslint-setup agent"
