Short version: synorg is the “brains” that tells your AI dev team what to do, when to do it, and how to stay sane – with GitHub as the factory floor.

synorg is a Rails control plane for AI development agents.

It:

Takes a project brief.

Designs and drives a development plan via GitHub issues / PRs.

Uses GitHub Copilot (and friends) as the execution layer.

Tracks work items, runs, and status across agents and repos.


It does orchestration, not raw code execution:

Think: “project lead + traffic controller” for AI agents working in GitHub.




---

2. Core concepts

Projects

A Project is the top-level thing you’re building.

Stored in synorg with:

Brief (problem, audience, constraints).

Linked GitHub repo (source of truth for code).

State: draft → scoped → repo_bootstrapped → in_build → live.



Agents

synorg knows about a team of agents and their roles, with prompts documented in AGENTS.md and per-agent instruction files.

Current roles roughly:

Go-to-market (GTM) – naming, positioning, value prop, messaging.

Product Manager – project definition, scope, epics, issues.

Issue / GitHub agent – opens / syncs GitHub issues and labels.

Docs agent – README, docs, prompts, architecture write-ups.

DevTooling agent – CI, linting, tests, security scanners, dev UX.

Orchestration agent – decides what should happen next, based on webhooks, state, and human inputs.



Work items & runs

Work items: atomic tasks (often mapped to issues) with:

Type, priority, owning agent role, and GitHub linkage.


Runs: execution attempts of a work item by an agent:

Captures logs, status, duration, errors, metrics.




---

3. How synorg uses GitHub

Source of truth

Code, PRs, checks, workflows live in GitHub.

synorg:

Receives webhooks (issues, pull_request, push, workflow_run, etc.).

Keeps its own DB in sync with:

Issue states (open/closed/labels).

PR lifecycle (open/merge/CI status).

Workflow success/failure.




Agent runtime via issues + Copilot

Runtime is GitHub-native:

Agents run as Copilot coding agents (and other tools) working on:

Issues assigned to them.

PRs they open or update.


synorg’s job:

Create/curate issues.

Label and assign them to the right agent.

React to changes (e.g. CI failed, review requested, merge happened).





---

4. Orchestration agent (the “app brain”)

What this “app orchestration agent” does:

Watches events:

New project created.

New issue or PR opened.

Webhook from CI (success/failure).

Human completes a blocking task (e.g. DNS, Stripe keys).


Evaluates what should happen next:

Need more definition? → ask PM agent to create issues.

Repo tooling missing? → ask DevTooling agent to add workflows.

Docs out of date? → ask Docs agent to update README/docs.

CI failing on a PR? → create/label a “fix build” task and assign it.


Records runs and status in synorg:

Work item → planned.

Run → scheduled → in progress → succeeded/failed.


Uses GitHub as shared reality:

If GitHub says “PR #42 merged and CI green”, synorg updates its internal state.

If they’re out of sync, GitHub wins and synorg reconciles.



No extra runtime containers needed for the orchestrator itself - it runs inside the Rails app as jobs/workers, and it points GitHub-side agents at the right tasks.


---

5. End-to-end flow for a new project

For a typical project:

1. Project creation

User creates a project in synorg with:

Brief (problem, audience, constraints).

Target GitHub repo (existing or to be created manually at first).


Project starts in draft then moves to scoped.



2. GTM & Product definition

GTM agent:

Suggests project name, core positioning, and messaging.


Product Manager agent:

Turns brief + GTM direction into:

Epics / themes.

Initial backlog of issues / work items.


Marks which tasks are blocking human tasks (e.g. “set up Stripe”).




3. Repo setup & dev tooling

DevTooling agent:

Ensures the repo has:

CI workflows (lint, tests, security, Playwright smoke).

Dev tooling (linting, formatting, pre-commit hooks, etc).

Kamal deploy workflow scaffold.


Opens PRs to add or fix this tooling.


Docs agent:

Creates or improves README and /docs based on the brief and chosen stack.




4. Ongoing development loop

Orchestration agent:

Watches webhooks to detect:

New TODOs (“CI broke”, “tests are flaky”, “docs stale”).

Completed work (“feature merged”, “tooling updated”).


Enqueues work items for the right agent roles.


Assignment logic:

Maps work items → GitHub issues.

Assigns issues to Copilot (or other agents) with the correct instructions.


Agents (in GitHub):

Pick up issues, produce code changes, open/iterate on PRs.


synorg:

Tracks runs, status, and metrics.

Surfaces what’s blocked vs progressing.




5. Human-in-the-loop

Some tasks are human-only (DNS, production keys, Stripe setup, etc.).

synorg:

Creates “human tasks” and marks downstream work as “blocked”.

Once humans confirm completion, orchestration unblocks dependent work.




6. Visibility & observability

synorg offers:

Project dashboard – state, key metrics, open runs, PRs, and issues.

Run history – what agents did, when, and what happened.


It can log and export:

Error tracking.

Throughput + success/failure rates per agent.

Time-to-merge, time-to-fix, etc.






---

6. How you’ll actually use it (from your POV)

As a user, synorg is there so you can:

Describe a project once and get:

A properly tooled repo.

A structured backlog.

Agents that actually push code via GitHub PRs.


See:

What’s happening right now (which PRs, which checks, which tasks).

What’s blocked on you vs blocked on an agent.


Nudge:

Add ideas or constraints via issues / notes.

Re-prioritise work items.

Approve or reject agent work through normal GitHub flows.
