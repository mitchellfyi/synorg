# Agents Directory

This directory contains prompt files for the AI agents used in Synorg.

## Structure

Each agent has its own subdirectory containing:

- `prompt.md`: The agent's prompt file with instructions, examples, and best practices

## Available Agents

### 1. GTM (Go-To-Market) Agent
- **Directory**: `gtm/`
- **Purpose**: Analyzes project briefs and generates product positioning
- **Service**: `GtmAgentService` in `app/services/`

### 2. Product Manager Agent
- **Directory**: `product_manager/`
- **Purpose**: Creates actionable work items from project briefs
- **Service**: `ProductManagerAgentService` in `app/services/`

### 3. Issue Agent
- **Directory**: `issue/`
- **Purpose**: Syncs work items to GitHub issues
- **Service**: `IssueAgentService` in `app/services/`

### 4. Docs Agent
- **Directory**: `docs/`
- **Purpose**: Generates and maintains project documentation
- **Service**: `DocsAgentService` in `app/services/`

### 5. Dev Tooling Agent
- **Directory**: `dev_tooling/`
- **Purpose**: Audits and recommends development tooling improvements
- **Service**: `DevToolingAgentService` in `app/services/`

## Usage

Agents are executed through their service classes. See `docs/ai/agents-overview.md` for detailed documentation and examples.

Quick example:

```ruby
# Via Rails console
project_brief = "Your project description..."

# Run GTM Agent
service = GtmAgentService.new(project_brief)
result = service.run
```

## Demonstration

Run the demonstration script to see all agents in action:

```bash
bin/rails runner script/demo_agents.rb
```

## Modifying Prompts

To modify an agent's behavior:

1. Edit the relevant `prompt.md` file
2. Update the service class if needed (`app/services/`)
3. Test the changes
4. Document the modifications

## Documentation

- **Detailed overview**: `docs/ai/agents-overview.md`
- **Agent conventions**: `AGENTS.md`
- **Service classes**: `app/services/*_agent_service.rb`

## Future Development

These agents are currently implemented with stub logic. Future enhancements include:

- LLM integration for intelligent content generation
- Automated triggers based on project state
- Web interface for agent management
- Agent orchestration and workflow coordination
