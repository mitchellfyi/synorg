# Ruby Version Upgrade Guide

## Current Version

Ruby 3.2.3 (see `.ruby-version`)

## Upgrading Ruby

### Prerequisites

1. Check Rails compatibility with the new Ruby version
2. Check gem compatibility in Gemfile.lock
3. Review Ruby changelog for breaking changes

### Steps

1. **Update `.ruby-version`**

   ```bash
   echo "3.3.0" > .ruby-version  # Example for Ruby 3.3.0
   ```

2. **Install the new Ruby version**

   Using rbenv:
   ```bash
   rbenv install 3.3.0
   rbenv local 3.3.0
   ```

   Using rvm:
   ```bash
   rvm install 3.3.0
   rvm use 3.3.0
   ```

3. **Update Bundler**

   ```bash
   gem install bundler
   ```

4. **Reinstall gems**

   ```bash
   bundle install
   ```

5. **Update RuboCop target version**

   Edit `.rubocop.yml`:
   ```yaml
   AllCops:
     TargetRubyVersion: 3.3
   ```

6. **Run tests**

   ```bash
   bin/test
   ```

7. **Run linters**

   ```bash
   bin/lint
   ```

8. **Update CI**

   The CI uses `ruby/setup-ruby@v1` which reads from `.ruby-version`, so no changes needed.

9. **Update documentation**

   - Update this file with the new version
   - Update README.md
   - Update any other docs mentioning the Ruby version

### Testing

Test thoroughly in development before deploying:

1. Run full test suite
2. Test background jobs
3. Test asset compilation
4. Check for deprecation warnings in logs
5. Test in production-like environment

### Rollback

If issues arise:

1. Revert `.ruby-version` to previous version
2. Run `bundle install` to restore gems
3. Revert `.rubocop.yml` changes
4. File an issue with details of the problem

## Resources

- Ruby changelog: https://www.ruby-lang.org/en/news/
- Rails compatibility: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html
- Ruby version support: https://www.ruby-lang.org/en/downloads/releases/
