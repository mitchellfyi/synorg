# Gemini Code Assist Style Guide for Synorg

This file customizes Gemini Code Assist behavior for code reviews, pull requests, and general assistance with the Synorg repository.

## Repository Overview

Synorg is a modern Rails edge application with PostgreSQL, Solid Queue, Tailwind CSS, esbuild, and Hotwire.

**Stack**:

- Ruby on Rails 8.1.1 (edge)
- Ruby 3.2.3
- PostgreSQL 16+
- Solid Queue (background jobs)
- Tailwind CSS v4
- TypeScript with esbuild
- Hotwire (Turbo & Stimulus)
- RSpec (testing)

## Operating Loop for Code Changes

When reviewing or suggesting code changes, follow this loop:

**clarify → look up official docs → research best approach → change → lint/format → test → self-review → document → run local CI → sync with `main` → commit (Conventional Commits) → sync with `main` again → reflect.**

Keep the codebase readable, maintainable, accessible, and secure.

References:

- [Trunk-based development](https://www.atlassian.com/continuous-delivery/continuous-integration/trunk-based-development)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- [Diátaxis documentation](https://diataxis.fr/)

## Code Review Guidelines

### What to Look For

1. **Conventional Commits**: Verify commit messages follow `feat:`, `fix:`, `chore:`, `docs:`, etc.
2. **Small, Focused Changes**: PRs should be small and focused on a single concern
3. **Tests**: All new code should have appropriate RSpec tests
4. **Linting**: Code should pass all linters (RuboCop, ESLint, Prettier, erb_lint)
5. **Security**: No secrets committed, inputs validated, outputs encoded
6. **Documentation**: Changes should update relevant docs
7. **Accessibility**: UI changes should meet WCAG 2.2 AA standards

### Code Style

#### Ruby/Rails

- Follow Rails conventions and RuboCop GitHub preset
- Use RSpec for testing (no Minitest)
- Use Solid Queue for background jobs
- Prefer explicit over implicit code
- Keep controllers thin, models focused

#### JavaScript/TypeScript

- Use TypeScript for type safety
- Follow ESLint flat config rules
- Format with Prettier
- Use Hotwire (Turbo/Stimulus) for interactivity
- Keep bundle sizes minimal

#### CSS

- Use Tailwind utility classes
- Follow mobile-first responsive design
- Avoid custom CSS when Tailwind utilities exist

### Quality Standards

- **DRY sensibly**: Use the rule of three before extracting
- **SOLID principles**: Apply where it improves testability and extensibility
- **Tests**: Many small unit tests, targeted integration tests, few e2e tests
- **Refactoring**: Tiny, behaviour-preserving steps only
- **Performance**: No obvious performance issues
- **Readability**: Code should be clear and self-documenting

## Security & Privacy

When reviewing code, ensure:

- **OWASP Top 10** vulnerabilities are avoided
- Secrets never committed to the repository
- All user inputs are validated
- All outputs are properly encoded
- Least privilege principle is followed
- Dependencies are up to date and not vulnerable

References:

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheets](https://cheatsheetseries.owasp.org/index.html)

## Accessibility & UX

- Check for **WCAG 2.2 AA** compliance
- Verify against **Nielsen's 10 usability heuristics**
- Ensure responsive design works on mobile and desktop

References:

- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [Nielsen's Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)

## CI/CD Expectations

All PRs must pass:

- RuboCop linting
- ERB Lint
- ESLint
- Prettier formatting check
- TypeScript type check
- Brakeman security scan
- bundler-audit dependency scan
- RSpec test suite
- Playwright smoke tests (if present)

PRs should not be merged with failing CI checks.

## Pull Request Best Practices

### Good PRs

- Small and focused on a single concern
- Include tests for new functionality
- Update documentation as needed
- Follow Conventional Commits format
- Pass all CI checks
- Include clear description of changes
- Link to related issues

### Red Flags

- Large PRs with many unrelated changes
- Missing tests
- Failing CI checks
- Security vulnerabilities
- Performance regressions
- Breaking changes without migration path
- Committed secrets or credentials

## Synorg-Specific Patterns

### Commands to Suggest

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

# Security
bin/brakeman
bin/bundler-audit
```

### Git Workflow

- Branch from `main`
- Keep `main` releasable
- Rebase or merge to stay synced with `main`
- Use `--force-with-lease` if rebasing
- Run local CI before pushing

References:

- [git-rebase](https://git-scm.com/docs/git-rebase)
- [Merge vs rebase](https://www.atlassian.com/git/tutorials/merging-vs-rebasing)

### Documentation Structure

- `/docs` - Detailed documentation
- `AGENTS.md` - Agent conventions
- `.github/copilot-instructions.md` - Copilot instructions
- `README.md` - Getting started
- `docs/ai/` - AI-specific docs

## Research Before Suggesting

Before making suggestions:

1. Read the latest **primary docs** for the relevant tool or framework
2. Check existing patterns in the codebase
3. Conform to established conventions
4. If deviating, explain why and provide migration path

## Upstream Documentation

Reference these when reviewing code:

- [Rails Guides](https://guides.rubyonrails.org/)
- [Solid Queue](https://github.com/rails/solid_queue)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Hotwire](https://hotwired.dev/)
- [RSpec](https://rspec.info/)
- [TypeScript](https://www.typescriptlang.org/docs/)
- [PostgreSQL](https://www.postgresql.org/docs/)

## Gemini-Specific References

- [Customize Gemini behavior in GitHub](https://developers.google.com/gemini-code-assist/docs/customize-gemini-behavior-github)
- [Review GitHub code with Gemini](https://developers.google.com/gemini-code-assist/docs/review-github-code)

---

**Note**: This styleguide helps Gemini Code Assist provide consistent, high-quality reviews and suggestions aligned with Synorg's conventions and best practices.
