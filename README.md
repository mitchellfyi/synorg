# Synorg

A modern Rails application built with edge Rails, PostgreSQL, Solid Queue, Tailwind CSS, and esbuild.

## Quick Start

```bash
# Install dependencies
bin/setup

# Start development server
bin/dev
```

Visit http://localhost:3000

## Requirements

- Ruby 3.2.3 (see `.ruby-version`)
- Node.js 20.x (see `.node-version`)
- PostgreSQL 16+
- Bundler 2.7+

## Development

### Setup

The `bin/setup` script is idempotent and safe to run multiple times:

```bash
bin/setup
```

This will:
- Install Ruby dependencies
- Install JavaScript dependencies
- Create and migrate databases
- Prepare test database
- Install Git hooks (Lefthook)

### Git Hooks

Git hooks are automatically installed via Lefthook to ensure code quality:

- **Pre-commit**: Auto-formats and lints staged files (RuboCop, ERB Lint, ESLint, Prettier)
- **Commit-msg**: Enforces Conventional Commits format (`feat:`, `fix:`, etc.)
- **Pre-push**: Runs full test suite and linters before pushing

To bypass hooks in emergencies:
```bash
git commit --no-verify
git push --no-verify
```

See `docs/commands.md` for more details on git hooks.

### Running the App

Start all services (Rails server, Solid Queue worker, asset watchers):

```bash
bin/dev
```

Individual processes:
- Rails server: `bin/rails server`
- Background jobs: `bin/jobs`
- JavaScript build: `npm run build -- --watch`
- CSS build: `npm run build:css -- --watch`

### Testing

Run the full test suite:

```bash
bin/test
```

Run specific tests:

```bash
bin/test spec/models/user_spec.rb
```

### Linting & Formatting

Check all code:

```bash
bin/lint
```

Auto-fix issues:

```bash
bin/format
```

Individual linters:
- Ruby: `bin/rubocop`
- ERB: `bundle exec erblint --lint-all`
- JavaScript: `npm run lint:js`
- Prettier: `npm run format:check`
- TypeScript: `npm run typecheck`

### Security Scans

Run security audits:

```bash
bin/brakeman          # Static analysis for Rails security
bin/bundler-audit     # Check for vulnerable gems
```

## Technology Stack

### Backend
- **Framework**: Ruby on Rails 8.2.0.alpha (edge)
- **Language**: Ruby 3.2.3
- **Database**: PostgreSQL
- **Background Jobs**: Solid Queue
- **Testing**: RSpec

### Frontend
- **CSS**: Tailwind CSS v4
- **JavaScript**: TypeScript with esbuild
- **Framework**: Hotwire (Turbo & Stimulus)

### Development Tools
- **Ruby Linting**: RuboCop (GitHub preset)
- **ERB Linting**: erb_lint
- **JS Linting**: ESLint (flat config)
- **Formatting**: Prettier
- **Security**: Brakeman, bundler-audit

## CI/CD

GitHub Actions runs on every non-draft PR:
- Ruby linting (RuboCop, erb_lint)
- JavaScript linting (ESLint, Prettier)
- TypeScript type checking
- Security scans (Brakeman, bundler-audit)
- RSpec test suite
- Playwright smoke tests

### Required Secrets

Set `RAILS_MASTER_KEY` in GitHub Actions secrets for CI to work:

1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `RAILS_MASTER_KEY`
4. Value: Contents of `config/master.key` (never commit this file)

The master key is used to decrypt Rails credentials. Keep it secure.

## Project Structure

```
app/
  ├── assets/         # Static assets and build output
  ├── controllers/    # Rails controllers
  ├── helpers/        # View helpers
  ├── javascript/     # TypeScript/JavaScript source
  ├── jobs/           # Background jobs
  ├── mailers/        # Email mailers
  ├── models/         # ActiveRecord models
  └── views/          # ERB templates
bin/                  # Executable scripts
config/               # Application configuration
db/                   # Database migrations and schema
docs/                 # Project documentation
spec/                 # RSpec tests
```

## Documentation

- **Setup Guide**: See this README
- **Agent Conventions**: See `AGENTS.md`
- **Copilot Instructions**: See `.github/copilot-instructions.md`
- **Detailed Docs**: See `docs/` directory

## Contributing

1. Create a branch from `main`
2. Make your changes
3. Run `bin/lint` and `bin/test`
4. Submit a pull request
5. CI must pass before merging

## License

All rights reserved.

