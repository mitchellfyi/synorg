# Continuous Integration (CI)

This document describes the CI/CD pipeline for the Synorg application.

## Overview

GitHub Actions runs automated checks on every non-draft pull request and push to the main branch.

## CI Jobs

### 1. Check PR Status

Determines if the PR is a draft to skip CI for draft PRs.

### 2. Ruby Linting (`lint_ruby`)

Checks Ruby and ERB code style:

- RuboCop with GitHub preset
- ERB Lint for templates

**Runs on**: Non-draft PRs and main branch pushes

**Required to pass**: Yes

### 3. JavaScript/TypeScript Linting (`lint_js`)

Checks JavaScript and TypeScript code:

- ESLint with flat config
- Prettier formatting
- TypeScript type checking

**Runs on**: Non-draft PRs and main branch pushes

**Required to pass**: Yes

### 4. Security Scans (`security`)

Scans for security vulnerabilities:

- Brakeman (static analysis for Rails)
- bundler-audit (checks for vulnerable gems)

**Runs on**: Non-draft PRs and main branch pushes

**Required to pass**: Yes

### 5. Tests (`test`)

Runs the RSpec test suite with PostgreSQL:

- Sets up PostgreSQL 16 service
- Builds JavaScript and CSS assets
- Runs database migrations
- Executes RSpec tests

**Runs on**: Non-draft PRs and main branch pushes

**Required to pass**: Yes

### 6. Playwright Tests (`playwright`)

Runs end-to-end browser tests (optional):

- Installs Playwright browsers
- Runs tests if they exist
- Passes gracefully if no tests are present

**Runs on**: Non-draft PRs and main branch pushes

**Required to pass**: Yes (but passes if no tests exist)

## Required Secrets

### RAILS_MASTER_KEY

The Rails master key is required for CI to decrypt credentials.

**How to set it**:

1. Navigate to: Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `RAILS_MASTER_KEY`
4. Value: Contents of `config/master.key`

⚠️ **Never commit `config/master.key` to version control**

## Workflow File

Location: `.github/workflows/ci.yml`

## Running CI Locally

You can run the same checks locally before pushing:

### Ruby Linting

```bash
bin/rubocop
bundle exec erb_lint --lint-all
```

### JavaScript Linting

```bash
yarn lint:js
yarn format:check
yarn typecheck
```

### Security Scans

```bash
bin/brakeman --no-pager
bin/bundler-audit
```

### Tests

```bash
bin/test
```

### All Checks

```bash
bin/lint  # Runs all linters
bin/test  # Runs all tests
```

## Troubleshooting CI

### CI doesn't run on my PR

- Check if your PR is marked as "Draft" - CI skips draft PRs
- Convert to "Ready for review" to trigger CI

### RuboCop failures

Run locally and auto-fix:

```bash
bin/rubocop -A
```

### ERB Lint failures

Run locally and auto-fix:

```bash
bundle exec erb_lint --lint-all --autocorrect
```

### ESLint failures

Run locally and auto-fix:

```bash
yarn eslint app/javascript --fix
```

### Prettier failures

Run locally and auto-fix:

```bash
yarn format:fix
```

### TypeScript errors

Check types locally:

```bash
yarn typecheck
```

### Test failures

Run tests locally:

```bash
bin/test
```

For specific tests:

```bash
bin/test spec/models/user_spec.rb
```

### Brakeman failures

Review the security warnings carefully. If they're false positives, you can ignore them in `config/brakeman.ignore`:

```bash
bin/brakeman -I
```

### bundler-audit failures

Update the vulnerable gem or acknowledge the advisory in `config/bundler-audit.yml`:

```yaml
ignore:
  - CVE-XXXX-XXXXX
```

### PostgreSQL connection issues in CI

The workflow uses a PostgreSQL service container. If tests fail with database errors:

1. Check the `DATABASE_URL` in `.github/workflows/ci.yml`
2. Ensure migrations are running correctly
3. Check for schema.rb conflicts

## Branch Protection

Recommended branch protection rules for `main`:

1. Require pull request reviews before merging
2. Require status checks to pass:
   - `lint_ruby`
   - `lint_js`
   - `security`
   - `test`
   - `playwright`
3. Require branches to be up to date before merging
4. Require conversation resolution before merging

Configure at: Settings → Branches → Add rule

## Caching

The CI workflow uses caching to speed up builds:

- **Ruby gems**: Cached via `ruby/setup-ruby` with `bundler-cache: true`
- **Node modules**: Cached via `actions/setup-node` with `cache: 'yarn'`
- **RuboCop cache**: Cached via `actions/cache`

Caches are invalidated when dependencies change.

## Performance

Typical CI run times:

- Ruby linting: ~30 seconds
- JavaScript linting: ~20 seconds
- Security scans: ~40 seconds
- Tests: ~60 seconds (depends on test count)
- Playwright: ~30 seconds (if tests exist)

**Total**: ~3-4 minutes for a full CI run

## Future Enhancements

Potential improvements to CI:

- [ ] Add test coverage reporting
- [ ] Parallelize test runs
- [ ] Add performance benchmarking
- [ ] Deploy preview environments for PRs
- [ ] Add visual regression testing
- [ ] Cache Docker layers for faster builds
