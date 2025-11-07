# AI Agent Roles & Conventions

This document defines the roles, specializations, and conventions for AI agents working on the Synorg codebase.

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

## Getting Help

If you're stuck or uncertain:
1. Check the documentation in `/docs`
2. Review this AGENTS.md file
3. Check GitHub Copilot custom instructions in `.github/copilot-instructions.md`
4. Ask for clarification in the issue or PR
5. Consult upstream documentation for the relevant tool or framework
