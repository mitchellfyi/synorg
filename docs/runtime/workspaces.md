# Workspace Management

The Workspace Management system provides isolated Git environments for agents to execute work safely and reliably. Each work item gets a temporary workspace where the agent can clone the repository, make changes, and create pull requests.

## Overview

When an agent claims a work item, the workspace lifecycle is:

1. **Provision** - Create a temporary directory
2. **Clone** - Clone the project repository using PAT authentication
3. **Branch** - Create a uniquely-named branch from the latest main
4. **Apply** - Apply changes (code, docs, configs)
5. **Commit** - Commit changes with a descriptive message
6. **Push** - Push the branch to GitHub
7. **PR** - Open a pull request for review
8. **Cleanup** - Remove the temporary workspace

## Architecture

### WorkspaceService

The `WorkspaceService` handles low-level Git operations:

- Provisioning temporary directories
- Cloning repositories with authentication
- Creating and checking out branches
- Committing and pushing changes

### WorkspaceRunner

The `WorkspaceRunner` orchestrates the full workflow:

- Manages the workspace lifecycle
- Implements branch naming conventions
- Handles idempotency and conflict resolution
- Integrates with GitHub API for PR creation
- Records run logs and artifacts

## Workspace Lifecycle

### 1. Provision

A temporary directory is created for the workspace:

```ruby
workspace_service = WorkspaceService.new(project)
workspace_service.provision
# => "/tmp/synorg-workspace-a3f8e9d2..."
```

Directory structure:
```
/tmp/synorg-workspace-{random}/
├── repo/              # Cloned repository
└── git-askpass.sh     # Temporary auth script
```

### 2. Clone Repository

The repository is cloned using the project's GitHub PAT:

```ruby
pat = Rails.application.credentials.dig(:github, :pat)
workspace_service.clone_repository(pat)
```

**Security considerations:**
- PAT is passed via `GIT_ASKPASS` environment variable, not CLI
- PAT is redacted from error logs
- Temporary askpass script is executable only by the process owner
- Shallow clone (`--depth 1`) minimizes disk usage and clone time

### 3. Create Branch

Branches follow the naming convention: `agent/<agent-key>-<timestamp>`

Examples:
- `agent/code-reviewer-20251109-143025`
- `agent/docs-writer-20251109-143530`

```ruby
branch_name = "agent/#{agent.key.parameterize}-#{timestamp}"
workspace_service.create_branch(branch_name)
```

**Naming rules:**
- Agent key is parameterized (lowercase, hyphens)
- Timestamp format: `YYYYMMDD-HHMMSS`
- Prefix `agent/` groups all agent branches together

### 4. Merge Latest Main

Before making changes, the branch is updated with the latest from main:

```ruby
# Fetch latest main
git fetch origin main

# Merge origin/main into current branch
git merge origin/main
```

This minimizes merge conflicts when the PR is eventually merged.

### 5. Apply Changes

Changes are applied to the working directory:

```ruby
changes = {
  files: [
    { path: "app/models/user.rb", content: "..." },
    { path: "spec/models/user_spec.rb", content: "..." }
  ]
}

# Files are written to disk
apply_changes(changes)
```

### 6. Commit

All changes are staged and committed:

```ruby
git add .
git commit -m "feat: implement user authentication"
```

### 7. Push Branch

The branch is pushed to GitHub:

```ruby
git push -u origin agent/code-reviewer-20251109-143025
```

### 8. Open Pull Request

A PR is created via the GitHub API:

```ruby
github_service.create_pull_request(
  title: "feat: implement user authentication",
  body: pr_body,
  head: branch_name,
  base: "main"
)
```

### 9. Cleanup

The workspace is cleaned up, regardless of success or failure:

```ruby
workspace_service.cleanup
# Removes entire /tmp/synorg-workspace-{random} directory
```

## Idempotency

The workspace runner implements idempotency to handle retries and prevent duplicate work.

### Idempotency Key

Each run generates a unique idempotency key based on:

```ruby
content_digest = Digest::SHA256.hexdigest([
  work_item.id,
  work_item.work_type,
  work_item.payload.to_json,
  agent.key
].join(":"))

idempotency_key = "run:#{work_item.id}:#{agent.key}:#{content_digest}"
```

### Idempotency Checks

Before executing, the runner checks if this exact work has already been completed:

```ruby
if Run.exists?(idempotency_key: idempotency_key, outcome: "success")
  # Already done, skip
  return true
end
```

### Branch Idempotency

If a branch already exists (from a previous attempt), the runner:

1. Checks out the existing branch
2. Merges the latest main
3. Applies new changes
4. Updates the existing PR (if it exists)

This handles cases where:
- The agent timed out but the branch was created
- The PR creation failed but commits were pushed
- The work needs to be retried with updated changes

## Concurrency Considerations

### Workspace Isolation

Each work item gets its own isolated workspace:

```ruby
# Work item 1
workspace1 = "/tmp/synorg-workspace-a3f8e9d2..."

# Work item 2 (concurrent)
workspace2 = "/tmp/synorg-workspace-b7c4d1f5..."
```

Multiple agents can work concurrently without interfering with each other.

### Git Push Conflicts

If two agents create branches with the same name (extremely rare due to timestamp), the second push will fail:

```ruby
git push -u origin agent/code-reviewer-20251109-143025
# => error: failed to push some refs
```

The runner handles this by:
1. Detecting the push failure
2. Marking the run as failed
3. Releasing the work item for retry (which will generate a new branch name)

### Database-Level Idempotency

The `runs` table enforces unique idempotency keys:

```sql
CREATE UNIQUE INDEX index_runs_on_idempotency_key
  ON runs (idempotency_key)
  WHERE idempotency_key IS NOT NULL;
```

If two workers try to create runs with the same key, one will fail with a unique constraint violation.

## Run Tracking

### Run Record

Each workspace execution creates a `Run` record:

```ruby
Run.create!(
  agent: agent,
  work_item: work_item,
  started_at: Time.current,
  idempotency_key: idempotency_key,
  outcome: nil  # Set to "success" or "failure" later
)
```

### Run Lifecycle

1. **Started** - `started_at` is set when the run begins
2. **In Progress** - Run is associated with the work item
3. **Completed** - `finished_at` and `outcome` are set
4. **Logged** - `logs` field contains execution details
5. **Artifacts** - `artifacts_url` points to PR or other outputs

### Example Run Record

```ruby
{
  id: 42,
  agent_id: 5,
  work_item_id: 23,
  started_at: "2025-11-09 14:30:25",
  finished_at: "2025-11-09 14:32:18",
  outcome: "success",
  idempotency_key: "run:23:code-reviewer:a8f3d...",
  logs: "Workspace execution completed successfully\nBranch created and pushed\nPull request created: https://...",
  artifacts_url: "https://github.com/example/repo/pull/87"
}
```

## Error Handling

### Graceful Failures

The workspace runner handles various failure scenarios:

#### Clone Failure

```ruby
unless workspace_service.clone_repository(pat)
  mark_failed("Failed to clone repository")
  cleanup
  return false
end
```

#### Merge Conflict

```ruby
unless merge_latest_main
  mark_failed("Merge conflict with main branch")
  cleanup
  return false
end
```

#### Push Failure

```ruby
unless push_branch(branch_name, pat)
  mark_failed("Failed to push branch")
  cleanup
  return false
end
```

### Cleanup Guarantee

Cleanup is guaranteed via `ensure` block:

```ruby
def execute(changes:)
  begin
    # Workspace operations...
  ensure
    workspace_service.cleanup
  end
end
```

Even if an exception is raised, the workspace is cleaned up.

## API Reference

### WorkspaceRunner.new(project:, agent:, work_item:)

Creates a new workspace runner.

**Parameters:**
- `project` - The project to work on
- `agent` - The agent performing the work
- `work_item` - The work item being processed

### WorkspaceRunner#execute(changes:)

Executes the work item in an isolated workspace.

**Parameters:**
- `changes` - Hash with:
  - `:message` - Commit message (optional, defaults to "feat: automated agent work")
  - `:pr_title` - PR title (optional, defaults to generated title)
  - `:pr_body` - PR body (optional, defaults to generated body)
  - `:files` - Array of file changes: `[{ path: "...", content: "..." }, ...]`

**Returns:**
- `true` if successful
- `false` if failed

**Side effects:**
- Creates/updates Run record
- Clones repository
- Creates/updates branch
- Pushes commits
- Opens/updates PR
- Cleans up workspace

**Example:**

```ruby
runner = WorkspaceRunner.new(
  project: project,
  agent: agent,
  work_item: work_item
)

success = runner.execute(
  changes: {
    message: "feat: add user authentication",
    pr_title: "Add JWT-based authentication",
    pr_body: "Implements secure JWT authentication for API endpoints",
    files: [
      {
        path: "app/controllers/auth_controller.rb",
        content: File.read("templates/auth_controller.rb")
      },
      {
        path: "spec/controllers/auth_controller_spec.rb",
        content: File.read("templates/auth_controller_spec.rb")
      }
    ]
  }
)

if success
  Rails.logger.info("Workspace execution completed successfully")
else
  Rails.logger.error("Workspace execution failed")
end
```

## Security

### Credential Management

PATs are stored securely:

```ruby
# Development: Rails encrypted credentials
Rails.application.credentials.dig(:github, :pat)

# Production: Environment variable or secret manager
ENV["GITHUB_PAT"]
```

### Credential Protection

- PATs never appear in CLI arguments (use `GIT_ASKPASS`)
- PATs are redacted from logs
- Temporary auth scripts are mode `0700` (owner-only)
- Auth scripts are cleaned up after use

### Workspace Security

- Workspaces are created in `/tmp` with secure random names
- Workspaces are isolated from each other
- Workspaces are cleaned up after use
- No shared state between concurrent workspaces

## Performance Optimization

### Shallow Clone

Repositories are cloned with `--depth 1` to minimize clone time and disk usage:

```bash
git clone --branch main --depth 1 https://github.com/example/repo.git
```

### Parallel Execution

Multiple agents can execute concurrently:

```ruby
# Agent 1
runner1.execute(changes: changes1)  # => /tmp/synorg-workspace-abc123

# Agent 2 (concurrent)
runner2.execute(changes: changes2)  # => /tmp/synorg-workspace-def456
```

### Resource Cleanup

Workspaces are cleaned up immediately after execution:

```ruby
# Before cleanup: ~500MB per workspace
workspace_service.cleanup
# After cleanup: 0MB
```

## Monitoring

### Key Metrics

- **Execution time**: Time from provision to cleanup
- **Clone time**: Time to clone repository
- **Push time**: Time to push branch
- **Success rate**: Percentage of successful executions
- **Workspace count**: Number of active workspaces

### Queries

```ruby
# Average execution time
Run.where(outcome: "success")
  .average("finished_at - started_at")

# Recent failures
Run.failed
  .where("started_at > ?", 1.hour.ago)
  .order(started_at: :desc)

# Active runs (not finished)
Run.where(finished_at: nil)
  .where("started_at > ?", 1.hour.ago)
```

## Best Practices

### 1. Keep Changes Focused

Each work item should make focused, atomic changes:

```ruby
# Good: Single responsibility
changes = {
  message: "feat: add user model",
  files: [
    { path: "app/models/user.rb", content: "..." },
    { path: "spec/models/user_spec.rb", content: "..." }
  ]
}

# Bad: Too many unrelated changes
changes = {
  message: "feat: add multiple features",
  files: [
    { path: "app/models/user.rb", content: "..." },
    { path: "app/controllers/admin_controller.rb", content: "..." },
    { path: "app/views/layouts/application.html.erb", content: "..." }
  ]
}
```

### 2. Use Descriptive Commit Messages

Follow Conventional Commits:

```ruby
# Good
"feat: add user authentication"
"fix: resolve login timeout issue"
"docs: update API documentation"

# Bad
"update files"
"changes"
```

### 3. Test Before Pushing

Run tests in the workspace before pushing:

```ruby
# In workspace
unless run_tests
  mark_failed("Tests failed")
  return false
end

# Then push
push_branch(branch_name, pat)
```

### 4. Handle Large Files

For large generated files, consider uploading to artifacts storage:

```ruby
if file_size > 10.megabytes
  # Upload to S3/GCS
  artifact_url = upload_artifact(file_content)
  
  # Reference in PR instead of committing
  pr_body += "\n\nArtifact: #{artifact_url}"
end
```

## Troubleshooting

### Common Issues

#### Clone Timeout

**Symptom**: Clone takes too long and times out

**Solution**: Check network connectivity, repository size, or increase timeout

#### Merge Conflict

**Symptom**: Cannot merge latest main into branch

**Solution**: Update the agent's logic to resolve conflicts, or alert for manual intervention

#### Push Rejected

**Symptom**: Push fails with "rejected" error

**Solution**: Fetch latest and rebase, or use a new branch name

#### Cleanup Failure

**Symptom**: Workspace directory not removed

**Solution**: Check file permissions and disk space

## Related Documentation

- [Assignment Service](/docs/runtime/assignment.md) - Work item assignment and queueing
- [GitHub Integration](/docs/integrations/github.md) - GitHub API and webhooks
- [Domain Model](/docs/domain/model.md) - Complete data model
