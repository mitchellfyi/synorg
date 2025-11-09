# Assignment Service

The Assignment Service is responsible for distributing work items to agents in a safe, concurrent, and prioritized manner. It uses PostgreSQL row-level locking to ensure that work items are claimed exactly once, even under high concurrency.

## Overview

The assignment model follows a queue-based architecture where:

1. Work items are created with a `pending` status and a priority level
2. Multiple agents can request work concurrently
3. The service uses `SELECT FOR UPDATE SKIP LOCKED` to claim work items atomically
4. Once claimed, a work item transitions to `in_progress` and is locked to a specific agent
5. Upon completion, the work item is marked as `completed` or `failed` and unlocked

## Architecture

### Work Item States

Work items progress through these states:

- **pending**: Waiting to be claimed by an agent
- **in_progress**: Currently being processed by an agent
- **completed**: Successfully finished by an agent
- **failed**: Processing failed (can be retried)

### Locking Mechanism

The service uses PostgreSQL's `FOR UPDATE SKIP LOCKED` clause to implement optimistic, wait-free locking:

```ruby
work_item = WorkItem
  .pending
  .unlocked
  .by_priority
  .lock("FOR UPDATE SKIP LOCKED")
  .first
```

**How it works:**

1. `FOR UPDATE` acquires a row-level lock on the selected row within a transaction
2. `SKIP LOCKED` skips any rows that are already locked by other transactions
3. Multiple concurrent requests will each get a different unlocked row (or `nil` if none available)
4. The transaction commits after updating the work item status and creating a run record

This approach ensures:
- **No waiting**: Agents never block waiting for locks
- **No duplicates**: Each work item is claimed by exactly one agent
- **High throughput**: Multiple agents can claim different work items simultaneously

### Priority Handling

Work items are ordered by:

1. **Priority** (descending) - higher priority values are processed first
2. **Created at** (ascending) - older items at the same priority level are processed first

```ruby
scope :by_priority, -> { order(priority: :desc, created_at: :asc) }
```

## API Reference

### `AssignmentService.lease_next_work_item(agent)`

Claims the next available work item for the specified agent.

**Parameters:**
- `agent` (Agent) - The agent requesting work

**Returns:**
- `WorkItem` - The claimed work item, or `nil` if none available

**Side effects:**
- Updates work item status to `in_progress`
- Sets `locked_at` timestamp
- Sets `locked_by_agent` reference
- Creates a `Run` record with `started_at` timestamp

**Example:**

```ruby
agent = Agent.find_by(key: "code-reviewer")
work_item = AssignmentService.lease_next_work_item(agent)

if work_item
  # Process the work item
  perform_work(work_item)
  
  # Complete it
  run = work_item.runs.in_progress.first
  AssignmentService.complete_work_item(work_item, run, outcome: "success")
else
  # No work available
  Rails.logger.info("No work items available for #{agent.key}")
end
```

### `AssignmentService.release_work_item(work_item)`

Releases a locked work item (typically on timeout or error before completion).

**Parameters:**
- `work_item` (WorkItem) - The work item to release

**Side effects:**
- Clears `locked_at` timestamp
- Clears `locked_by_agent` reference
- Work item returns to the queue for another agent to claim

**Example:**

```ruby
begin
  perform_work(work_item)
rescue TimeoutError => e
  # Release the work item so another agent can try
  AssignmentService.release_work_item(work_item)
  raise
end
```

### `AssignmentService.complete_work_item(work_item, run, outcome:)`

Marks a work item as completed with the specified outcome.

**Parameters:**
- `work_item` (WorkItem) - The work item to complete
- `run` (Run) - The associated run record
- `outcome` (String) - Either `"success"` or `"failure"`

**Side effects:**
- Updates work item status to `completed` (success) or `failed` (failure)
- Clears lock fields (`locked_at`, `locked_by_agent`)
- Updates run record with `finished_at` timestamp and outcome

**Example:**

```ruby
run = work_item.runs.in_progress.first

begin
  result = perform_work(work_item)
  AssignmentService.complete_work_item(work_item, run, outcome: "success")
rescue StandardError => e
  AssignmentService.complete_work_item(work_item, run, outcome: "failure")
end
```

## Concurrency Guarantees

### Multiple Workers

The assignment service is designed to be safe under high concurrency:

```ruby
# Even if 10 workers call this simultaneously,
# each will get a unique work item (or nil)
10.times.map do
  Thread.new do
    agent = Agent.find(...)
    AssignmentService.lease_next_work_item(agent)
  end
end.each(&:join)
```

**Guarantees:**
- Each work item is claimed by at most one agent
- No deadlocks or race conditions
- No waiting or blocking (thanks to `SKIP LOCKED`)

### Database Transaction Isolation

All operations are wrapped in database transactions to ensure atomicity:

```ruby
WorkItem.transaction do
  work_item = WorkItem.pending.unlocked.lock("FOR UPDATE SKIP LOCKED").first
  return nil unless work_item
  
  work_item.update!(status: "in_progress", ...)
  Run.create!(agent: agent, work_item: work_item, ...)
  
  work_item
end
```

If any step fails, the entire transaction rolls back, ensuring consistency.

## Monitoring and Observability

### Key Metrics

Monitor these metrics to understand assignment health:

- **Queue depth**: Number of pending work items
- **Claim rate**: Work items claimed per second
- **Completion rate**: Work items completed per second
- **Failure rate**: Percentage of failed work items
- **Lock duration**: Average time items remain locked

### Queries

```ruby
# Queue depth by priority
WorkItem.pending.group(:priority).count

# Average time to claim
WorkItem.completed.average("locked_at - created_at")

# Failure rate
total = WorkItem.where.not(status: "pending").count
failed = WorkItem.failed.count
failure_rate = (failed.to_f / total * 100).round(2)

# Current locks
WorkItem.in_progress.where.not(locked_at: nil).count
```

## Orchestration Agent

The orchestration agent monitors GitHub webhook events and creates work items based on repository activity:

### Monitored Events

- **Issues**: `opened`, `labeled`, `closed`
- **Pull Requests**: `opened`, `merged`, `closed`
- **Workflow Runs**: `completed`, `failed`

### Work Item Creation

When a relevant event occurs, the orchestration agent:

1. Evaluates the event against project policies
2. Creates a work item with appropriate priority
3. Sets the work type based on the event (e.g., `issue_triage`, `pr_review`, `build_failure`)
4. Populates the payload with event details

Example:

```ruby
# On issue labeled with "bug"
WorkItem.create!(
  project: project,
  work_type: "issue_triage",
  status: "pending",
  priority: 8,  # Bugs get higher priority
  payload: {
    event_type: "issues.labeled",
    issue_number: 42,
    label: "bug",
    title: "Application crashes on startup"
  }
)
```

### Run Synchronization

The orchestration agent also updates run records to stay in sync with GitHub:

- Links runs to pull requests when PRs are created
- Updates run outcomes based on CI/CD status
- Records logs and artifacts from GitHub Actions

## Best Practices

### 1. Set Appropriate Priorities

Use a consistent priority scheme across your work types:

```ruby
PRIORITIES = {
  critical_bug: 10,
  security_issue: 9,
  bug: 8,
  feature: 5,
  documentation: 3,
  refactoring: 1
}
```

### 2. Implement Timeouts

Work items should have reasonable timeouts to prevent agents from holding locks indefinitely:

```ruby
# In your worker
Timeout.timeout(work_item.timeout_seconds || 300) do
  perform_work(work_item)
end
rescue Timeout::Error
  AssignmentService.release_work_item(work_item)
  raise
end
```

### 3. Graceful Degradation

Handle cases where no work is available:

```ruby
loop do
  work_item = AssignmentService.lease_next_work_item(agent)
  
  if work_item
    process(work_item)
  else
    # Back off when queue is empty
    sleep(5)
  end
end
```

### 4. Monitor Agent Concurrency

Respect agent concurrency limits to avoid overwhelming agents:

```ruby
if agent.locked_work_items.count >= agent.max_concurrency
  # Agent is at capacity, skip
  return nil
end

AssignmentService.lease_next_work_item(agent)
```

## Related Documentation

- [Workspace Management](/docs/runtime/workspaces.md) - How agents execute work in isolated Git workspaces
- [Domain Model](/docs/domain/model.md) - Complete data model overview
- [GitHub Integration](/docs/integrations/github.md) - GitHub API and webhook handling
