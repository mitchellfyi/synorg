# Secrets Management

This document describes all environment secrets required for Synorg's CI/CD pipelines and deployment.

## Overview

Synorg uses environment secrets for:
- **CI/CD workflows** (GitHub Actions)
- **Production deployment** (Kamal)
- **Local development** (via `.kamal/secrets`)

**Critical**: Never commit secrets or credentials to git. Use environment variables, GitHub Secrets, or secure secret management tools.

## Required Secrets

### 1. RAILS_MASTER_KEY

**Purpose**: Encryption key for Rails credentials

**Format**: 32-character hexadecimal string

**Where it's used**:
- CI workflow (for running tests with encrypted credentials)
- Deploy workflow (for production deployment)
- Kamal deployment (passed to Docker containers)

**How to find it**:
```bash
cat config/master.key
```

**GitHub Secret Setup**:
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `RAILS_MASTER_KEY`
4. Value: Contents of `config/master.key`
5. Click **Add secret**

**Local Setup** (`.kamal/secrets`):
```bash
RAILS_MASTER_KEY=$(cat config/master.key)
```

**Security Notes**:
- Never commit `config/master.key` to git (already in `.gitignore`)
- Store securely in password manager (1Password, LastPass, etc.)
- Rotate periodically by generating new credentials

### 2. DATABASE_URL

**Purpose**: PostgreSQL database connection string

**Format**: `postgresql://user:password@host:port/database_name`

**Example**:
```
postgresql://synorg_user:secure_password@db.example.com:5432/synorg_production
```

**Where it's used**:
- CI workflow (uses ephemeral PostgreSQL service, auto-configured)
- Deploy workflow (for production database access)
- Kamal deployment (passed to Docker containers)

**GitHub Secret Setup**:
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `DATABASE_URL`
4. Value: Your production database connection string
5. Click **Add secret**

**Local Setup** (`.kamal/secrets`):
```bash
# For managed database (recommended)
DATABASE_URL=postgresql://user:password@host:port/database_name

# For local Kamal accessory
DATABASE_URL=postgresql://synorg:${POSTGRES_PASSWORD}@synorg-db:5432/synorg_production
```

**Security Notes**:
- Use strong, randomly generated passwords
- Restrict database access to deployment servers only
- Use SSL/TLS for database connections in production
- Consider using managed database services (DigitalOcean, AWS RDS)

### 3. KAMAL_REGISTRY_PASSWORD

**Purpose**: Authentication for container registry

**Format**: Personal access token or password

**Where it's used**:
- Deploy workflow (authenticates to GitHub Container Registry)
- Kamal deployment (pulls images from registry)

**For GitHub Container Registry**:
- In GitHub Actions: Use `secrets.GITHUB_TOKEN` (automatically provided)
- For local deployment: Generate a Personal Access Token (PAT)

**GitHub Secret Setup**:
Not needed for GitHub Actions (uses `GITHUB_TOKEN` automatically)

**Local Setup** (`.kamal/secrets`):
```bash
# For GitHub Container Registry
KAMAL_REGISTRY_PASSWORD=ghp_YourPersonalAccessToken

# For Docker Hub
KAMAL_REGISTRY_PASSWORD=your_docker_hub_password_or_token
```

**Creating a GitHub PAT** (for local deployments):
1. Go to GitHub **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token**
3. Name: "Kamal Deployment"
4. Expiration: 90 days (or as needed)
5. Select scopes:
   - `write:packages` (to push images)
   - `read:packages` (to pull images)
   - `delete:packages` (to clean up old images)
6. Click **Generate token**
7. Copy the token immediately (it won't be shown again)

**Security Notes**:
- Use tokens with minimal required permissions
- Set expiration dates on tokens
- Rotate tokens regularly
- Never commit tokens to git

### 4. SSH_PRIVATE_KEY

**Purpose**: SSH authentication for deployment servers

**Format**: RSA or Ed25519 private key

**Where it's used**:
- Deploy workflow (to SSH into deployment servers)

**GitHub Secret Setup**:
1. Generate an SSH key pair if you don't have one:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/deploy_key
   ```

2. Add the public key to your deployment server:
   ```bash
   ssh-copy-id -i ~/.ssh/deploy_key.pub root@YOUR_SERVER_IP
   ```

3. Add the private key to GitHub Secrets:
   - Go to repository **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `SSH_PRIVATE_KEY`
   - Value: Contents of `~/.ssh/deploy_key` (entire file, including headers)
   - Click **Add secret**

**Format**:
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
...
-----END OPENSSH PRIVATE KEY-----
```

**Local Setup**:
Not needed for local deployment (uses your existing SSH keys)

**Security Notes**:
- Use key-based authentication, not passwords
- Protect private keys with file permissions (600)
- Use separate keys for different purposes
- Consider using SSH agent forwarding for additional security
- Never commit private keys to git

### 5. DEPLOY_HOST

**Purpose**: IP address or hostname of deployment server

**Format**: IP address or fully qualified domain name

**Examples**:
- `192.168.1.100`
- `synorg.example.com`
- `deploy.synorg.io`

**Where it's used**:
- Deploy workflow (SSH target and known_hosts setup)

**GitHub Secret Setup**:
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `DEPLOY_HOST`
4. Value: Your server's IP or hostname
5. Click **Add secret**

**Local Setup**:
Not needed (configured in `config/deploy.yml`)

### 6. DIGITALOCEAN_ACCESS_TOKEN (Optional)

**Purpose**: DigitalOcean API authentication

**Format**: 64-character alphanumeric token

**Where it's used**:
- Optional: For programmatic infrastructure management
- Optional: For Dynamic DNS updates
- Optional: For automated server provisioning

**GitHub Secret Setup** (if needed):
1. Generate token in DigitalOcean:
   - Go to DigitalOcean **API** → **Tokens/Keys**
   - Click **Generate New Token**
   - Name: "Synorg Deployment"
   - Scopes: Read/Write
2. Add to GitHub Secrets:
   - Name: `DIGITALOCEAN_ACCESS_TOKEN`
   - Value: Your DO token

**Local Setup** (`.env` or shell):
```bash
export DIGITALOCEAN_ACCESS_TOKEN=dop_v1_your_token_here
```

**Security Notes**:
- Only needed if using DigitalOcean API features
- Can be omitted if managing infrastructure manually
- Restrict token permissions to only what's needed

## Secret References in Configuration

### CI Workflow (.github/workflows/ci.yml)

```yaml
env:
  RAILS_ENV: test
  DATABASE_URL: postgres://postgres:postgres@localhost:5432/synorg_test
  RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
```

### Deploy Workflow (.github/workflows/deploy.yml)

```yaml
env:
  RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
  KAMAL_REGISTRY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  DIGITALOCEAN_ACCESS_TOKEN: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}

steps:
  - name: Set up SSH
    run: |
      echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
      ssh-keyscan -H ${{ secrets.DEPLOY_HOST }} >> ~/.ssh/known_hosts
```

### Kamal Configuration (config/deploy.yml)

```yaml
registry:
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
```

### Local Secrets (.kamal/secrets)

```bash
#!/bin/bash

# Rails encryption key
RAILS_MASTER_KEY=$(cat config/master.key)

# Database connection
DATABASE_URL=postgresql://user:password@host:port/database_name

# Registry authentication
KAMAL_REGISTRY_PASSWORD=ghp_YourPersonalAccessToken
```

## Secret Management Best Practices

### Development

1. **Use `.env` files locally** (never commit them)
   ```bash
   # .env (add to .gitignore)
   RAILS_MASTER_KEY=abc123...
   DATABASE_URL=postgresql://...
   ```

2. **Use direnv for automatic loading**
   ```bash
   brew install direnv
   echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
   ```

3. **Use Rails credentials for sensitive config**
   ```bash
   rails credentials:edit
   ```

### Production

1. **Use environment variables** (never hardcode)
2. **Use GitHub Secrets** for CI/CD
3. **Use `.kamal/secrets`** for local deployments (never commit)
4. **Use password managers** (1Password, AWS Secrets Manager, etc.)

### Security Checklist

- [ ] All secrets are in `.gitignore`
- [ ] No secrets committed to git history
- [ ] GitHub Secrets configured for all required values
- [ ] SSH keys are properly secured (600 permissions)
- [ ] Database passwords are strong and unique
- [ ] Tokens have appropriate expiration dates
- [ ] Tokens have minimal required permissions
- [ ] Secrets are rotated periodically
- [ ] Access to secrets is logged and audited

## Rotating Secrets

### Rails Master Key

1. Generate new credentials:
   ```bash
   rails credentials:edit
   # Save and exit to generate new master key
   ```

2. Update GitHub Secret
3. Update `.kamal/secrets`
4. Redeploy application

### Database Password

1. Change password in database management console
2. Update `DATABASE_URL` in GitHub Secrets
3. Update `.kamal/secrets`
4. Redeploy application

### SSH Keys

1. Generate new key pair:
   ```bash
   ssh-keygen -t ed25519 -C "new-deploy-key"
   ```

2. Add new public key to servers
3. Update `SSH_PRIVATE_KEY` in GitHub Secrets
4. Remove old public key from servers

### Registry Tokens

1. Generate new token (GitHub PAT, Docker Hub, etc.)
2. Update `KAMAL_REGISTRY_PASSWORD` in GitHub Secrets (if needed)
3. Update `.kamal/secrets`
4. Revoke old token

## Troubleshooting

### "Missing secret" errors

**Symptom**: GitHub Actions fails with "missing secret" error

**Solution**:
1. Verify secret is set in GitHub repository settings
2. Check secret name matches exactly (case-sensitive)
3. Ensure secret has a value (not empty)

### Authentication failures

**Symptom**: Cannot push to registry or SSH to server

**Solution**:
1. Verify credentials are correct
2. Check token hasn't expired
3. Ensure token has required permissions
4. Test locally: `docker login ghcr.io`

### Database connection errors

**Symptom**: Application can't connect to database

**Solution**:
1. Verify `DATABASE_URL` format is correct
2. Check database server is accessible from deployment server
3. Verify username/password are correct
4. Check firewall rules allow connections
5. Test connection: `psql $DATABASE_URL`

### SSH errors in deployment

**Symptom**: "Permission denied" or "Host key verification failed"

**Solution**:
1. Verify SSH key is added to server's `authorized_keys`
2. Check key format in GitHub Secret (must include headers)
3. Verify `DEPLOY_HOST` is correct
4. Test SSH: `ssh -i ~/.ssh/deploy_key root@$DEPLOY_HOST`

## Emergency Procedures

### Compromised Secret

If a secret is compromised:

1. **Immediately rotate** the secret
2. **Revoke** old credentials
3. **Review logs** for unauthorized access
4. **Update** all affected systems
5. **Audit** access patterns
6. **Document** incident for future reference

### Lost Master Key

If you lose the Rails master key:

1. Generate new credentials:
   ```bash
   rm config/credentials.yml.enc config/master.key
   rails credentials:edit
   ```

2. Re-add all configuration values
3. Update GitHub Secrets
4. Redeploy application

## Additional Resources

- [GitHub Encrypted Secrets](https://docs.github.com/actions/security-guides/encrypted-secrets)
- [Kamal Secrets Management](https://kamal-deploy.org/docs/configuration/secrets/)
- [Rails Credentials](https://guides.rubyonrails.org/security.html#custom-credentials)
- [1Password for Teams](https://1password.com/teams/)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)
