# Git Hooks with Lefthook

This project uses [Lefthook](https://github.com/evilmartians/lefthook) to manage Git hooks that ensure code quality before commits reach CI.

## Overview

Git hooks automatically run checks at different stages of your Git workflow:

- **Pre-commit**: Runs linters and formatters on staged files before committing
- **Commit-msg**: Validates commit messages follow Conventional Commits format
- **Pre-push**: Runs full test suite before pushing to remote

## Installation

Git hooks are automatically installed when you run:

```bash
bin/setup
```

Or manually:

```bash
bundle exec lefthook install
```

## Pre-commit Hook

Automatically formats and lints staged files before commit:

### What it does

1. **RuboCop** - Auto-corrects Ruby code style issues
2. **ERB Lint** - Auto-corrects ERB template issues
3. **ESLint** - Auto-fixes JavaScript/TypeScript linting issues
4. **Prettier** - Formats JavaScript/TypeScript, JSON, YAML, Markdown
5. **TypeScript** - Type-checks TypeScript files (validation only)

### How it works

- Only processes **staged files** (files you've `git add`ed)
- Automatically stages fixed files with `stage_fixed: true`
- Runs checks in parallel for speed
- Fails the commit if TypeScript type checking fails

### Example

```bash
$ git add app/models/user.rb
$ git commit -m "feat: add user model"

# Lefthook runs:
# ✓ RuboCop auto-corrects user.rb
# ✓ Files are re-staged
# ✓ Commit proceeds
```

## Commit Message Hook

Enforces [Conventional Commits](https://www.conventionalcommits.org/) specification using [commitlint](https://commitlint.js.org/).

### Valid commit types

- `feat:` - A new feature
- `fix:` - A bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting, semicolons, etc.)
- `refactor:` - Code refactoring (no feature change or bug fix)
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks, dependency updates
- `ci:` - CI/CD configuration changes
- `build:` - Build system or external dependency changes
- `perf:` - Performance improvements
- `revert:` - Revert a previous commit

### Format

```
<type>(<optional scope>): <description>

[optional body]

[optional footer]
```

### Examples

**Valid commits:**
```bash
git commit -m "feat: add user authentication"
git commit -m "fix: resolve login bug"
git commit -m "docs: update README"
git commit -m "feat(auth): add password reset"
git commit -m "fix(api): handle null response"
```

**Invalid commits:**
```bash
git commit -m "added user auth"           # Missing type
git commit -m "FEAT: add auth"            # Type must be lowercase
git commit -m "feat: Add auth."           # Subject must be lowercase, no period
```

## Pre-push Hook

Runs the full CI suite locally before pushing to prevent broken builds:

### What it does

1. **bin/lint** - Runs all linters (RuboCop, ERB Lint, ESLint, Prettier, TypeScript)
2. **bin/test** - Runs the complete RSpec test suite

### How it works

- Runs after you execute `git push`
- Blocks the push if any check fails
- Ensures remote branch stays green

### Example

```bash
$ git push origin feature/my-feature

# Lefthook runs:
# ✓ bin/lint (all linters pass)
# ✓ bin/test (all tests pass)
# ✓ Push proceeds
```

## Bypassing Hooks

**⚠️ Use sparingly and only in emergencies!**

### Skip all hooks for a commit

```bash
git commit --no-verify -m "emergency: critical hotfix"
```

### Skip pre-push hook

```bash
git push --no-verify
```

### When to bypass

- **Emergency hotfixes** that need immediate deployment
- **WIP commits** to save work (but don't push these!)
- **Temporary local experiments**

### When NOT to bypass

- "I'm in a hurry" - hooks are fast and save time by catching issues early
- "I'll fix it later" - CI will fail anyway, fix it now
- "The linter is wrong" - either fix the code or update the linter config

## Manual Hook Execution

Run hooks manually without committing:

```bash
# Run pre-commit checks
lefthook run pre-commit

# Run commit message validation
echo "feat: test message" | lefthook run commit-msg

# Run pre-push checks
lefthook run pre-push
```

## Configuration

Hook configuration is in `lefthook.yml` at the repository root.

### Customizing hooks

Edit `lefthook.yml` to:
- Add new commands
- Adjust file patterns (globs)
- Enable/disable specific checks
- Change parallelization

After modifying, reinstall hooks:

```bash
lefthook install -f
```

## Troubleshooting

### Hooks not running

```bash
# Reinstall hooks
lefthook install -f

# Check hook installation
ls -la .git/hooks/
```

### Hooks failing

```bash
# Run individual linters to debug
bin/rubocop
bundle exec erb_lint --lint-all
npm run lint:js
npm run typecheck

# Check specific file
bundle exec rubocop app/models/user.rb
```

### Commitlint failing

```bash
# Test commit message format
echo "feat: my message" | npx commitlint
```

### Pre-push taking too long

Consider running tests in parallel or reducing test scope for pre-push:

```yaml
# In lefthook.yml
pre-push:
  commands:
    test:
      run: bin/test --tag ~slow  # Skip slow tests
```

## Best Practices

1. **Commit often** - Small commits are easier to review and revert
2. **Write clear messages** - Follow Conventional Commits for consistency
3. **Run hooks manually** - Use `lefthook run pre-commit` before committing large changes
4. **Keep hooks fast** - Pre-commit should complete in seconds, not minutes
5. **Don't bypass unnecessarily** - Hooks catch issues early, saving time

## Additional Resources

- Lefthook documentation: https://github.com/evilmartians/lefthook
- Conventional Commits: https://www.conventionalcommits.org/
- Commitlint: https://commitlint.js.org/
- Git hooks reference: https://git-scm.com/docs/githooks
