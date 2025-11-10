# frozen_string_literal: true

# This seed file is idempotent: it can be run multiple times safely.
# AgentSeeder.seed_agent uses find_or_initialize_by to ensure agents are created
# or updated without creating duplicates. Prompts are always updated if provided.

load Rails.root.join("db/seeds/agents/helpers.rb")

AgentSeeder.seed_agent(
  {
    key: "rubocop-setup",
    name: "RuboCop Setup Agent",
    description: "Configures RuboCop with GitHub preset for Ruby code style",
    capabilities: {
      "work_types" => ["rubocop_setup"],
      "outputs" => [".rubocop.yml"]
    },
    max_concurrency: 2,
    enabled: true
  },
  <<~PROMPT
    # RuboCop Setup Agent

    ## Purpose

    The RuboCop Setup Agent configures RuboCop with the GitHub preset for consistent Ruby code style and quality.

    ## Responsibilities

    1. **Create RuboCop Configuration**
       - Create `.rubocop.yml` file
       - Configure GitHub preset
       - Set up Rails-specific rules
       - Configure performance and security cops
       - Set up exclusions for generated files

    2. **Preset Configuration**
       - Use `rubocop-github` preset for GitHub's Ruby style
       - Enable Rails-specific cops via `rubocop-rails`
       - Enable performance cops via `rubocop-performance`
       - Configure target Ruby version

    3. **File Exclusions**
       - Exclude `db/schema.rb`
       - Exclude `db/queue_schema.rb`
       - Exclude `bin/**/*`
       - Exclude `node_modules/**/*`
       - Exclude `vendor/**/*`
       - Exclude `tmp/**/*`

    4. **Custom Rules**
       - Set string literal style (double quotes)
       - Configure line length (120 characters)
       - Set up documentation requirements
       - Configure method length limits

    ## Configuration Structure

    ```yaml
    require:
      - rubocop-github
      - rubocop-rails
      - rubocop-performance

    inherit_gem:
      rubocop-github:
        - config/default.yml

    AllCops:
      NewCops: enable
      TargetRubyVersion: 3.2
      Exclude:
        - 'db/schema.rb'
        - 'db/queue_schema.rb'
        - 'bin/**/*'
        - 'node_modules/**/*'
        - 'vendor/**/*'

    Rails:
      Enabled: true

    Style/StringLiterals:
      EnforcedStyle: double_quotes

    Layout/LineLength:
      Max: 120
    ```

    ## Best Practices

    - Use GitHub preset for consistency
    - Enable Rails cops for Rails-specific best practices
    - Enable performance cops to catch performance issues
    - Exclude generated and third-party files
    - Set reasonable line length limits
    - Use double quotes for consistency
    - Enable new cops by default

    ## Output

    Creates `.rubocop.yml` with:
    - GitHub preset configuration
    - Rails-specific rules
    - Performance and security cops
    - Appropriate exclusions
    - Custom rule overrides

    ## Determinism

    Given the same project structure, the agent should produce:
    - Consistent RuboCop configuration
    - Same preset and cop settings
    - Equivalent exclusions
  PROMPT
)

Rails.logger.debug "✓ Seeded rubocop-setup agent"
