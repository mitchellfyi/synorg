# Agents Overview

This document describes the AI agents implemented in Synorg, their purposes, triggers, and outputs.

## Overview

Synorg uses specialized AI agents to automate various aspects of project management, documentation, and development workflows. Each agent has a specific role and operates independently while contributing to the overall project lifecycle.

## Agent Architecture

### Location of Agent Files

- **Prompt files**: `/agents/{agent_name}/prompt.md`
- **Service classes**: `/app/services/{agent_name}_agent_service.rb`
- **Documentation**: `/docs/ai/agents-overview.md` (this file)

### Agent Execution

Agents can be executed manually via Rails console or automated through various triggers. Each agent service follows a consistent interface:

```ruby
# Example: Running the GTM Agent
service = GtmAgentService.new(project_brief)
result = service.run
# => { success: true, ... }
```

## The Five Core Agents

### 1. GTM (Go-To-Market) Agent

**Purpose**: Analyzes project briefs and generates product positioning, naming suggestions, and initial marketing strategy.

**Service Class**: `GtmAgentService`

**Prompt Location**: `/agents/gtm/prompt.md`

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
project_brief = <<~TEXT
  A collaborative task management tool for remote teams that emphasizes
  asynchronous communication and time zone awareness.
TEXT

service = GtmAgentService.new(project_brief)
result = service.run

puts "Positioning written to: #{result[:file_path]}"
# => "Positioning written to: /docs/product/positioning.md"
```

### 2. Product Manager Agent

**Purpose**: Interprets the project brief and GTM output to create an initial project scope with actionable work items.

**Service Class**: `ProductManagerAgentService`

**Prompt Location**: `/agents/product_manager/prompt.md`

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
service = ProductManagerAgentService.new(project_brief)
result = service.run

puts "Created #{result[:work_items_created]} work items"
work_items = WorkItem.where(id: result[:work_item_ids])
work_items.each { |wi| puts "- #{wi.title}" }
```

### 3. Issue Agent

**Purpose**: Reads work items from the database and creates corresponding GitHub issues.

**Service Class**: `IssueAgentService`

**Prompt Location**: `/agents/issue/prompt.md`

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
service = IssueAgentService.new
result = service.run

puts "Created #{result[:issues_created]} GitHub issues"
puts "Issue numbers: #{result[:issue_numbers].join(', ')}"
```

**Note**: Currently stubbed. To enable real GitHub integration:
1. Set `GITHUB_TOKEN` environment variable
2. Set `GITHUB_REPOSITORY` environment variable (e.g., `owner/repo`)
3. Uncomment the Octokit integration code in the service

### 4. Docs Agent

**Purpose**: Generates and maintains project documentation based on project context.

**Service Class**: `DocsAgentService`

**Prompt Location**: `/agents/docs/prompt.md`

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
service = DocsAgentService.new(project_brief)
result = service.run

puts "Updated files:"
result[:files_updated].each { |file| puts "- #{file}" }
```

### 5. Dev Tooling Agent

**Purpose**: Monitors the repository for missing or outdated development tooling and proposes improvements.

**Service Class**: `DevToolingAgentService`

**Prompt Location**: `/agents/dev_tooling/prompt.md`

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
service = DevToolingAgentService.new
result = service.run

puts "Found #{result[:recommendations_count]} recommendations:"
result[:recommendations].each do |rec|
  puts "- [#{rec[:priority].upcase}] #{rec[:title]}"
end
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
# 1. Start with a project brief
project_brief = "Your project description here..."

# 2. Run GTM Agent
gtm = GtmAgentService.new(project_brief)
gtm_result = gtm.run

# 3. Run Product Manager Agent
pm = ProductManagerAgentService.new(project_brief)
pm_result = pm.run

# 4. Run Issue Agent
issue = IssueAgentService.new
issue_result = issue.run

# 5. Run Docs Agent
docs = DocsAgentService.new(project_brief)
docs_result = docs.run

# 6. Run Dev Tooling Agent
dev = DevToolingAgentService.new
dev_result = dev.run
```

## Extending Agents

### Adding a New Agent

1. **Create prompt file**: `/agents/new_agent/prompt.md`
2. **Create service class**: `/app/services/new_agent_service.rb`
3. **Implement `#run` method** with consistent interface
4. **Add tests**: `/spec/services/new_agent_service_spec.rb`
5. **Update this documentation**

### Modifying Agent Behavior

1. **Update prompt file**: Modify `/agents/{agent_name}/prompt.md`
2. **Update service logic**: Modify `/app/services/{agent_name}_agent_service.rb`
3. **Test changes**: Run tests and manual verification
4. **Document changes**: Update this file and agent-specific docs

### Agent Service Interface

All agent services should implement:

```ruby
class MyAgentService
  def initialize(*args)
    # Setup with required inputs
  end

  def run
    # Main execution logic
    # Returns hash with :success, :message, and relevant data
    {
      success: true,
      message: "Operation completed",
      # ... additional data
    }
  rescue StandardError => e
    {
      success: false,
      error: e.message
    }
  end

  private

  def read_prompt
    # Read agent's prompt.md file
  end

  # ... other private methods
end
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

- **Unit tests**: Test individual methods and logic
- **Integration tests**: Test full `#run` execution
- **Fixtures**: Use consistent test data
- **Mocking**: Mock external APIs (GitHub, LLM)

Example test:

```ruby
RSpec.describe ProductManagerAgentService do
  describe '#run' do
    let(:project_brief) { "Test project" }
    let(:service) { described_class.new(project_brief) }

    it 'creates work items' do
      expect { service.run }.to change(WorkItem, :count).by_at_least(5)
    end

    it 'returns success response' do
      result = service.run
      expect(result[:success]).to be true
      expect(result[:work_items_created]).to be >= 5
    end
  end
end
```

## Configuration

### Environment Variables

```bash
# Required for Issue Agent (when enabled)
GITHUB_TOKEN=ghp_your_token_here
GITHUB_REPOSITORY=owner/repo

# Optional
RAILS_ENV=development
```

### Agent-Specific Configuration

Each agent may have additional configuration in:
- Rails credentials: `bin/rails credentials:edit`
- Environment variables
- Agent prompt files

## Future Enhancements

### Planned Features

- **LLM Integration**: Replace stubbed implementations with real LLM calls
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

1. Verify `GITHUB_TOKEN` is set and valid
2. Check token has correct permissions
3. Verify repository name format: `owner/repo`
4. Check GitHub API rate limits

### File Creation Issues

1. Ensure directories exist or service creates them
2. Check file permissions
3. Verify disk space

## Support and Feedback

For issues or questions about agents:
1. Check agent prompt files for detailed behavior
2. Review service class implementation
3. Run manual tests via Rails console
4. Check logs for error messages

## References

- [Agent Conventions](../../AGENTS.md)
- [GitHub Copilot Instructions](../../.github/copilot-instructions.md)
- [Development Setup](../setup.md)
- [Technology Stack](../stack.md)

---

*Last updated: #{Time.current.to_s(:long)}*
