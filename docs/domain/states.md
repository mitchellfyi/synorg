# Project State Machine

This document describes the state machine for the `Project` model, including states, transitions, and business rules.

## Overview

Projects in synorg follow a defined lifecycle from initial drafting through to being live in production. The state machine ensures projects progress through appropriate stages with proper validation at each step.

## State Diagram

```
┌───────┐
│ draft │
└───┬───┘
    │ scope
    ▼
┌────────┐
│ scoped │
└───┬────┘
    │ bootstrap_repo
    ▼
┌────────────────────┐
│ repo_bootstrapped │
└───┬────────────────┘
    │ start_build
    ▼
┌──────────┐
│ in_build │◄──────┐
└───┬──────┘       │
    │ go_live      │ revert_to_build
    ▼              │
┌──────┐           │
│ live │───────────┘
└──────┘
```

## States

### draft (initial state)

**Description:** The project has been created but not yet fully defined.

**Characteristics:**
- Project requirements are being gathered
- No repository association required
- Minimal validation
- Planning and scoping in progress

**Exit conditions:**
- All required fields are populated
- Project scope is defined
- Ready to transition to `scoped`

---

### scoped

**Description:** The project scope is defined and approved.

**Characteristics:**
- Project requirements are documented in the `brief` field
- Quality gates configured in `gates_config`
- Repository information may be provided
- Team members assigned

**Entry conditions:**
- Project has a clear scope and objectives
- Basic configuration completed

**Exit conditions:**
- Repository is ready to be bootstrapped
- All necessary secrets configured (PAT, webhook secret)

---

### repo_bootstrapped

**Description:** The Git repository has been set up with initial structure.

**Characteristics:**
- Repository exists and is accessible
- Initial project structure created
- CI/CD pipelines configured
- Branch protection rules applied

**Entry conditions:**
- `repo_full_name` is set
- GitHub PAT is configured
- Repository exists and is accessible

**Exit conditions:**
- Initial CI/CD build passes
- All quality gates are configured
- Ready for development work

---

### in_build

**Description:** Active development and iteration are ongoing.

**Characteristics:**
- Development work is in progress
- CI/CD pipelines are running
- Code reviews and testing happening
- Quality gates being enforced

**Entry conditions:**
- Repository is bootstrapped
- CI/CD is functional
- Development team is active

**Exit conditions (to `live`):**
- All acceptance criteria met
- All quality gates passing
- Stakeholder approval obtained

**Exit conditions (from `live`):**
- Reversion needed for fixes or updates
- New major features being added

---

### live

**Description:** The project is deployed and running in production.

**Characteristics:**
- Production deployment active
- Monitoring and alerting enabled
- Maintenance mode
- Limited development work

**Entry conditions:**
- All acceptance criteria satisfied
- Quality gates passing
- Production deployment successful
- Stakeholder sign-off

**Reversion:**
- Can transition back to `in_build` for updates or fixes
- Maintains production stability during updates

## Transitions (Events)

### scope

**From:** `draft`  
**To:** `scoped`  
**Trigger:** Project scope is defined and approved

**Validations:**
- Brief must be present (recommended)
- Gates configuration should be defined

**Example:**
```ruby
project = Project.create!(slug: "my-app", state: "draft")
project.scope!
project.state # => "scoped"
```

---

### bootstrap_repo

**From:** `scoped`  
**To:** `repo_bootstrapped`  
**Trigger:** Repository setup is complete

**Validations:**
- `repo_full_name` must be present
- `repo_default_branch` should be set
- GitHub PAT must be configured
- Repository must be accessible

**Example:**
```ruby
project.repo_full_name = "example/my-app"
project.repo_default_branch = "main"
project.github_pat_secret_name = "GITHUB_PAT"
project.bootstrap_repo!
project.state # => "repo_bootstrapped"
```

---

### start_build

**From:** `repo_bootstrapped`  
**To:** `in_build`  
**Trigger:** Development work begins

**Validations:**
- Repository is accessible
- CI/CD pipelines are configured

**Example:**
```ruby
project.start_build!
project.state # => "in_build"
```

---

### go_live

**From:** `in_build`  
**To:** `live`  
**Trigger:** Production deployment is ready

**Validations:**
- All quality gates passing
- Acceptance criteria met
- Stakeholder approval

**Example:**
```ruby
project.go_live!
project.state # => "live"
```

---

### revert_to_build

**From:** `live`  
**To:** `in_build`  
**Trigger:** Updates or fixes needed

**Validations:**
- None (always allowed for maintenance)

**Example:**
```ruby
project.revert_to_build!
project.state # => "in_build"
```

## Business Rules

### State Persistence

- State changes are persisted immediately
- State transitions are atomic
- Failed transitions raise exceptions

### Validation

States should validate:
1. **draft**: Minimal validation (slug required)
2. **scoped**: Brief and gates_config recommended
3. **repo_bootstrapped**: Repository information required
4. **in_build**: All repository fields required
5. **live**: All quality gates must pass

### Permissions

State transitions may require different permission levels:
- `draft` → `scoped`: Project manager
- `scoped` → `repo_bootstrapped`: DevOps engineer
- `repo_bootstrapped` → `in_build`: Development lead
- `in_build` → `live`: Release manager
- `live` → `in_build`: Release manager

*(Permission enforcement to be implemented in authorization layer)*

## Usage Examples

### Creating a New Project

```ruby
# Start in draft
project = Project.create!(
  slug: "my-new-app",
  name: "My New Application"
)
project.state # => "draft"

# Define scope
project.update!(
  brief: "An innovative new application",
  gates_config: { require_tests: true, require_review: true }
)
project.scope!

# Bootstrap repository
project.update!(
  repo_full_name: "myorg/my-new-app",
  repo_default_branch: "main",
  github_pat_secret_name: "MY_APP_PAT"
)
project.bootstrap_repo!

# Start development
project.start_build!

# Deploy to production
project.go_live!
```

### Reverting to Development

```ruby
# If updates are needed
live_project = Project.find_by(slug: "my-app")
live_project.state # => "live"

live_project.revert_to_build!
# Make updates...
# Test and validate...
live_project.go_live!
```

## Testing

State transitions should be tested to ensure:
- Valid transitions succeed
- Invalid transitions fail with appropriate errors
- State persistence is atomic
- Callbacks and validations execute correctly

Example RSpec tests:

```ruby
RSpec.describe Project, type: :model do
  describe "state machine" do
    it "starts in draft state" do
      project = Project.create!(slug: "test")
      expect(project.state).to eq("draft")
    end

    it "can transition from draft to scoped" do
      project = Project.create!(slug: "test")
      expect { project.scope! }.to change { project.state }.from("draft").to("scoped")
    end

    it "cannot skip states" do
      project = Project.create!(slug: "test", state: "draft")
      expect { project.bootstrap_repo! }.to raise_error(AASM::InvalidTransition)
    end
  end
end
```

## References

- [AASM (Acts As State Machine)](https://github.com/aasm/aasm)
- [Rails Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
- [State Machine Pattern](https://refactoring.guru/design-patterns/state)
