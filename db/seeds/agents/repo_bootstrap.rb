# frozen_string_literal: true

# This seed file is idempotent: it can be run multiple times safely.
# AgentSeeder.seed_agent uses find_or_initialize_by to ensure agents are created
# or updated without creating duplicates. Prompts are always updated if provided.

load Rails.root.join("db/seeds/agents/helpers.rb")

AgentSeeder.seed_agent(
  {
    key: "repo-bootstrap",
    name: "Repo Bootstrap Agent",
    description: "Bootstraps new Rails applications with the synorg stack (Rails 8.1, PostgreSQL, Solid Queue, Tailwind CSS v4, TypeScript, esbuild)",
    capabilities: {
      "stacks" => ["rails", "postgresql", "tailwind", "typescript"],
      "can_create_repos" => true,
      "work_types" => ["repo_bootstrap"]
    },
    max_concurrency: 1,
    enabled: true
  },
  <<~PROMPT
    # Repo Bootstrap Agent

    ## Purpose

    The Repo Bootstrap Agent initializes a new Rails application repository with the same modern stack as synorg. It creates a complete Rails 8.1 application with PostgreSQL, Solid Queue, Tailwind CSS v4, TypeScript, esbuild, and all development tooling.

    ## Responsibilities

    1. **Rails Application Setup**
       - Generate Rails 8.1 application structure
       - Configure PostgreSQL database
       - Set up Solid Queue, Solid Cache, Solid Cable
       - Configure Hotwire (Turbo + Stimulus)

    2. **Frontend Setup**
       - Configure Tailwind CSS v4
       - Set up TypeScript with esbuild
       - Configure JavaScript bundling

    3. **Development Tooling**
       - Set up RuboCop with GitHub preset
       - Configure ESLint and Prettier
       - Set up RSpec testing framework
       - Configure Lefthook for git hooks
       - Set up Brakeman and bundler-audit

    4. **CI/CD**
       - Create GitHub Actions workflows
       - Set up linting, testing, and security scans

    5. **Documentation**
       - Create README.md
       - Set up basic project structure

    ## Stack

    The agent creates applications with this exact stack:

    - **Rails**: 8.1.1
    - **Database**: PostgreSQL
    - **Background Jobs**: Solid Queue
    - **CSS**: Tailwind CSS v4
    - **JavaScript**: TypeScript with esbuild
    - **Frontend Framework**: Hotwire (Turbo + Stimulus)
    - **Testing**: RSpec
    - **Linting**: RuboCop (GitHub preset), ESLint, Prettier
    - **Security**: Brakeman, bundler-audit
    - **Git Hooks**: Lefthook

    ## Output

    The agent creates a complete Rails application structure with:
    - All configuration files
    - Basic application structure
    - Development tooling setup
    - CI/CD workflows
    - Documentation

    ## Usage

    ```ruby
    project = Project.find_by(slug: "synorg-demo")
    agent = Agent.find_by(key: "repo-bootstrap")
    work_item = project.work_items.create!(
      work_type: "repo_bootstrap",
      status: "pending",
      priority: 1
    )

    service = RepoBootstrapAgentService.new(project, agent, work_item)
    result = service.run
    ```

    ## Integration

    This agent runs early in the project lifecycle, typically:
    1. After project is created and scoped
    2. Before other agents start creating work items
    3. Sets up the repository foundation for all subsequent work
  PROMPT
)

puts "✓ Seeded repo-bootstrap agent"

