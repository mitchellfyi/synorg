# Project Lifecycle UI - Visual Guide

## Overview

This document provides a visual description of the project lifecycle UI pages. Since the application requires a PostgreSQL database to run, this guide describes what each page looks like and how it functions.

## Projects Index (`/` or `/projects`)

### Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Projects                                    [+ New Project] │
│ Manage your development projects and track their progress   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ ┌───────────────────────────────────────────────────────┐  │
│ │ My Awesome Project                    [Draft]         │  │
│ │ Slug: my-awesome-project • Repo: owner/repo          │  │
│ │                                                        │  │
│ │     5          10                                  →  │  │
│ │ Open Tasks   Completed                                │  │
│ └───────────────────────────────────────────────────────┘  │
│                                                               │
│ ┌───────────────────────────────────────────────────────┐  │
│ │ Another Project                        [Live]         │  │
│ │ Slug: another-project                                 │  │
│ │                                                        │  │
│ │     2          25                                  →  │  │
│ │ Open Tasks   Completed                                │  │
│ └───────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Features
- **Header:** Title and "New Project" button (indigo)
- **Project Cards:** Each shows:
  - Project name and state badge (color-coded)
  - Slug and repository (if set)
  - Open tasks count (pending + in_progress)
  - Completed tasks count
  - Hover effect and clickable to detail page
- **Empty State:** When no projects, shows icon and "New Project" CTA
- **Responsive:** Stacks on mobile, grid on desktop

### State Badge Colors
- Draft: Gray
- Scoped: Blue
- Repo Bootstrapped: Purple
- In Build: Yellow
- Live: Green

## Project Detail (`/projects/:id`)

### Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ ← Back to Projects                                                  │
│                                                                      │
│ My Awesome Project [Draft]                    [View Runs]          │
│ my-awesome-project • owner/repo                                     │
├─────────────────────────────────────┬───────────────────────────────┤
│                                     │                               │
│ ┌─────────────────────────────┐    │ ┌─────────────────────────┐  │
│ │ Project Brief               │    │ │ Quick Stats             │  │
│ ├─────────────────────────────┤    │ ├─────────────────────────┤  │
│ │ This project aims to...     │    │ │ Open Work Items         │  │
│ │ [brief text continues]      │    │ │        5                │  │
│ │                              │    │ │                          │  │
│ └─────────────────────────────┘    │ │ Total Runs              │  │
│                                     │ │       12                │  │
│ ┌─────────────────────────────┐    │ └─────────────────────────┘  │
│ │ Recent Activity             │    │                               │
│ ├─────────────────────────────┤    │ ┌─────────────────────────┐  │
│ │ ● Agent CodeBot ran for     │    │ │ Next Steps              │  │
│ │   Fix login bug             │    │ ├─────────────────────────┤  │
│ │   Success • 5m 23s          │    │ │ [In Progress]           │  │
│ │   2 hours ago               │    │ │ Fix login bug           │  │
│ │                              │    │ │ Priority: 10            │  │
│ │ ● Agent CodeBot ran for     │    │ │                          │  │
│ │   Add user profile          │    │ │ [Pending]               │  │
│ │   In Progress • 2m 15s      │    │ │ Add user profile        │  │
│ │   1 hour ago                │    │ │ Priority: 5             │  │
│ │                              │    │ │                          │  │
│ └─────────────────────────────┘    │ └─────────────────────────┘  │
│                                     │                               │
└─────────────────────────────────────┴───────────────────────────────┘
```

### Features

**Main Content (left, 2/3 width):**
- **Project Brief Card:** Shows formatted brief text
- **Recent Activity Timeline:** Last 10 runs with:
  - Status icon (✓ green for success, ✗ red for failure, ⏱ blue for in-progress)
  - Agent name and work item title
  - Status, duration, and relative timestamp
  - Connecting vertical line between events

**Sidebar (right, 1/3 width):**
- **Quick Stats:** Open work items count, total runs count
- **Next Steps:** Top 5 pending/in-progress work items with:
  - Status badge
  - Work item title
  - Priority indicator

**Header:**
- Back link to projects index
- Project name and state badge
- Slug and repository info
- "View Runs" button

## New Project Form (`/projects/new`)

### Layout

```
┌─────────────────────────────────────────────────┐
│ ← Back to Projects                              │
│                                                  │
│ Create New Project                              │
│ Enter the details for your new project          │
├─────────────────────────────────────────────────┤
│                                                  │
│ Name (optional)                                 │
│ ┌─────────────────────────────────────────────┐│
│ │ My Awesome Project                          ││
│ └─────────────────────────────────────────────┘│
│ A human-readable name for your project          │
│                                                  │
│ Slug * (required)                               │
│ ┌─────────────────────────────────────────────┐│
│ │ my-awesome-project                          ││
│ └─────────────────────────────────────────────┘│
│ A unique identifier (lowercase, hyphens)        │
│                                                  │
│ Project Brief                                   │
│ ┌─────────────────────────────────────────────┐│
│ │                                             ││
│ │ Describe what this project is about...     ││
│ │                                             ││
│ └─────────────────────────────────────────────┘│
│ Describe the purpose and goals                  │
│                                                  │
│ Repository Name                                 │
│ ┌─────────────────────────────────────────────┐│
│ │ owner/repository                            ││
│ └─────────────────────────────────────────────┘│
│ The GitHub repository (e.g., "octocat/hello")   │
│                                                  │
│ GitHub PAT Secret Name                          │
│ ┌─────────────────────────────────────────────┐│
│ │ GITHUB_PAT                                  ││
│ └─────────────────────────────────────────────┘│
│ The name of the secret containing the PAT       │
│                                                  │
│                      Cancel  [Create Project]   │
└─────────────────────────────────────────────────┘
```

### Features
- **Form Fields:**
  - Name (optional text input)
  - Slug (required text input with validation)
  - Brief (textarea)
  - Repository name (text input, format: "owner/repo")
  - GitHub PAT secret name (text input)
- **Validation:**
  - Slug is required and must be unique
  - Inline error messages show below invalid fields
  - Error summary box at top if submission fails
- **Actions:**
  - Cancel returns to projects index
  - Submit creates project with state="draft" and redirects to detail page
- **Styling:**
  - Clean white card with shadow
  - Indigo submit button
  - Red error text and borders for invalid fields

## Runs Index (`/projects/:project_id/runs`)

### Layout

```
┌──────────────────────────────────────────────────────────────────────────┐
│ ← Back to My Awesome Project                                             │
│                                                                           │
│ Agent Runs                                                               │
│ View all agent runs for this project                                     │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│ ┌────────────────────────────────────────────────────────────────────┐  │
│ │ Agent    │ Work Item    │ Status    │ Started    │ Duration │ Links│  │
│ ├────────────────────────────────────────────────────────────────────┤  │
│ │ CodeBot  │ Fix login    │ [Success] │ 2h ago     │ 5m 23s   │ Logs │  │
│ │ github   │ bug          │           │            │          │      │  │
│ ├────────────────────────────────────────────────────────────────────┤  │
│ │ CodeBot  │ Add user     │ [In Prog] │ 1h ago     │ 2m 15s   │ Logs │  │
│ │ github   │ profile      │           │            │          │      │  │
│ ├────────────────────────────────────────────────────────────────────┤  │
│ │ TestBot  │ E2E tests    │ [Failure] │ 3h ago     │ 10m 5s   │ Logs │  │
│ │ testing  │ for signup   │           │            │          │ Art. │  │
│ └────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

### Features
- **Table View:**
  - Agent name and type
  - Work item title and type
  - Status badge (green=success, red=failure, blue=in-progress)
  - Started time (relative, with tooltip showing absolute time)
  - Duration (formatted: "5m 23s", "2h 15m")
  - Links to logs and artifacts (if available)
- **Hover Effect:** Row highlights on hover
- **Empty State:** When no runs, shows icon and message
- **Limit:** Shows 100 most recent runs
- **Responsive:** Horizontal scroll on mobile

## Color Scheme

### State Badges
- **Draft:** `bg-gray-100 text-gray-800`
- **Scoped:** `bg-blue-100 text-blue-800`
- **Repo Bootstrapped:** `bg-purple-100 text-purple-800`
- **In Build:** `bg-yellow-100 text-yellow-800`
- **Live:** `bg-green-100 text-green-800`

### Run Status Badges
- **Success:** `bg-green-100 text-green-800`
- **Failure:** `bg-red-100 text-red-800`
- **In Progress:** `bg-blue-100 text-blue-800`
- **Pending:** `bg-gray-100 text-gray-800`

### Primary Actions
- **Buttons:** `bg-indigo-600 hover:bg-indigo-700` (white text)
- **Links:** `text-indigo-600 hover:text-indigo-900`

## Accessibility Features

- Semantic HTML elements (header, main, nav, article)
- ARIA labels where appropriate
- Color is not the only indicator (badges include text)
- Keyboard navigation support
- Focus states on all interactive elements
- Relative timestamps with tooltips showing absolute time

## Mobile Responsiveness

- **Projects Index:** Cards stack vertically on mobile
- **Project Detail:** Sidebar moves below main content on mobile
- **New Project Form:** Full width on mobile
- **Runs Table:** Horizontal scroll on mobile
- All pages use mobile-first Tailwind breakpoints (sm:, md:, lg:)

## User Flow

1. **Landing:** User visits `/` and sees projects index
2. **Create:** User clicks "New Project" → fills form → submits → redirected to project detail
3. **View Project:** User clicks project card → sees project detail with timeline and stats
4. **View Runs:** User clicks "View Runs" → sees full table of agent runs with logs/artifacts
5. **Navigate Back:** User uses back links to return to previous pages

## Future Enhancements

See `/docs/ux/projects.md` for detailed future enhancement plans including:
- Search and filtering
- Real-time updates with Turbo Streams
- Work item detail pages
- Run detail pages with full logs
- Charts and analytics
- Webhook event integration
