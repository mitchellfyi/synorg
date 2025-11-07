# Cursor AI Foundations for Synorg

This file provides foundational rules and conventions for Cursor AI when working with the Synorg repository.

## Repository Overview

Synorg is a modern Ruby on Rails edge application with:
- **Framework**: Ruby on Rails 8.1.1 (edge)
- **Language**: Ruby 3.2.3
- **Database**: PostgreSQL 16+
- **Background Jobs**: Solid Queue
- **Frontend CSS**: Tailwind CSS v4
- **Frontend JS**: TypeScript with esbuild
- **Interactive UI**: Hotwire (Turbo & Stimulus)
- **Testing**: RSpec

## Coding Agent Operating Loop

Work in tiny loops: **clarify → look up official docs → research best approach → change → lint/format → test → self-review → document → run local CI → sync with `main` → commit (Conventional Commits) → sync with `main` again → reflect.**

Keep the codebase readable, maintainable, accessible, and secure. **Re-read this loop at the start of every task and roughly every ~50k tokens used.**

References:
- Trunk-based development: [Atlassian](https://www.atlassian.com/continuous-delivery/continuous-integration/trunk-based-development), [Martin Fowler](https://martinfowler.com/articles/continuousIntegration.html)
- [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/)
- [Diátaxis documentation framework](https://diataxis.fr/start-here/)

## Ground Rules

- **Small branches and PRs**: Keep `main` releasable at all times. Use feature flags when needed.
- **Conventional Commits**: All commits follow the format: `feat:`, `fix:`, `chore:`, `docs:`, etc.
- **DRY sensibly**: Apply the **rule of three** before extracting. Don't over-abstract prematurely.
- **SOLID principles**: Apply where it improves testability and extensibility.
- **Update docs as you go**: Follow Diátaxis split (tutorials/how-tos/reference/explanation).

References:
- [DRY principle](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
- [SOLID principles](https://en.wikipedia.org/wiki/SOLID)

## Quality Bar – Every Change

- **Lint/format before tests**: Keep warnings at zero.
- **Tests first or concurrent**: Many small unit tests, targeted integration tests, few end-to-end tests. Keep suites fast and deterministic.
- **Refactor in tiny steps**: Behaviour-preserving incremental changes only.

## Security, Privacy, Reliability

- Design with **OWASP Top 10** in mind
- Use the **OWASP Cheat Sheet Series** and secure coding checklist
- Never commit secrets
- Validate all inputs
- Encode all outputs
- Follow least privilege principle

References:
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/index.html)

## Accessibility, UX, DevEx

- Aim for **WCAG 2.2 AA** compliance
- Sanity-check UX against **Nielsen's 10 usability heuristics**

References:
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [Nielsen's 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)

## Research and Consistency

- **Before implementing**: Read the latest **primary docs** for the tool you're touching and one reputable guide. Link sources in your code comments or PR.
- **Conform to existing patterns**: If deviating, explain why and migrate incrementally.

## Keep Your Branch in Sync with `main`

**Before each commit**: Fetch and integrate the latest `main` into your feature branch:
- Prefer linear history: `git fetch origin && git rebase origin/main`
- Alternatively merge if your team prefers: `git fetch origin && git merge origin/main`

**After the commit (before push)**: Repeat the sync quickly to catch new upstream changes. Resolve conflicts, **re-run local CI**, then push (use `--force-with-lease` if you rebased).

References:
- [git-rebase](https://git-scm.com/docs/git-rebase)
- [Atlassian rebase guide](https://www.atlassian.com/git/tutorials/rewriting-history/git-rebase)
- [Merge vs rebase](https://www.atlassian.com/git/tutorials/merging-vs-rebasing)
- [git-pull with rebase](https://git-scm.com/docs/git-pull)

## Run CI Locally Before You Push

- Use pre-commit/pre-push hooks (via Lefthook) to run the same commands CI runs
- Optionally simulate **GitHub Actions** locally with [`act`](https://github.com/nektos/act)
- **Keep PRs green** – do not merge red builds

References:
- [GitHub Actions events](https://docs.github.com/actions/learn-github-actions/events-that-trigger-workflows)
- [GitHub-hosted runners](https://docs.github.com/actions/using-github-hosted-runners/about-github-hosted-runners)

## Synorg-Specific Code Style

### Ruby/Rails
- Use Rails conventions and idioms
- Follow RuboCop GitHub preset
- Write RSpec tests for all new code
- Use Solid Queue for background jobs
- Prefer explicit over implicit

### JavaScript/TypeScript
- Use TypeScript for type safety
- Follow ESLint flat config rules
- Format with Prettier
- Keep bundle sizes minimal
- Use Hotwire (Turbo/Stimulus) for interactivity

### CSS
- Use Tailwind utility classes
- Follow mobile-first responsive design
- Avoid custom CSS when Tailwind utilities suffice

## Testing Philosophy

- **RSpec only** - no Minitest
- Write tests before or alongside code
- Test behavior, not implementation
- Use factories (FactoryBot) for test data
- Keep tests fast and focused

## Key Commands

```bash
# Setup (idempotent)
bin/setup

# Development (all services)
bin/dev

# Testing
bin/test

# Linting
bin/lint

# Formatting
bin/format

# Security scans
bin/brakeman
bin/bundler-audit
```

## Documentation Locations

- `/docs` - Detailed documentation
- `AGENTS.md` - Agent conventions and Operating Loop (single source of truth)
- `.github/copilot-instructions.md` - GitHub Copilot instructions
- `README.md` - Getting started guide
- `docs/ai/` - AI-specific documentation and prompts

## Architecture & Patterns

Before making changes, understand existing patterns:
- Rails models → `app/models/`
- Controllers → `app/controllers/`
- Background jobs → `app/jobs/`
- Views/templates → `app/views/`
- JavaScript/TypeScript → `app/javascript/`
- Tests → `spec/`

## Upstream Documentation

When working on Synorg, consult these primary sources:
- [Rails Guides](https://guides.rubyonrails.org/)
- [Solid Queue](https://github.com/rails/solid_queue)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Hotwire](https://hotwired.dev/)
- [RSpec](https://rspec.info/)
- [TypeScript](https://www.typescriptlang.org/docs/)
- [PostgreSQL](https://www.postgresql.org/docs/)

## Cursor-Specific Tips

1. **Always lint and test after generating code**
2. **Follow the Operating Loop** - don't skip steps
3. **Make small, focused changes** that can be easily reviewed
4. **Check existing patterns** before introducing new ones
5. **Document as you go** - update relevant docs with your changes
6. **Link sources** when referencing external documentation or best practices

## Cursor Rules Reference

- [Cursor Rules Documentation](https://cursor.com/docs/context/rules)

---

**Note**: This is the foundational rules file for Cursor. Additional rule files can be added to `.cursor/rules/` for specific domains or components. Rule files are loaded in alphabetical order, so this `000-foundations.md` loads first.
