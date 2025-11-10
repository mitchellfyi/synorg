# GitHub Copilot Custom Instructions

## Repository Context

This is **Synorg**, a Rails edge application with PostgreSQL, Solid Queue, Tailwind CSS, and esbuild.

For synorg's mission, core concepts, and orchestration architecture, see [MISSION.md](../MISSION.md).

## Operating Loop

Work in tiny loops: **clarify → look up official docs → research best approach → change → lint/format → test → self-review → document → run local CI → sync with `main` → commit (Conventional Commits) → sync with `main` again → reflect.** Keep the codebase readable, maintainable, accessible, and secure.

References:

- [Trunk-based development](https://www.atlassian.com/continuous-delivery/continuous-integration/trunk-based-development)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- [Diátaxis documentation framework](https://diataxis.fr/)

### Ground Rules

- Small branches and PRs; keep `main` releasable. Use feature flags when needed.
- Commits follow **Conventional Commits** (`feat:`, `fix:`, `chore:`, `docs:`, etc.)
- Apply **DRY** sensibly (use the **rule of three** before extracting) and **SOLID** where it improves testability/extensibility
- Update docs as you go (Diátaxis split: tutorials/how-tos/reference/explanation)

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

### Security & Accessibility

- Design with **OWASP Top 10** in mind; use the **Cheat Sheet Series**
- Never commit secrets; validate inputs; encode outputs; least privilege
- Aim for **WCAG 2.2 AA** compliance

References:

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheets](https://cheatsheetseries.owasp.org/index.html)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)

### Sync with `main`

**Before each commit**: `git fetch origin && git rebase origin/main` (or merge if preferred)
**After commit (before push)**: Repeat sync, resolve conflicts, **re-run local CI**, then push

References:

- [git-rebase](https://git-scm.com/docs/git-rebase)
- [Merge vs rebase](https://www.atlassian.com/git/tutorials/merging-vs-rebasing)

## Code Style & Standards

### Ruby

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

## Security

- Never commit secrets or credentials
- Use Rails credentials for sensitive data
- Run Brakeman before committing
- Keep dependencies updated
- Follow OWASP best practices

## Documentation

- Update docs when changing behavior
- Keep README concise
- Put detailed docs in `/docs`
- Document non-obvious decisions
- Include code examples

## Before Suggesting Code

1. Understand the full context
2. Check existing patterns in the codebase
3. Verify it follows our linting rules
4. Ensure it's testable
5. Consider security implications

## Best Practices

- Make minimal changes to achieve the goal
- Run linters and tests frequently
- Commit small, logical changes
- Write clear commit messages
- Update documentation as needed

## Common Commands

```bash
# Setup
bin/setup

# Development
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

## Key Technologies

- **Framework**: Ruby on Rails (edge)
- **Database**: PostgreSQL
- **Background Jobs**: Solid Queue
- **Frontend**: Tailwind CSS, Hotwire (Turbo/Stimulus)
- **JavaScript**: TypeScript with esbuild
- **Testing**: RSpec
- **Security**: Brakeman, bundler-audit

## When in Doubt

- Check `/docs` directory for guidance
- Review `AGENTS.md` for role-specific conventions
- Consult Rails edge documentation
- Follow the principle of least surprise

## Run CI Locally Before You Push

- Use pre-commit/pre-push hooks to run the same commands CI runs
- Optionally simulate GitHub Actions locally with [`act`](https://github.com/nektos/act)
- Keep PRs green – do **not** merge red builds

References:

- [GitHub Actions events](https://docs.github.com/actions/learn-github-actions/events-that-trigger-workflows)
- [GitHub-hosted runners](https://docs.github.com/actions/using-github-hosted-runners/about-github-hosted-runners)

## Path-Specific Instructions

For more specific guidance on certain paths or components, check for path-scoped instruction files in `.github/copilot-instructions/` (when supported).

References:

- [Repository custom instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- [Your first custom instructions](https://docs.github.com/en/copilot/tutorials/customization-library/custom-instructions/your-first-custom-instructions)
- [Copilot coding agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)
- [Using coding agent](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent)
