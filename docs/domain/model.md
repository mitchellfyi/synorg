# Domain Model

This document describes the database schema and relationships for synorg's control plane.

## Entity Relationship Diagram

```
┌──────────────┐
│   Projects   │
└──────┬───────┘
       │
       │ 1:N
       ├──────────────────┐
       │                  │
       ▼                  ▼
┌──────────────┐   ┌─────────────┐
│  Work Items  │   │Integrations │
└──────┬───────┘   └─────────────┘
       │
       │ 1:N         ┌─────────────┐
       ▼             │   Policies  │
┌──────────────┐    └─────────────┘
│     Runs     │           ▲
└──────┬───────┘           │
       │                   │ 1:N
       │                   │
       │            ┌──────┴──────┐
       │            │   Projects  │
       │            └─────────────┘
       │
       ▼
┌──────────────┐
│    Agents    │
└──────────────┘
```

## Tables

### Projects

The `projects` table stores information about software projects managed by synorg.

| Column                   | Type      | Nullable | Default | Description                                    |
|--------------------------|-----------|----------|---------|------------------------------------------------|
| id                       | bigint    | NO       |         | Primary key                                    |
| name                     | string    | YES      | NULL    | Human-readable project name                    |
| slug                     | string    | NO       |         | Unique URL-safe identifier                     |
| state                    | string    | NO       | 'draft' | Current state in the project lifecycle         |
| brief                    | text      | YES      | NULL    | Project description or summary                 |
| repo_full_name           | string    | YES      | NULL    | GitHub repository (e.g., 'owner/repo')         |
| repo_default_branch      | string    | YES      | NULL    | Default branch name (e.g., 'main')             |
| github_pat               | text      | YES      | NULL    | GitHub Personal Access Token (encrypted)       |
| github_pat_secret_name   | string    | YES      | NULL    | Name of secret storing GitHub PAT              |
| webhook_secret           | text      | YES      | NULL    | Webhook secret for signature verification      |
| gates_config             | json      | NO       | {}      | Configuration for quality gates                |
| e2e_required             | boolean   | NO       | true    | Whether E2E tests are required                 |
| created_at               | datetime  | NO       |         | Record creation timestamp                      |
| updated_at               | datetime  | NO       |         | Record last update timestamp                   |

**Indexes:**
- `index_projects_on_slug` (unique)
- `index_projects_on_state`
- `index_projects_on_webhook_secret` (partial, where webhook_secret IS NOT NULL)
- `index_projects_on_created_at`

**Relationships:**
- Has many `work_items`
- Has many `integrations`
- Has many `policies`
- Has many `webhook_events`

---

### Agents

The `agents` table stores information about autonomous agents that process work items.

| Column          | Type      | Nullable | Default | Description                                    |
|-----------------|-----------|----------|---------|------------------------------------------------|
| id              | bigint    | NO       |         | Primary key                                    |
| key             | string    | NO       |         | Unique agent identifier                        |
| name            | string    | NO       |         | Human-readable agent name                      |
| description     | text      | YES      | NULL    | Agent description                              |
| prompt          | text      | YES      | NULL    | LLM prompt for agent execution                 |
| capabilities    | json      | NO       | {}      | Agent capabilities and configuration           |
| max_concurrency | integer   | NO       | 1       | Maximum concurrent work items                  |
| enabled         | boolean   | NO       | true    | Whether the agent is active                    |
| created_at      | datetime  | NO       |         | Record creation timestamp                      |
| updated_at      | datetime  | NO       |         | Record last update timestamp                   |

**Indexes:**
- `index_agents_on_key` (unique)
- `index_agents_on_enabled`

**Relationships:**
- Has many `runs`
- Has many `assigned_work_items` (as `assigned_agent`)
- Has many `locked_work_items` (as `locked_by_agent`)

---

### Work Items

The `work_items` table stores tasks to be processed by agents.

| Column              | Type      | Nullable | Default    | Description                                    |
|---------------------|-----------|----------|------------|------------------------------------------------|
| id                  | bigint    | NO       |            | Primary key                                    |
| project_id          | bigint    | NO       |            | Foreign key to projects                        |
| work_type           | string    | NO       |            | Type of work (e.g., 'code_review', 'deploy')   |
| payload             | json      | NO       | {}         | Work item data and parameters                  |
| status              | string    | NO       | 'pending'  | Current status                                 |
| priority            | integer   | NO       | 0          | Priority (higher = more urgent)                |
| assigned_agent_id   | bigint    | YES      | NULL       | Foreign key to agents (assigned)               |
| locked_at           | datetime  | YES      | NULL       | When the work item was locked                  |
| locked_by_agent_id  | bigint    | YES      | NULL       | Foreign key to agents (locked by)              |
| created_at          | datetime  | NO       |            | Record creation timestamp                      |
| updated_at          | datetime  | NO       |            | Record last update timestamp                   |

**Indexes:**
- `index_work_items_on_project_id`
- `index_work_items_on_status`
- `index_work_items_on_priority`
- `index_work_items_on_status_and_priority_and_locked_at` (composite)
- `index_work_items_on_assigned_agent_id`
- `index_work_items_on_locked_by_agent_id`
- `index_work_items_on_work_type`
- `index_work_items_on_project_id_and_work_type` (composite)
- `index_work_items_on_work_type_and_status` (composite)
- `index_work_items_on_created_at`

**Relationships:**
- Belongs to `project`
- Belongs to `assigned_agent` (optional)
- Belongs to `locked_by_agent` (optional)
- Has many `runs`

**Status Values:**
- `pending` - Waiting to be processed
- `in_progress` - Currently being processed
- `completed` - Successfully completed
- `failed` - Processing failed

---

### Runs

The `runs` table tracks execution history of work items by agents.

| Column         | Type      | Nullable | Default | Description                                    |
|----------------|-----------|----------|---------|------------------------------------------------|
| id             | bigint    | NO       |         | Primary key                                    |
| agent_id       | bigint    | NO       |         | Foreign key to agents                          |
| work_item_id   | bigint    | NO       |         | Foreign key to work_items                      |
| started_at     | datetime  | YES      | NULL    | When the run started                           |
| finished_at    | datetime  | YES      | NULL    | When the run finished                          |
| outcome        | string    | YES      | NULL    | Result ('success', 'failure', or NULL)         |
| logs_url       | string    | YES      | NULL    | URL to execution logs                          |
| artifacts_url  | string    | YES      | NULL    | URL to build artifacts                         |
| costs          | json      | NO       | {}      | Cost tracking data                             |
| created_at     | datetime  | NO       |         | Record creation timestamp                      |
| updated_at     | datetime  | NO       |         | Record last update timestamp                   |

**Indexes:**
- `index_runs_on_agent_id`
- `index_runs_on_work_item_id`
- `index_runs_on_outcome`
- `index_runs_on_agent_id_and_started_at` (composite)
- `index_runs_on_work_item_id_and_started_at` (composite)
- `index_runs_on_work_item_id_and_outcome` (composite)
- `index_runs_on_created_at`
- `index_runs_on_idempotency_key` (unique, partial)

**Relationships:**
- Belongs to `agent`
- Belongs to `work_item`

**Outcome Values:**
- `success` - Run completed successfully
- `failure` - Run failed
- `NULL` - Run is in progress

---

### Integrations

The `integrations` table stores external service integrations for projects.

| Column      | Type      | Nullable | Default   | Description                                    |
|-------------|-----------|----------|-----------|------------------------------------------------|
| id          | bigint    | NO       |           | Primary key                                    |
| project_id  | bigint    | NO       |           | Foreign key to projects                        |
| kind        | string    | NO       |           | Integration type (e.g., 'slack', 'github')     |
| name        | string    | NO       |           | Integration name                               |
| value       | text      | YES      | NULL      | Integration configuration or credentials       |
| status      | string    | NO       | 'active'  | Current status                                 |
| created_at  | datetime  | NO       |           | Record creation timestamp                      |
| updated_at  | datetime  | NO       |           | Record last update timestamp                   |

**Indexes:**
- `index_integrations_on_project_id`
- `index_integrations_on_project_id_and_kind` (composite)
- `index_integrations_on_status`

**Relationships:**
- Belongs to `project`

**Status Values:**
- `active` - Integration is enabled
- `inactive` - Integration is disabled

---

### Policies

The `policies` table stores project-level configuration policies.

| Column      | Type      | Nullable | Default | Description                                    |
|-------------|-----------|----------|---------|------------------------------------------------|
| id          | bigint    | NO       |         | Primary key                                    |
| project_id  | bigint    | NO       |         | Foreign key to projects                        |
| key         | string    | NO       |         | Policy key (unique per project)                |
| value       | json      | NO       | {}      | Policy configuration                           |
| created_at  | datetime  | NO       |         | Record creation timestamp                      |
| updated_at  | datetime  | NO       |         | Record last update timestamp                   |

**Indexes:**
- `index_policies_on_project_id`
- `index_policies_on_project_id_and_key` (unique composite)

**Relationships:**
- Belongs to `project`

**Common Policy Keys:**
- `require_approval` - Approval requirements
- `ci_timeout` - CI/CD timeout configuration
- `merge_strategy` - Git merge strategy

---

### Webhook Events

The `webhook_events` table stores incoming GitHub webhook events for processing and debugging.

| Column      | Type      | Nullable | Default | Description                                    |
|-------------|-----------|----------|---------|------------------------------------------------|
| id          | bigint    | NO       |         | Primary key                                    |
| project_id  | bigint    | NO       |         | Foreign key to projects                        |
| event_type  | string    | NO       |         | GitHub event type (e.g., 'issues', 'pull_request') |
| delivery_id | string    | NO       |         | Unique GitHub delivery ID                      |
| payload     | json      | NO       | {}      | Full webhook payload                           |
| created_at  | datetime  | NO       |         | Record creation timestamp                      |
| updated_at  | datetime  | NO       |         | Record last update timestamp                   |

**Indexes:**
- `index_webhook_events_on_project_id`
- `index_webhook_events_on_project_id_and_event_type` (composite)
- `index_webhook_events_on_project_id_and_created_at` (composite)
- `index_webhook_events_on_delivery_id` (unique)
- `index_webhook_events_on_event_type`

**Relationships:**
- Belongs to `project`

**Event Types:**
- `issues` - Issue events (opened, closed, labeled)
- `pull_request` - Pull request events (opened, closed, merged)
- `push` - Push events
- `workflow_run` - GitHub Actions workflow run events
- `check_suite` - Check suite completion events

## Foreign Key Relationships

```ruby
work_items.project_id → projects.id
work_items.assigned_agent_id → agents.id
work_items.locked_by_agent_id → agents.id
runs.agent_id → agents.id
runs.work_item_id → work_items.id
integrations.project_id → projects.id
policies.project_id → projects.id
webhook_events.project_id → projects.id
```

## Design Notes

### Work Item Locking

Work items use a pessimistic locking strategy with `SELECT FOR UPDATE SKIP LOCKED` to ensure:
- No two agents can process the same work item simultaneously
- Failed locks don't block other agents
- Efficient queue processing at scale

### JSON Columns

Several tables use JSON columns for flexible, schema-less data:
- `projects.gates_config` - Quality gate rules
- `agents.capabilities` - Agent feature flags
- `agents.prompt` - LLM prompt text (stored as text, not JSON)
- `work_items.payload` - Work-specific parameters
- `runs.costs` - Cost tracking metrics
- `policies.value` - Policy configuration
- `webhook_events.payload` - Webhook event data

This allows for extensibility without schema migrations.

### Indexes

Indexes are optimized for common query patterns:
- Work item assignment queries (status + priority + locked_at)
- Work item filtering by work_type and status
- Agent lookup by key and enabled state (with caching)
- Project lookup by slug
- Run history queries (agent_id + started_at, work_item_id + started_at)
- Webhook event queries (project_id + created_at)

## References

- [Rails Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- [PostgreSQL JSON Types](https://www.postgresql.org/docs/current/datatype-json.html)
- [SELECT FOR UPDATE SKIP LOCKED](https://www.postgresql.org/docs/current/sql-select.html#SQL-FOR-UPDATE-SHARE)
