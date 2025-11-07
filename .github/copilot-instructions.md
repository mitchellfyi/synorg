# GitHub Copilot Custom Instructions

## Repository Context

This is **Synorg**, a Rails edge application with PostgreSQL, Solid Queue, Tailwind CSS, and esbuild.

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
