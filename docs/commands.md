# Development Commands Quick Reference

## Setup

```bash
# Initial setup (idempotent, safe to run multiple times)
bin/setup

# Update dependencies
bundle install
npm install
```

## Development Server

```bash
# Start all services (Rails, Solid Queue, JS build, CSS build)
bin/dev

# Individual services
bin/rails server           # Rails app only
bin/jobs                   # Background worker only
npm run build -- --watch   # JavaScript build watch mode
npm run build:css -- --watch  # CSS build watch mode
```

## Database

```bash
# Create and migrate database
bin/rails db:create
bin/rails db:migrate

# Reset database (drop, create, migrate, seed)
bin/rails db:reset

# Rollback migration
bin/rails db:rollback

# View database status
bin/rails db:migrate:status

# Open database console
bin/rails dbconsole
```

## Code Quality

```bash
# Run all linters
bin/lint

# Auto-fix all issues
bin/format

# Individual linters
bin/rubocop                           # Ruby linter
bin/rubocop -A                        # Ruby auto-fix
bundle exec erb_lint --lint-all       # ERB linter
bundle exec erb_lint --lint-all --autocorrect  # ERB auto-fix
npm run lint:js                       # JavaScript linter
npm run lint:js -- --fix              # JavaScript auto-fix
npm run format:check                  # Prettier check
npm run format:fix                    # Prettier auto-fix
npm run typecheck                     # TypeScript type check
```

## Security

```bash
# Run security scans
bin/brakeman --no-pager    # Rails security scan
bin/bundler-audit          # Gem vulnerability scan

# Update security advisories
bundle exec bundler-audit update
```

## Testing

```bash
# Run all tests
bin/test

# Run specific test file
bin/test spec/models/user_spec.rb

# Run tests matching a pattern
bin/test spec/models/

# Run with specific options
bundle exec rspec --format documentation
bundle exec rspec --fail-fast  # Stop on first failure
```

## Rails Console

```bash
# Development console
bin/rails console

# Production console (careful!)
bin/rails console -e production

# Sandbox mode (rollback all changes on exit)
bin/rails console --sandbox
```

## Routes

```bash
# List all routes
bin/rails routes

# Search routes
bin/rails routes | grep users

# Show routes for specific controller
bin/rails routes -c UsersController
```

## Generators

```bash
# Generate model
bin/rails generate model User name:string email:string

# Generate controller
bin/rails generate controller Users index show

# Generate migration
bin/rails generate migration AddAgeToUsers age:integer

# Generate RSpec test
bin/rails generate rspec:model User
bin/rails generate rspec:controller Users
```

## Background Jobs

```bash
# Start background worker
bin/jobs

# View job queue status
bin/rails solid_queue:status

# Clear jobs
bin/rails solid_queue:clear
```

## Assets

```bash
# Build JavaScript
npm run build

# Build CSS
npm run build:css

# Build both
npm run build && npm run build:css

# Clean build artifacts
rm -rf app/assets/builds/*
```

## Credentials

```bash
# Edit credentials
bin/rails credentials:edit

# Edit credentials for specific environment
bin/rails credentials:edit --environment production

# Show credentials
bin/rails credentials:show
```

## Logs

```bash
# Tail development log
tail -f log/development.log

# Clear logs
bin/rails log:clear

# View Solid Queue logs
tail -f log/solid_queue.log
```

## Cleanup

```bash
# Clear temporary files
bin/rails tmp:clear

# Clear logs
bin/rails log:clear

# Clear cache
bin/rails cache:clear

# Deep clean (removes node_modules, clears caches)
rm -rf node_modules
npm install
bin/rails tmp:clear
```

## Git

```bash
# Create feature branch
git checkout -b feature/my-feature

# Stage changes
git add .

# Commit with message
git commit -m "Add feature description"

# Push to remote
git push origin feature/my-feature

# Rebase on main
git fetch origin
git rebase origin/main
```

## Debugging

```bash
# Start Rails server with debugger
bin/rails server

# In code, add breakpoint
debugger

# Or use binding
binding.break
```

## CI/CD

```bash
# Run full CI suite locally
bin/lint && bin/test

# Run security checks
bin/brakeman --no-pager && bin/bundler-audit
```

## Docker (if using)

```bash
# Build Docker image
docker build -t synorg .

# Run container
docker run -p 3000:3000 synorg

# View logs
docker logs <container-id>
```

## Deployment

```bash
# Deploy with Kamal (if configured)
bin/kamal deploy

# Check deployment status
bin/kamal app logs
```

## Helpful Aliases

Add to your shell config (`.bashrc`, `.zshrc`):

```bash
# Rails shortcuts
alias rc='bin/rails console'
alias rs='bin/rails server'
alias rsp='bin/rails spec'
alias rgm='bin/rails generate migration'

# Git shortcuts
alias gs='git status'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
```

## Environment Variables

```bash
# Set environment variable for one command
RAILS_ENV=test bin/rails db:migrate

# Export for session
export DATABASE_URL=postgres://localhost/synorg_development

# Load from .env file (using dotenv)
# Create .env file and add variables, then:
bin/rails console  # automatically loads .env
```

## Performance

```bash
# Profile memory usage
bundle exec derailed bundle:mem

# Profile boot time
bundle exec derailed bundle:objects

# Check N+1 queries (with Bullet in development)
# Visit page, check logs for Bullet warnings
```

## Tips

- Use `bin/` prefix for all Rails commands to ensure correct version
- Run `bin/setup` after pulling main to ensure dependencies are up to date
- Use `bin/dev` instead of `bin/rails server` to run all services
- Check CI before pushing with `bin/lint && bin/test`
- Keep dependencies updated regularly
- Use feature branches for all changes
- Write tests for new features
- Run security scans before deploying
