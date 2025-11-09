# AI Agent Roles & Conventions

This document defines the roles, specializations, and conventions for AI agents working on the Synorg codebase. It serves as the single source of truth for agent responsibilities, the Operating Loop, conventions, and safety rails.

## Coding Agent Operating Loop

Work in tiny loops: **clarify → look up official docs → research best approach → change → lint/format → test → self-review → document → run local CI → sync with `main` → commit (Conventional Commits) → sync with `main` again → reflect.** Keep the codebase readable, maintainable, accessible, and secure. **Re-read this loop at the start of every task and roughly every ~50k tokens used.**

References:

- Trunk-based development: [Atlassian](https://www.atlassian.com/continuous-delivery/continuous-integration/trunk-based-development), [Martin Fowler](https://martinfowler.com/articles/continuousIntegration.html)
- [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/)
- [Diátaxis documentation framework](https://diataxis.fr/start-here/)

### Ground Rules

- **Small branches and PRs**: Keep `main` releasable at all times. Use feature flags when needed.
- **Conventional Commits**: All commits follow the format: `feat:`, `fix:`, `chore:`, `docs:`, etc.
- **DRY sensibly**: Apply the **rule of three** before extracting. Don't over-abstract prematurely.
- **SOLID principles**: Apply where it improves testability and extensibility.
- **Update docs as you go**: Follow Diátaxis split (tutorials/how-tos/reference/explanation).

References:

- [DRY principle](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
- [SOLID principles](https://en.wikipedia.org/wiki/SOLID)

### Quality Bar – Every Change

**CRITICAL: All of the following MUST pass before committing code. No exceptions, no workarounds.**

1. **Linting (RuboCop, ERB Lint, ESLint, Prettier)**
   - Run: `bin/lint` or `bin/rubocop -f github` for Ruby files only
   - All offenses must be fixed or properly disabled with inline comments and justification
   - Zero warnings policy - keep the codebase clean
   
2. **Security Scanning (Brakeman, bundler-audit)**
   - Run: `bin/brakeman --no-pager` and `bin/bundler-audit`
   - No new security vulnerabilities may be introduced
   - Existing vulnerabilities in unchanged code are acceptable but should be documented
   
3. **Tests (RSpec)**
   - Run: `bin/test` or `bundle exec rspec`
   - All tests must pass
   - New code requires test coverage
   - Keep suites fast and deterministic

**Pre-commit and Pre-push hooks** (via Lefthook) enforce these requirements automatically:
- **Pre-commit**: Auto-fixes linting issues on staged files
- **Pre-push**: Runs full lint + security + test suite before allowing push

**To install hooks**: Run `lefthook install -f` after cloning the repository.

**CI/CD**: GitHub Actions runs the same checks. If local checks pass, CI should pass.

### Security, Privacy, Reliability

- Design with **OWASP Top 10** in mind
- Use the **OWASP Cheat Sheet Series** and secure coding checklist
- Never commit secrets
- Validate all inputs
- Encode all outputs
- Follow least privilege principle

References:

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/index.html)

### Accessibility, UX, DevEx

- Aim for **WCAG 2.2 AA** compliance
- Sanity-check UX against **Nielsen's 10 usability heuristics**

References:

- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [Nielsen's 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)

### Research and Consistency

- **Before implementing**: Read the latest **primary docs** for the tool you're touching and one reputable guide. Link sources in the PR.
- **Conform to existing patterns**: If deviating, explain why and migrate incrementally.

### Keep Your Branch in Sync with `main`

**Before each commit**: Fetch and integrate the latest `main` into your feature branch:

- Prefer linear history: `git fetch origin && git rebase origin/main`
- Alternatively merge if your team prefers: `git fetch origin && git merge origin/main`

**After the commit (before push)**: Repeat the sync quickly to catch new upstream changes. Resolve conflicts, **re-run local CI**, then push (use `--force-with-lease` if you rebased).

References:

- [git-rebase](https://git-scm.com/docs/git-rebase)
- [Atlassian rebase guide](https://www.atlassian.com/git/tutorials/rewriting-history/git-rebase)
- [Merge vs rebase](https://www.atlassian.com/git/tutorials/merging-vs-rebasing)
- [git-pull with rebase](https://git-scm.com/docs/git-pull)

### Run CI Locally Before You Push

- Use pre-commit/pre-push hooks to run the same commands CI runs (lint/format/tests/type-checks)
- Optionally simulate **GitHub Actions** locally with [`act`](https://github.com/nektos/act)
- **Keep PRs green** – do not merge red builds

References:

- [GitHub Actions events](https://docs.github.com/actions/learn-github-actions/events-that-trigger-workflows)
- [GitHub-hosted runners](https://docs.github.com/actions/using-github-hosted-runners/about-github-hosted-runners)

## How to Stay in Context

- Re-read this Operating Loop at the start of every task
- Check existing documentation in `/docs` before making assumptions
- Review `AGENTS.md` (this file) for role-specific conventions
- Consult `.github/copilot-instructions.md` for tool-specific guidance
- Reference upstream documentation for all technologies you're using
- Re-read roughly every ~50k tokens to stay aligned with conventions

## Core Principles

All AI agents working on this repository must adhere to the following principles:

1. **Thoroughness**: Understand the problem completely before making changes
2. **Documentation**: Every change must be documented and explained
3. **Testing**: All changes must include appropriate tests
4. **Idempotency**: Scripts and operations should be safe to run multiple times
5. **Security**: Always check for security vulnerabilities before committing
6. **Code Quality**: Follow established linting and formatting standards

## Agent Roles

### Senior Dev Tooling Engineer

**Specialization**: Development infrastructure, build tooling, CI/CD, linters, formatters

**Responsibilities**:

- Setting up and maintaining build systems
- Configuring linters and formatters (RuboCop, ESLint, Prettier, ERB Lint)
- Managing CI/CD pipelines
- Ensuring developer experience is smooth and consistent
- Maintaining documentation for development workflows

**Key Practices**:

- Use official installers and maintained presets
- Keep defaults conventional
- Document non-obvious choices under `/docs`
- Keep README concise and actionable
- Always verify configurations work across team environments

### Backend Engineer (Rails)

**Specialization**: Ruby on Rails application development, database design, API development

**Responsibilities**:

- Developing Rails models, controllers, and services
- Database migrations and schema design
- Background job implementation with Solid Queue
- API endpoint development
- Performance optimization

**Key Practices**:

- Follow Rails conventions and best practices
- Use edge Rails features appropriately
- Write comprehensive RSpec tests
- Ensure database queries are optimized
- Use Solid Queue for background processing

### Frontend Engineer

**Specialization**: JavaScript/TypeScript, Tailwind CSS, Hotwire (Turbo/Stimulus)

**Responsibilities**:

- Building interactive UI components
- Implementing Stimulus controllers
- Styling with Tailwind CSS
- Managing JavaScript build pipeline (esbuild)
- Ensuring accessibility and responsive design

**Key Practices**:

- Use TypeScript for type safety
- Follow ESLint and Prettier configurations
- Keep JavaScript bundle sizes minimal
- Use Hotwire for progressive enhancement
- Test JavaScript functionality

### Security Engineer

**Specialization**: Security scanning, vulnerability assessment, secure coding practices

**Responsibilities**:

- Running Brakeman and bundler-audit
- Reviewing code for security vulnerabilities
- Ensuring credentials are not committed
- Managing secrets and environment variables
- Keeping dependencies updated

**Key Practices**:

- Run security scans before every commit
- Never commit secrets or credentials
- Use Rails credentials for sensitive data
- Keep dependencies up to date
- Follow OWASP best practices

## Workflow Conventions

### Before Starting Work

1. Read and understand the issue or requirement completely
2. Check existing documentation in `/docs`
3. Review related code and tests
4. Plan the minimal changes needed
5. Verify you have the right specialization for the task

### During Development

1. Make small, incremental changes
2. Run linters and tests frequently
3. Commit often with clear messages
4. Document as you go
5. Seek clarification if requirements are unclear

### Before Completing Work

1. Run full test suite (`bin/test`)
2. Run all linters (`bin/lint`)
3. Run security scans (Brakeman, bundler-audit)
4. Update documentation if needed
5. Verify changes work as expected

## Code Review Standards

All code should be:

- **Readable**: Clear and self-documenting
- **Tested**: Covered by appropriate tests
- **Secure**: Free of common vulnerabilities
- **Performant**: No obvious performance issues
- **Maintainable**: Easy for others to modify

## Documentation Standards

- Keep README concise and focused on getting started
- Put detailed docs in `/docs` directory
- Use clear headers and structure
- Include code examples where helpful
- Keep documentation up to date with code changes

## Tool Configuration

### Ruby/Rails

- **Ruby Version**: Defined in `.ruby-version`
- **Linter**: RuboCop with GitHub preset
- **Test Framework**: RSpec only (no Minitest)
- **Background Jobs**: Solid Queue

### JavaScript/TypeScript

- **Linter**: ESLint with flat config
- **Formatter**: Prettier
- **Type Checker**: TypeScript with `noEmit: true`
- **Bundler**: esbuild

### CSS

- **Framework**: Tailwind CSS
- **Build**: Tailwind CLI

### Database

- **Development**: PostgreSQL
- **Test**: PostgreSQL
- **Production**: PostgreSQL

## Continuous Integration

All PRs must pass CI checks:

- RuboCop linting
- ERB Lint
- ESLint
- Prettier formatting check
- TypeScript type check
- Brakeman security scan
- bundler-audit dependency scan
- RSpec test suite
- Playwright smoke tests (if present)

## Synorg Stack & Context

When generating code, documentation, or follow-up tasks, **always adapt to this specific codebase**:

### Technology Stack

- **Framework**: Ruby on Rails 8.1.1 (edge)
- **Language**: Ruby 3.2.3
- **Database**: PostgreSQL 16+
- **Background Jobs**: Solid Queue
- **Frontend CSS**: Tailwind CSS v4
- **Frontend JS**: TypeScript with esbuild
- **Interactive UI**: Hotwire (Turbo & Stimulus)
- **Testing**: RSpec

### Development Tools

- **Ruby Linting**: RuboCop (GitHub preset)
- **ERB Linting**: erb_lint
- **JavaScript Linting**: ESLint (flat config)
- **Formatting**: Prettier
- **Security Scanning**: Brakeman, bundler-audit
- **Git Hooks**: Lefthook
- **Commit Messages**: Conventional Commits (enforced via commitlint)

### Key Commands

- `bin/setup` - Idempotent setup script
- `bin/dev` - Start all services (Rails, Solid Queue, asset watchers)
- `bin/test` - Run RSpec test suite
- `bin/lint` - Run all linters
- `bin/format` - Auto-fix linting issues
- `bin/brakeman` - Security scan
- `bin/bundler-audit` - Dependency vulnerability check

### Documentation Locations

- `/docs` - Detailed documentation
- `AGENTS.md` - This file (agent conventions)
- `.github/copilot-instructions.md` - GitHub Copilot instructions
- `README.md` - Getting started guide
- `docs/ai/` - AI-specific documentation and prompts

### Upstream Documentation References

When working on this codebase, consult these primary sources:

- [Rails Guides](https://guides.rubyonrails.org/)
- [Solid Queue](https://github.com/rails/solid_queue)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Hotwire](https://hotwired.dev/)
- [RSpec](https://rspec.info/)
- [TypeScript](https://www.typescriptlang.org/docs/)

## Getting Help

If you're stuck or uncertain:

1. Check the documentation in `/docs`
2. Review this AGENTS.md file
3. Check GitHub Copilot custom instructions in `.github/copilot-instructions.md`
4. Ask for clarification in the issue or PR
5. Consult upstream documentation for the relevant tool or framework
