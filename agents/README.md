# Agents Directory

This directory contains prompt files for the AI agents used in Synorg.

## Structure

Each agent has its own subdirectory containing:

- `prompt.md`: The agent's prompt file with instructions, examples, and best practices

## Available Agents

### 1. GTM (Go-To-Market) Agent
- **Directory**: `gtm/`
- **Purpose**: Analyzes project briefs and generates product positioning
- **Key**: `gtm`

### 2. Product Manager Agent
- **Directory**: `product_manager/`
- **Purpose**: Creates actionable work items from project briefs
- **Key**: `product-manager`

### 3. Issue Agent
- **Directory**: `issue/`
- **Purpose**: Syncs work items to GitHub issues
- **Key**: `issue`

### 4. Docs Agent
- **Directory**: `docs/`
- **Purpose**: Generates and maintains project documentation
- **Key**: `docs`

### 5. Dev Tooling Agent
- **Directory**: `dev_tooling/`
- **Purpose**: Audits and recommends development tooling improvements
- **Key**: `dev-tooling`

## Usage

Agents are executed through AgentRunner. All agents are seeded via `bin/rails db:seed`.
See `docs/ai/agents-overview.md` for detailed documentation and examples.

Quick example:

```ruby
# Via Rails console
project = Project.find_by(slug: "your-project")
agent = Agent.find_by(key: "gtm")
work_item = project.work_items.create!(work_type: "gtm", status: "pending")

# Run agent via AgentRunner
runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
result = runner.run
```

## Modifying Prompts

To modify an agent's behavior:

1. Edit the relevant seed file in `db/seeds/agents/`
2. Run `bin/rails db:seed` to update the agent's prompt
3. Test the changes via AgentRunner
4. Document the modifications

## Documentation

- **Detailed overview**: `docs/ai/agents-overview.md`
- **Agent conventions**: `AGENTS.md`
- **AgentRunner**: `app/services/agent_runner.rb`
- **Seeds**: `db/seeds/agents/*.rb`

## Setup

All agents are seeded automatically when you run:

```bash
bin/rails db:seed
```

This loads all agent definitions from `db/seeds/agents/*.rb` files. Agents are global resources that can be used by any project.
