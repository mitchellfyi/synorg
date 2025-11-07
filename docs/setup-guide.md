# Setup Guide

This guide covers the initial setup of the Synorg application.

## Prerequisites

Before running `bin/setup`, ensure you have:

- Ruby 3.2.3 installed (see `.ruby-version`)
- Node.js 20.x installed (see `.node-version`)
- PostgreSQL 16+ installed and running
- Bundler 2.7+ installed

### Installing Prerequisites

#### macOS (using Homebrew)

```bash
# Install Ruby (using rbenv recommended)
brew install rbenv
rbenv install 3.2.3

# Install Node.js
brew install node@20

# Install PostgreSQL
brew install postgresql@16
brew services start postgresql@16
```

#### Ubuntu/Debian

```bash
# Install Ruby (using rbenv recommended)
sudo apt-get update
sudo apt-get install -y rbenv
rbenv install 3.2.3

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt-get install -y postgresql-16
sudo systemctl start postgresql
```

## Running Setup

The `bin/setup` script is idempotent and safe to run multiple times:

```bash
bin/setup
```

### What `bin/setup` Does

1. Installs Ruby gem dependencies via Bundler
2. Installs JavaScript dependencies via npm
3. Creates development and test databases
4. Loads database schema
5. Runs database migrations
6. Prepares test database

### Troubleshooting Setup

#### PostgreSQL Connection Issues

If you get database connection errors:

1. Ensure PostgreSQL is running:
   ```bash
   # macOS (Homebrew)
   brew services list
   brew services start postgresql@16

   # Linux
   sudo systemctl status postgresql
   sudo systemctl start postgresql
   ```

2. Create a PostgreSQL user if needed:
   ```bash
   createuser -s postgres
   ```

3. Check database configuration in `config/database.yml`

#### Bundler Issues

If gems fail to install:

```bash
# Update Bundler
gem install bundler

# Clear bundle cache
bundle clean --force

# Retry
bundle install
```

#### Node/npm Issues

If JavaScript dependencies fail:

```bash
# Clear npm cache
npm cache clean --force

# Remove node_modules
rm -rf node_modules package-lock.json

# Retry
npm install
```

## Post-Setup Verification

After setup completes, verify everything works:

```bash
# Run tests
bin/test

# Run linters
bin/lint

# Start development server
bin/dev
```

Visit http://localhost:3000 to see the app running.

## Configuration

### Environment Variables

Create a `.env` file (not committed) for local configuration:

```bash
# Database (optional, defaults to config/database.yml)
DATABASE_URL=postgres://localhost/synorg_development

# Rails
RAILS_ENV=development
```

### Rails Credentials

Rails master key is in `config/master.key` (never commit this).

To edit credentials:

```bash
bin/rails credentials:edit
```

## Next Steps

- Read the [README](../README.md) for common commands
- Check [AGENTS.md](../AGENTS.md) for development conventions
- Review the [Ruby Upgrade Guide](ruby-upgrade-guide.md) if you need to update Ruby

## Getting Help

If setup fails:

1. Check error messages carefully
2. Ensure all prerequisites are installed
3. Try the troubleshooting steps above
4. Check GitHub issues for similar problems
5. Create a new issue with full error details
