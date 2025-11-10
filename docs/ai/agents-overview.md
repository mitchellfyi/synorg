# Agents Overview

This document describes the AI agents implemented in Synorg, their purposes, triggers, and outputs.

## Overview

Synorg uses specialized AI agents to automate various aspects of project management, documentation, and development workflows. Each agent has a specific role and operates independently while contributing to the overall project lifecycle.

## Agent Architecture

### Location of Agent Files

- **Agent definitions**: `db/seeds/agents/{agent_name}.rb` - Contains agent prompts and configuration
- **Agent execution**: `app/services/agent_runner.rb` - Generic runner for all agents
- **Execution strategies**: `app/services/execution_strategies/` - Strategy pattern for different work types
- **Documentation**: `/docs/ai/agents-overview.md` (this file)

### Agent Execution

Agents are executed via `AgentRunner` which:
1. Reads the agent's prompt from the database (`agents.prompt` field)
2. Builds context from the project and work item
3. Calls the LLM service (`LlmService`) with the prompt and context
4. Parses the LLM's JSON response
5. Routes to the appropriate execution strategy based on `work_type`
6. Updates work item and run records with results

```ruby
# Example: Running the GTM Agent
agent = Agent.find_by_cached("gtm")  # Uses cached lookup
work_item = project.work_items.create!(work_type: "gtm", status: "pending")
runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
result = runner.run
# => { success: true, files_written: 2, ... }
```

**Key Components:**
- **`LlmService`**: Wraps OpenAI API calls, handles authentication and response parsing
- **`AgentRunner`**: Orchestrates agent execution, builds context, parses LLM responses
- **Execution Strategies**: Handle different work types (FileWriteStrategy, DatabaseStrategy, GitHubApiStrategy)

## The Five Core Agents

### 1. GTM (Go-To-Market) Agent

**Purpose**: Analyzes project briefs and generates product positioning, naming suggestions, and initial marketing strategy.

**Agent Key**: `gtm`

**Seed File**: `db/seeds/agents/gtm.rb`

**Input Triggers**:
- Manual execution with project brief
- Project state changes to "scoped"
- New project creation events

**Inputs**:
- Project brief (text description of the project)
- Existing documentation (optional)

**Outputs**:
- Product naming options (3-5 suggestions)
- Positioning statement
- Target audience definition
- Key differentiators
- **File**: `/docs/product/positioning.md`

**Usage Example**:
```ruby
# Via Rails console
agent = Agent.find_by_cached("gtm")  # Uses cached lookup
work_item = project.work_items.create!(work_type: "gtm", status: "pending")

runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
result = runner.run

puts "Result: #{result[:success] ? 'Success' : 'Failed'}"
puts "Files written: #{result[:files_written]&.count || 0}"
```

### 2. Product Manager Agent

**Purpose**: Interprets the project brief and GTM output to create an initial project scope with actionable work items.

**Agent Key**: `product-manager`

**Seed File**: `db/seeds/agents/product_manager.rb`

**Input Triggers**:
- After GTM agent completes
- Manual execution with project brief
- Project scope change requests

**Inputs**:
- Project brief
- GTM positioning output
- Existing work items (optional)

**Outputs**:
- Epic definition (high-level description)
- Work items (minimum 5 tasks)
- **Database**: `work_items` table with `type=task`

**Work Item Structure**:
```ruby
{
  type: "task",
  title: "Clear, action-oriented title",
  description: "Detailed description with context",
  status: "pending",
  priority: 1,
  github_issue_number: nil
}
```

**Usage Example**:
```ruby
# Via Rails console
agent = Agent.find_by_cached("product-manager")
work_item = project.work_items.create!(work_type: "orchestrator", status: "pending")

runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
result = runner.run

puts "Created #{result[:work_items_created] || 0} work items"
```

### 3. Issue Agent

**Purpose**: Reads work items from the database and creates corresponding GitHub issues.

**Agent Key**: `issue`

**Seed File**: `db/seeds/agents/issue.rb`

**Input Triggers**:
- After Product Manager agent creates work items
- Manual execution to sync pending work items
- Scheduled jobs (e.g., nightly sync)

**Inputs**:
- Work items with `type=task` and `github_issue_number IS NULL`
- GitHub repository configuration
- GitHub API token

**Outputs**:
- GitHub issues (one per work item)
- Updated work items with `github_issue_number`

**GitHub Issue Format**:
- **Title**: Work item title
- **Body**: Description + acceptance criteria + context
- **Labels**: `task`, `agent-created`

**Usage Example**:
```ruby
# Via Rails console
agent = Agent.find_by_cached("issue")
work_item = project.work_items.create!(work_type: "issue", status: "pending")

runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
result = runner.run

puts "Performed #{result[:operations_performed] || 0} GitHub operations"
```

### 4. Docs Agent

**Purpose**: Generates and maintains project documentation based on project context.

**Agent Key**: `docs`

**Seed File**: `db/seeds/agents/docs.rb`

**Input Triggers**:
- After GTM and Product Manager agents complete
- Manual execution for documentation updates
- Major project changes

**Inputs**:
- Project brief
- GTM positioning
- Work items (current scope)
- Existing documentation

**Outputs**:
- **File**: `README.md` (project overview, updated if needed)
- **File**: `/docs/stack.md` (technical stack documentation)
- **File**: `/docs/setup.md` (development setup guide)

**Usage Example**:
```ruby
# Via Rails console
agent = Agent.find_by_cached("docs")
work_item = project.work_items.create!(work_type: "docs", status: "pending")

runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
result = runner.run

puts "Wrote #{result[:files_written]&.count || 0} files"
```

### 5. Dev Tooling Agent

**Purpose**: Monitors the repository for missing or outdated development tooling and proposes improvements.

**Agent Key**: `dev-tooling`

**Seed File**: `db/seeds/agents/dev_tooling.rb`

**Input Triggers**:
- Scheduled runs (e.g., weekly)
- Manual execution for audits
- After major dependency updates

**Inputs**:
- Repository configuration files
- CI/CD workflow definitions
- Linting and testing configurations

**Outputs**:
- Recommendations for improvements
- GitHub issues with detailed proposals (when enabled)
- Pull requests with configuration updates (when enabled)

**Recommendation Categories**:
- Testing (e.g., Playwright, SimpleCov)
- Linting (e.g., RuboCop presets)
- CI/CD (e.g., workflow optimizations)
- Security (e.g., additional scans)

**Usage Example**:
```ruby
# Via Rails console
agent = Agent.find_by(key: "dev-tooling")
work_item = project.work_items.create!(work_type: "dev_tooling", status: "pending")

runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
result = runner.run

puts "Result: #{result[:message]}"
```

## Agent Execution Flow

### Typical Project Initialization Flow

```
1. GTM Agent
   ↓ (creates positioning.md)
2. Product Manager Agent
   ↓ (creates work_items)
3. Issue Agent
   ↓ (creates GitHub issues)
4. Docs Agent
   ↓ (updates documentation)
5. Dev Tooling Agent
   ↓ (audits and recommends)
```

### Manual Execution (Rails Console)

All agents can be run manually from the Rails console:

```ruby
# 1. Get a project
project = Project.find_by(slug: "your-project")

# 2. Run GTM Agent
gtm_agent = Agent.find_by_cached("gtm")
gtm_work_item = project.work_items.create!(work_type: "gtm", status: "pending")
gtm_runner = AgentRunner.new(agent: gtm_agent, project: project, work_item: gtm_work_item)
gtm_result = gtm_runner.run

# 3. Run Product Manager Agent (orchestrator)
pm_agent = Agent.find_by_cached("orchestrator")
pm_work_item = project.work_items.create!(work_type: "orchestrator", status: "pending")
pm_runner = AgentRunner.new(agent: pm_agent, project: project, work_item: pm_work_item)
pm_result = pm_runner.run

# 4. Run Issue Agent
issue_agent = Agent.find_by_cached("issue")
issue_work_item = project.work_items.create!(work_type: "issue", status: "pending")
issue_runner = AgentRunner.new(agent: issue_agent, project: project, work_item: issue_work_item)
issue_result = issue_runner.run

# 5. Run Docs Agent
docs_agent = Agent.find_by_cached("docs")
docs_work_item = project.work_items.create!(work_type: "docs", status: "pending")
docs_runner = AgentRunner.new(agent: docs_agent, project: project, work_item: docs_work_item)
docs_result = docs_runner.run
```

## Extending Agents

### Adding a New Agent

1. **Create seed file**: `db/seeds/agents/new_agent.rb` with agent definition and prompt
2. **Define execution strategy**: Ensure appropriate strategy exists in `app/services/execution_strategies/`
3. **Add work_type mapping**: Update `AgentRunner#resolve_strategy` if needed
4. **Add tests**: Test via `AgentRunner` spec or create specific tests
5. **Update this documentation**

### Modifying Agent Behavior

1. **Update seed file**: Modify `db/seeds/agents/{agent_name}.rb` to update the prompt
2. **Run seeds**: Execute `bin/rails db:seed` to update agent in database (seeds are idempotent)
3. **Clear cache**: Agent caching is automatically invalidated on update
4. **Test changes**: Run tests and manual verification via `AgentRunner`
5. **Document changes**: Update this file and agent-specific docs

### Agent Execution Flow

Agents are executed through `AgentRunner`:

```ruby
# 1. Find or create agent (via seeds)
agent = Agent.find_by_cached("gtm")  # Uses cached lookup

# 2. Create work item
work_item = project.work_items.create!(
  work_type: "gtm",
  status: "pending"
)

# 3. Run agent
runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
result = runner.run

# Result format:
# {
#   success: true/false,
#   message: "Description of what happened",
#   files_written: [...],  # For FileWriteStrategy
#   work_items_created: 5,  # For DatabaseStrategy
#   operations_performed: 2,  # For GitHubApiStrategy
#   # ... additional data based on execution strategy
# }
```

## Disabling Agents

### Temporary Disable

Comment out agent execution in automated workflows or skip in manual flows.

### Permanent Disable

1. Remove or comment out the service class
2. Remove automated triggers
3. Document the change

## Determinism and Testing

### Determinism Principle

Given the same inputs, agents should produce:
- Consistent structure and content
- Similar outputs (exact wording may vary with LLM integration)
- Predictable side effects (files created, database records)

### Testing Strategy

- **Unit tests**: Test individual methods and logic (`LlmService`, execution strategies)
- **Integration tests**: Test full `AgentRunner#run` execution flow
- **Fixtures**: Use consistent test data via FactoryBot
- **Mocking**: Mock external APIs (OpenAI, GitHub)

Example test:

```ruby
RSpec.describe AgentRunner do
  describe '#run' do
    let(:project) { create(:project) }
    let(:agent) { create(:agent, key: "test-agent", prompt: "Test prompt") }
    let(:work_item) { create(:work_item, project: project, work_type: "gtm") }
    let(:runner) { described_class.new(agent: agent, project: project, work_item: work_item) }

    before do
      # Mock OpenAI client
      mock_client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:chat).and_return({
        "choices" => [{"message" => {"content" => '{"type":"file_writes","files":[]}'}}],
        "usage" => {}
      })
    end

    it 'executes successfully' do
      result = runner.run
      expect(result[:success]).to be true
    end
  end
end
```

## Configuration

### Environment Variables

```bash
# Required for LLM integration
OPENAI_API_KEY=sk-...  # Set in Rails credentials: openai:api_key

# Required for GitHub operations (Issue Agent, GitHub API Strategy)
GITHUB_PAT=ghp_...  # Set in project.github_pat or Rails credentials

# Optional
RAILS_ENV=development
```

### Agent-Specific Configuration

Each agent's prompt is stored in the database (`agents.prompt` field) and can be updated via seed files:
- Agent seed files: `db/seeds/agents/{agent_name}.rb`
- LLM API key: Set in Rails credentials (`openai:api_key`) or `ENV["OPENAI_API_KEY"]`
- GitHub PAT: Set per-project in `projects.github_pat` or Rails credentials

## Future Enhancements

### Planned Features

- **Enhanced LLM Integration**: Additional model options and fine-tuning
- **Automated Triggers**: Set up background jobs for agent execution
- **Agent Orchestration**: Coordinator service to run agents in sequence
- **Web Interface**: UI for triggering and monitoring agents
- **Agent History**: Track agent executions and results
- **Agent Feedback Loop**: Learn from results to improve future runs

### Integration Points

- **GitHub Webhooks**: Trigger agents on repository events
- **Slack/Discord**: Send agent notifications to team channels
- **Project Management Tools**: Sync with Jira, Linear, etc.
- **Analytics**: Track agent effectiveness and outcomes

## Troubleshooting

### Agent Not Running

1. Check Rails logs: `tail -f log/development.log`
2. Verify inputs are correct
3. Check for missing dependencies
4. Ensure database is accessible

### GitHub Integration Issues

1. Verify `github_pat` is set on the project and valid
2. Check token has correct permissions (issues, pull requests, contents)
3. Verify repository name format: `owner/repo`
4. Check GitHub API rate limits
5. Ensure `GithubService` is properly configured

### File Creation Issues

1. Ensure directories exist or service creates them
2. Check file permissions
3. Verify disk space

## Support and Feedback

For issues or questions about agents:
1. Check agent prompt files (`db/seeds/agents/{agent_name}.rb`) for detailed behavior
2. Review `AgentRunner` and `LlmService` implementation
3. Check execution strategies in `app/services/execution_strategies/`
4. Run manual tests via Rails console
5. Check logs for error messages (structured logging via `StructuredLogger`)

## References

- [Agent Conventions](../../AGENTS.md)
- [GitHub Copilot Instructions](../../.github/copilot-instructions.md)
- [Development Setup](../setup-guide.md)
- [Domain Model](../domain/model.md)
- [Execution Strategies](../runtime/assignment.md)

---

*Last updated: November 2025*
