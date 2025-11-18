# Personal Access Token (PAT) Security

This document covers the secure handling of GitHub Personal Access Tokens (PATs) in Synorg, including creation, storage, rotation, and best practices for minimal privilege access.

## Overview

Synorg uses GitHub Personal Access Tokens to interact with GitHub repositories on behalf of users. These tokens provide programmatic access to:

- Clone repositories
- Push commits and branches
- Create and update pull requests
- Update issue status and labels
- Read repository metadata

**Critical**: PATs are sensitive credentials that must be protected with the same care as passwords.

## Token Storage Philosophy

### What We DO NOT Do

❌ **Store PATs in the database**
- PATs are never stored in the `projects` or `integrations` tables
- Even encrypted tokens in the database are vulnerable to SQL injection, backups, and insider threats

❌ **Commit PATs to version control**
- Never include tokens in code, configuration files, or environment files committed to Git

❌ **Log PATs**
- Tokens are filtered from application logs and audit logs

### What We DO

✅ **Store only references to secrets**
- The database stores the **name** of the GitHub Secret or environment variable
- Example: `github_pat_secret_name: "SYNORG_GITHUB_PAT"`

✅ **Retrieve tokens at runtime**
- Load tokens from GitHub Secrets or Doppler when needed
- Tokens are never persisted in application memory longer than necessary

✅ **Use minimal scopes**
- Only request the minimum permissions required for operation

## Creating a Personal Access Token

### Required Scopes

Synorg requires the following **minimal scopes** for PATs:

| Scope | Permission | Purpose |
|-------|-----------|---------|
| `contents:read` | Read-only | Clone repositories, read files |
| `contents:write` | Read/Write | Push commits, create branches |
| `pull_requests:write` | Read/Write | Create and update pull requests |
| `issues:write` | Read/Write | Update issue status, add labels |
| `metadata:read` | Read-only | Read repository metadata (automatic) |

**Note**: The `metadata:read` scope is automatically included with any repository scope.

### Classic PAT Creation

For GitHub.com accounts:

1. Navigate to **Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. Set **Note** to something descriptive: `Synorg - <project-name>`
4. Set **Expiration** to 90 days (recommended) or less
5. Select scopes:
   - `repo` (for private repositories) or `public_repo` (for public only)
   - `workflow` (if you need to trigger GitHub Actions)
6. Click **Generate token**
7. **Copy the token immediately** - you won't be able to see it again

### Fine-Grained PAT Creation (Recommended)

Fine-grained tokens provide better security through repository-specific permissions:

1. Navigate to **Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Click **Generate new token**
3. Set **Token name**: `Synorg - <project-name>`
4. Set **Expiration**: 90 days (recommended)
5. Set **Repository access**:
   - Select **Only select repositories**
   - Choose the specific repository for this project
6. Set **Repository permissions**:
   - **Contents**: Read and write
   - **Issues**: Read and write
   - **Pull requests**: Read and write
   - **Metadata**: Read-only (automatic)
7. Click **Generate token**
8. **Copy the token immediately**

### Token Format

GitHub PATs follow specific formats:

- **Classic**: `ghp_` followed by 36 characters
- **Fine-grained**: `github_pat_` followed by 22 characters, underscore, then 59 characters

Example:
```
ghp_abcdefghijklmnopqrstuvwxyz123456
github_pat_1234567890ABCDEFGH_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ
```

## Storing Tokens Securely

### Using GitHub Secrets (Recommended)

GitHub Actions and Dependabot can access encrypted secrets:

1. Navigate to your **Synorg repository** (not the target repo)
2. Go to **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Name: `SYNORG_GITHUB_PAT` (or project-specific name)
5. Value: Paste the PAT
6. Click **Add secret**

In your Synorg project configuration:

```ruby
# Store only the secret name, not the token itself
project.update(github_pat_secret_name: "SYNORG_GITHUB_PAT")

# At runtime, load from environment
token = ENV["SYNORG_GITHUB_PAT"]
```

### Using Doppler (Alternative)

For cloud deployments, use [Doppler](https://www.doppler.com/) or similar secret management:

1. Add secret to Doppler: `SYNORG_GITHUB_PAT`
2. Configure Doppler to inject secrets at runtime
3. Reference the secret name in Synorg configuration

### Using Rails Credentials (Development)

For development/testing only:

```bash
# Edit credentials
EDITOR=nano bin/rails credentials:edit

# Add your token
github_pat: ghp_yourtoken123456

# In code
token = Rails.application.credentials.github_pat
```

**Warning**: Do not use Rails credentials in production. Use GitHub Secrets or a dedicated secret manager.

## Using Tokens in Code

### Loading Tokens

```ruby
# app/services/github_service.rb
class GithubService
  def initialize(project)
    @project = project
    @token = load_token
  end

  private

  def load_token
    # Load token from environment using the stored secret name
    secret_name = @project.github_pat_secret_name
    return nil unless secret_name

    token = ENV[secret_name]
    
    # Validate token format
    unless valid_token_format?(token)
      Rails.logger.error("Invalid GitHub token format for #{secret_name}")
      return nil
    end

    token
  end

  def valid_token_format?(token)
    return false if token.blank?
    
    # Check for valid GitHub token patterns
    token.match?(/^ghp_[A-Za-z0-9]{36}$/) ||
      token.match?(/^github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}$/)
  end
end
```

### Token Sanitization

Always sanitize tokens from logs and audit trails:

```ruby
# app/models/audit_log.rb
def sanitized_payload_excerpt
  return nil if payload_excerpt.blank?

  sanitized = payload_excerpt.dup
  # Remove GitHub PAT patterns
  sanitized.gsub!(/ghp_[A-Za-z0-9]{36}/i, "***REDACTED***")
  sanitized.gsub!(/github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}/i, "***REDACTED***")
  sanitized
end
```

## Token Rotation

### When to Rotate

Rotate tokens immediately if:

- ✋ Token is committed to version control (public or private)
- ✋ Token appears in logs or error messages
- ✋ Suspicious activity detected on the account
- ✋ Team member with token access leaves
- ✋ Token is more than 90 days old

Rotate proactively:

- 📅 Every 90 days (recommended)
- 📅 Every 30 days for high-security environments

### Rotation Process

#### 1. Generate New Token

Follow the [creation steps](#creating-a-personal-access-token) to generate a new token with the same scopes.

#### 2. Update Secret Storage

**GitHub Secrets**:
1. Navigate to repository **Settings → Secrets → Actions**
2. Click the secret name (e.g., `SYNORG_GITHUB_PAT`)
3. Click **Update secret**
4. Paste the new token
5. Click **Update secret**

**Doppler**:
1. Log into Doppler dashboard
2. Navigate to your project
3. Update the secret value
4. Doppler will automatically sync to running instances

#### 3. Verify New Token

Test the new token before revoking the old one:

```bash
# Test GitHub API access
curl -H "Authorization: Bearer YOUR_NEW_TOKEN" \
  https://api.github.com/user

# Expected response: 200 OK with user details
```

#### 4. Graceful Deployment

For zero-downtime rotation:

1. Add new token as `SYNORG_GITHUB_PAT_NEW`
2. Update code to try new token, fallback to old
3. Deploy changes
4. Wait for all instances to update
5. Update `SYNORG_GITHUB_PAT` to new value
6. Remove `SYNORG_GITHUB_PAT_NEW`
7. Revoke old token

#### 5. Revoke Old Token

**Important**: Only revoke after verifying the new token works.

1. Navigate to **Settings → Developer settings → Personal access tokens**
2. Find the old token
3. Click **Revoke** or **Delete**
4. Confirm revocation

### Emergency Rotation

If a token is compromised:

1. **Immediately revoke** the compromised token
2. Generate a new token with different scopes (if compromise suggests over-privileged)
3. Update all secret storage locations
4. Review audit logs for unauthorized usage
5. Rotate any other credentials that may have been exposed
6. Consider rotating repository webhook secrets as well

## Incident Response

### Token Leakage Detection

GitHub automatically scans for leaked tokens:

- Public commits
- Public gists
- Public issues/comments

If GitHub detects a leaked token, they will:
1. Send you an email notification
2. Automatically revoke the token
3. Display a warning in your account

**Your action**: Follow the [emergency rotation](#emergency-rotation) process.

### Manual Detection

Check for accidentally committed tokens:

```bash
# Search git history for token patterns
git log -p | grep -E "ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}"

# Search current codebase
grep -r "ghp_" .
grep -r "github_pat_" .
```

If found:
1. Revoke the token immediately
2. Remove from git history using `git filter-branch` or BFG Repo-Cleaner
3. Force push cleaned history (if safe to do so)
4. Notify team members to re-clone

### Audit Log Review

Check for suspicious token usage:

```ruby
# Recent GitHub API activity
AuditLog.where(event_type: "github.api_call")
  .where("created_at > ?", 24.hours.ago)
  .order(created_at: :desc)

# Failed authentication attempts
AuditLog.where(event_type: "github.auth_failed")
  .where("created_at > ?", 7.days.ago)
```

Review GitHub's audit log:
1. Navigate to **Settings → Security → Audit log**
2. Filter by token name or IP address
3. Look for unexpected API calls

## Best Practices

### Scope Minimization

✅ **Do**:
- Use fine-grained tokens over classic tokens
- Request only the scopes you need
- Use different tokens for different purposes
- Scope tokens to specific repositories when possible

❌ **Don't**:
- Request `admin:org` unless absolutely necessary
- Use tokens with `delete_repo` scope
- Share tokens across multiple projects
- Grant broader access than required

### Token Lifecycle

✅ **Do**:
- Set expiration dates (90 days or less)
- Document token purpose and owner
- Rotate tokens before expiration
- Test token rotation process regularly
- Monitor token usage via audit logs

❌ **Don't**:
- Create tokens without expiration
- Forget which tokens are in use
- Wait for tokens to expire
- Skip rotation testing

### Access Control

✅ **Do**:
- Use separate tokens for each environment (dev/staging/prod)
- Limit who can access secret storage
- Use role-based access control for secret management
- Enable multi-factor authentication on GitHub accounts

❌ **Don't**:
- Share tokens between developers
- Store tokens in shared drives or wikis
- Email or message tokens to teammates
- Reuse tokens across organizations

## Migration Guide

### Removing PATs from Database

If your project currently stores PATs directly:

1. **Export existing tokens** to secure storage:
   ```ruby
   Project.where.not(github_pat: nil).find_each do |project|
     secret_name = "GITHUB_PAT_#{project.slug.upcase}"
     
     # Store in GitHub Secrets or Doppler
     # Manually add to secret manager using the project.github_pat value
     
     # Update project to reference secret name
     project.update!(
       github_pat_secret_name: secret_name,
       github_pat: nil  # Clear the stored token
     )
   end
   ```

2. **Update code** to load from secrets:
   ```ruby
   # Before
   token = project.github_pat
   
   # After
   token = ENV[project.github_pat_secret_name]
   ```

3. **Deploy changes**

4. **Verify** all projects can access tokens

5. **Remove column** (optional):
   ```ruby
   # Migration
   remove_column :projects, :github_pat
   ```

## Troubleshooting

### Token Not Working

1. **Verify format**: Check token matches `ghp_*` or `github_pat_*` pattern
2. **Check scopes**: Ensure token has required permissions
3. **Test API**: Use curl to verify token works
4. **Check expiration**: Verify token hasn't expired
5. **Review logs**: Check for authentication errors

### Missing Token

1. **Verify secret name**: Check `github_pat_secret_name` is set correctly
2. **Check environment**: Ensure secret is available in runtime environment
3. **Review deployment**: Verify secrets are injected correctly

### Rate Limiting

GitHub enforces rate limits:

- **Authenticated requests**: 5,000 per hour
- **Unauthenticated requests**: 60 per hour

If you hit rate limits:
- Check for inefficient API usage
- Implement caching
- Use conditional requests (ETags)
- Consider GraphQL for batch operations

## References

- [GitHub Personal Access Tokens Documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [GitHub Token Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
- [GitHub API Authentication](https://docs.github.com/en/rest/authentication)
- [Fine-Grained PATs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning)
