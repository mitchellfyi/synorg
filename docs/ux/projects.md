# Project Lifecycle UI Documentation

## Overview

This document describes the user interface for managing projects and tracking their lifecycle through agent runs, work items, and events. The UI provides dashboards for viewing project status, creating new projects, and monitoring agent execution.

## Data Model

### Core Models

#### Project
- **Attributes:**
  - `id`: Primary key
  - `name`: Human-readable project name (optional)
  - `slug`: Unique identifier (required)
  - `state`: Current project state (draft, scoped, repo_bootstrapped, in_build, live)
  - `brief`: Project description and goals
  - `repo_full_name`: Associated GitHub repository (e.g., "owner/repo")
  - `repo_default_branch`: Default branch for the repository
  - `github_pat_secret_name`: Reference to GitHub PAT secret
  - `webhook_secret_name`: Reference to webhook secret
  - `gates_config`: JSON configuration for deployment gates
  - `e2e_required`: Boolean flag for E2E testing requirement
  - `created_at`, `updated_at`: Timestamps

- **Associations:**
  - `has_many :work_items`
  - `has_many :integrations`
  - `has_many :policies`
  - `has_many :webhook_events`

- **State Machine:**
  The project follows these state transitions:
  1. `draft` → `scoped` (via `scope!`)
  2. `scoped` → `repo_bootstrapped` (via `bootstrap_repo!`)
  3. `repo_bootstrapped` → `in_build` (via `start_build!`)
  4. `in_build` → `live` (via `go_live!`)
  5. `live` → `in_build` (via `revert_to_build!`)

#### WorkItem
- **Attributes:**
  - `id`: Primary key
  - `project_id`: Foreign key to Project
  - `work_type`: Type of work (e.g., "task", "bug", "feature")
  - `payload`: JSON containing work details (title, description, etc.)
  - `status`: Current status (pending, in_progress, completed, failed)
  - `priority`: Integer priority (higher = more urgent)
  - `assigned_agent_id`: Agent assigned to this work item
  - `locked_by_agent_id`: Agent currently working on this item
  - `locked_at`: Timestamp when locked
  - `created_at`, `updated_at`: Timestamps

- **Associations:**
  - `belongs_to :project`
  - `belongs_to :assigned_agent` (optional)
  - `belongs_to :locked_by_agent` (optional)
  - `has_many :runs`

#### Run
- **Attributes:**
  - `id`: Primary key
  - `agent_id`: Foreign key to Agent
  - `work_item_id`: Foreign key to WorkItem
  - `started_at`: When the run started
  - `finished_at`: When the run completed
  - `outcome`: Result of the run (success, failure, or nil for in-progress)
  - `logs_url`: External URL for logs
  - `logs`: Text logs stored in database
  - `artifacts_url`: External URL for artifacts
  - `costs`: JSON containing cost metrics
  - `idempotency_key`: Unique key for idempotent runs
  - `created_at`, `updated_at`: Timestamps

- **Associations:**
  - `belongs_to :agent`
  - `belongs_to :work_item`

#### Agent
- **Attributes:**
  - `id`: Primary key
  - `name`: Agent name
  - `agent_type`: Type of agent
  - `capabilities`: JSON array of capabilities
  - `config`: JSON configuration
  - `created_at`, `updated_at`: Timestamps

## API Endpoints

### Projects

#### `GET /projects` (projects#index)
Lists all projects with summary information.

**Response includes:**
- Project name/slug
- Current state with badge styling
- Associated repository
- Count of open work items (pending + in_progress)
- Count of completed work items

**Query Parameters:** None

#### `GET /projects/:id` (projects#show)
Shows detailed view of a single project.

**Response includes:**
- Project brief and current state
- Timeline of recent runs (last 10)
- List of open work items (pending + in_progress)
- Quick statistics (open items count, total runs)
- Next steps based on pending work items

**Query Parameters:** None

#### `GET /projects/new` (projects#new)
Displays form for creating a new project.

**Form Fields:**
- `name`: Project name (optional)
- `slug`: Unique identifier (required)
- `brief`: Project description (optional)
- `repo_full_name`: GitHub repository (optional)
- `github_pat_secret_name`: PAT secret reference (optional)

#### `POST /projects` (projects#create)
Creates a new project.

**Request Body:**
```json
{
  "project": {
    "name": "My Project",
    "slug": "my-project",
    "brief": "Project description",
    "repo_full_name": "owner/repo",
    "github_pat_secret_name": "GITHUB_PAT"
  }
}
```

**Validations:**
- `slug` must be present and unique
- `state` defaults to "draft"

**Success Response:**
- Redirects to project show page
- Flash notice: "Project was successfully created."

**Error Response:**
- Re-renders new form with validation errors
- HTTP 422 Unprocessable Entity

### Runs

#### `GET /projects/:project_id/runs` (runs#index)
Lists all runs for a specific project.

**Response includes:**
- Agent name and type
- Work item title/description
- Run status (pending, in-progress, success, failure)
- Start time (relative: "2 hours ago")
- Duration calculation
- Links to logs and artifacts (if available)

**Query Parameters:** None (limited to 100 most recent runs)

## UI Pages

### Projects Index (`/projects`)

**Purpose:** Dashboard view of all projects

**Layout:**
- Header with "New Project" button
- List of projects as cards/rows showing:
  - Project name/slug
  - State badge (color-coded)
  - Repository name (if set)
  - Open tasks count
  - Completed tasks count
  - Arrow icon for navigation
- Empty state with call-to-action when no projects exist

**Interactions:**
- Click project card to navigate to detail page
- Click "New Project" to create a new project

### Project Detail (`/projects/:id`)

**Purpose:** Comprehensive view of a single project

**Layout:**
- **Header:**
  - Back link to projects index
  - Project name and state badge
  - Slug and repository info
  - "View Runs" button

- **Main Content (2/3 width):**
  - **Project Brief card:** Displays formatted brief text
  - **Recent Activity timeline:** Shows last 10 runs with:
    - Status icon (checkmark for success, X for failure, clock for in-progress)
    - Agent name and work item description
    - Status, duration, and relative timestamp
    - Connecting lines between events

- **Sidebar (1/3 width):**
  - **Quick Stats:** Open work items count, total runs count
  - **Next Steps:** Top 5 pending/in-progress work items with:
    - Status badge
    - Work item title
    - Priority indicator

**Interactions:**
- Click "View Runs" to see all runs
- Timeline events are read-only
- Back link returns to projects index

### New Project Form (`/projects/new`)

**Purpose:** Create a new project

**Layout:**
- Header with back link
- Form with fields:
  - Name (text input, optional)
  - Slug (text input, required, with validation)
  - Brief (textarea)
  - Repository name (text input, placeholder: "owner/repository")
  - GitHub PAT secret name (text input)
- Submit and Cancel buttons
- Inline validation error messages

**Validations:**
- Slug must be present and unique
- Client-side placeholder text guides format
- Server-side validation with error display

**Interactions:**
- Cancel returns to projects index
- Submit creates project and redirects to detail page
- Validation errors display inline with red styling

### Runs Index (`/projects/:project_id/runs`)

**Purpose:** Detailed list of all agent runs for a project

**Layout:**
- Header with back link to project
- Table with columns:
  - Agent (name and type)
  - Work Item (title and type)
  - Status (badge)
  - Started (relative time with tooltip)
  - Duration (formatted: "5m 23s", "2h 15m")
  - Links (logs and/or artifacts)
- Empty state when no runs exist

**Interactions:**
- Click log/artifact links (open in new tab)
- Back link returns to project detail
- Table rows have hover state

## Event Timeline Component

### Purpose
Aggregates important project events in chronological order for easy tracking of project progress.

### Data Sources
Currently displays:
- **Agent Runs:** Most prominent events showing agent execution
  - Success/failure/in-progress status
  - Agent and work item details
  - Duration and timing

### Future Extensions
The timeline component can be extended to include:
- **Brief Created:** Project initialization event
- **Issues Opened/Closed:** From webhook events
- **PRs Opened/Merged:** From webhook events
- **Deployments:** When deployment tracking is added

### Visual Design
- Vertical timeline with connecting lines
- Color-coded status indicators:
  - Green circle with checkmark for success
  - Red circle with X for failure  
  - Blue circle with clock for in-progress
- Each event shows:
  - Icon/status indicator
  - Event description
  - Relative timestamp
  - Duration (when applicable)

### Implementation
Located in `app/views/projects/show.html.erb`, the timeline is rendered as a list of recent runs. To extend:

1. Query additional event sources (webhook_events, etc.)
2. Combine and sort events by timestamp
3. Add conditional rendering for different event types
4. Update icon/styling based on event type

## Styling & Design System

### Color Scheme (Tailwind CSS)

**State Badges:**
- Draft: `bg-gray-100 text-gray-800`
- Scoped: `bg-blue-100 text-blue-800`
- Repo Bootstrapped: `bg-purple-100 text-purple-800`
- In Build: `bg-yellow-100 text-yellow-800`
- Live: `bg-green-100 text-green-800`

**Run Status Badges:**
- Success: `bg-green-100 text-green-800`
- Failure: `bg-red-100 text-red-800`
- In Progress: `bg-blue-100 text-blue-800`
- Pending: `bg-gray-100 text-gray-800`

**Primary Actions:**
- Buttons: `bg-indigo-600 hover:bg-indigo-700`
- Links: `text-indigo-600 hover:text-indigo-900`

### Responsive Design
- Mobile-first approach using Tailwind's responsive prefixes
- Grid layouts: Single column on mobile, multi-column on desktop
- Tables: Horizontal scroll on mobile
- Cards: Stack vertically on mobile, horizontal on desktop

### Accessibility
- Semantic HTML elements (nav, main, article, etc.)
- ARIA labels where needed
- Color is not the only indicator (badges include text)
- Focus states on interactive elements
- Keyboard navigation support

## Helper Methods

### `ProjectsHelper`

#### `state_badge_class(state)`
Returns Tailwind CSS classes for project state badges.

**Parameters:**
- `state` (String): Project state

**Returns:** String of CSS classes

**Example:**
```erb
<span class="<%= state_badge_class('live') %>">Live</span>
```

#### `run_status_badge_class(outcome)`
Returns Tailwind CSS classes for run status badges.

**Parameters:**
- `outcome` (String|nil): Run outcome ("success", "failure", or nil)

**Returns:** String of CSS classes

#### `run_status_text(outcome, started_at, finished_at)`
Returns human-readable status text for a run.

**Parameters:**
- `outcome` (String|nil): Run outcome
- `started_at` (DateTime|nil): Start timestamp
- `finished_at` (DateTime|nil): End timestamp

**Returns:** String ("In Progress", "Pending", "Success", "Failure")

#### `run_duration(started_at, finished_at)`
Calculates and formats run duration.

**Parameters:**
- `started_at` (DateTime|nil): Start timestamp
- `finished_at` (DateTime|nil): End timestamp (uses current time if nil and started_at is present)

**Returns:** Formatted string ("30s", "5m 23s", "2h 15m", "N/A")

**Algorithm:**
- < 60 seconds: "Xs"
- < 60 minutes: "Xm Ys"
- >= 60 minutes: "Xh Ym"

## Extending the UI

### Adding New Fields to Projects
1. Add migration to add database column
2. Update `project_params` in `ProjectsController`
3. Add form field in `new.html.erb`
4. Display field in `show.html.erb` or `index.html.erb`
5. Update validation in `Project` model if needed

### Adding New Event Types to Timeline
1. Query the event data in `ProjectsController#show`
2. Combine with existing `@recent_runs` array
3. Sort by timestamp
4. Add conditional rendering in timeline partial
5. Add new icon/styling for event type
6. Update helper methods if needed for new event types

### Customizing the Dashboard
The projects index can be customized by:
- Modifying the query in `ProjectsController#index` (filters, sorting)
- Adjusting the card layout in `index.html.erb`
- Adding search/filter UI components
- Implementing pagination for large project lists

### Adding Pagination to Runs
To add pagination:
1. Add `gem 'kaminari'` to Gemfile
2. Run `bundle install`
3. Update `RunsController#index`:
   ```ruby
   @runs = Run.joins(:work_item)
              .where(work_items: { project_id: @project.id })
              .includes(:agent, :work_item)
              .order(started_at: :desc)
              .page(params[:page])
              .per(25)
   ```
4. Uncomment pagination section in `runs/index.html.erb`

### Implementing Real-time Updates
For live updates of run status:
1. Use Hotwire Turbo Streams
2. Broadcast updates when run status changes
3. Subscribe to stream in view:
   ```erb
   <%= turbo_stream_from "project_#{@project.id}_runs" %>
   ```
4. Update `Run` model to broadcast changes:
   ```ruby
   after_update_commit -> { 
     broadcast_replace_to "project_#{work_item.project_id}_runs"
   }
   ```

## Testing

### Controller Specs
Located in `spec/controllers/`:
- `projects_controller_spec.rb`: Tests for CRUD operations
- `runs_controller_spec.rb`: Tests for run listing

### Request Specs (Optional)
Can be added in `spec/requests/` for integration testing of full request/response cycle.

### View Specs (Optional)
Can be added in `spec/views/` for testing view rendering logic.

### Example Test Coverage
- Projects index renders list of projects
- Project show page displays project details
- New project form validates required fields
- Project creation redirects to show page
- Runs index displays runs for specific project
- Empty states render correctly
- Helper methods format data correctly

## Future Enhancements

### Potential Features
1. **Search and Filtering:** Add search bar to filter projects by name, state, or repository
2. **Sorting Options:** Allow sorting by different columns (name, state, date created)
3. **Bulk Actions:** Select multiple projects for batch operations
4. **Project Settings Page:** Edit project configuration after creation
5. **Work Item Detail View:** Dedicated page for viewing work item details
6. **Run Detail View:** Detailed view of individual run with full logs
7. **Real-time Status Updates:** Live updates using WebSockets/Turbo Streams
8. **Export Functionality:** Export project data to CSV or JSON
9. **Charts and Analytics:** Visualize run success rates, duration trends
10. **Webhook Event Timeline:** Integrate GitHub webhook events into timeline

### Performance Optimization
- Implement pagination for projects list
- Add database indexes for common queries
- Cache rendered timeline events
- Use partial rendering for large lists
- Implement lazy loading for old runs

### Accessibility Improvements
- Add ARIA live regions for dynamic updates
- Improve keyboard navigation
- Add screen reader announcements
- Ensure color contrast meets WCAG AA standards
- Add skip navigation links

## Troubleshooting

### Common Issues

**Issue: Projects not displaying**
- Check that database migrations have run
- Verify projects exist in database: `Project.count`
- Check Rails logs for errors

**Issue: Runs page empty despite having runs**
- Verify runs are associated with work items that belong to the project
- Check the join query in `RunsController#index`

**Issue: State badges not showing colors**
- Ensure Tailwind CSS is properly compiled
- Check that `state_badge_class` helper is returning correct classes
- Verify Tailwind config includes necessary color variants

**Issue: Timeline not showing**
- Check that `@recent_runs` is being populated in controller
- Verify run records have `started_at` timestamps
- Ensure work items are properly associated

## Related Documentation

- [Setup Guide](/docs/setup-guide.md)
- [Domain Documentation](/docs/domain/)
- [GitHub Integration](/docs/integrations/)
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Hotwire Turbo](https://turbo.hotwired.dev/)
