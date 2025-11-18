# Deployment Guide

This guide explains how to deploy Synorg to production using Kamal and GitHub Actions.

## Overview

Synorg uses [Kamal](https://kamal-deploy.org) for deployment, which packages the application as a Docker container and deploys it to any server with SSH access. The deployment process is automated via GitHub Actions and can also be run manually from your local machine.

## Architecture

- **Container Registry**: GitHub Container Registry (ghcr.io)
- **Deployment Tool**: Kamal
- **Target Platform**: Any Linux server with Docker (DigitalOcean, AWS, etc.)
- **CI/CD**: GitHub Actions

## Prerequisites

### For Automated Deployment (GitHub Actions)

1. A server with:
   - Ubuntu 22.04 or later
   - Docker installed
   - SSH access configured
   - At least 2GB RAM (4GB recommended)

2. GitHub repository secrets configured (see [Secrets Management](#secrets-management))

3. Domain name (optional, for SSL via Let's Encrypt)

### For Manual Deployment (Local)

1. All of the above, plus:
   - Ruby 3.4.2 installed locally
   - Kamal gem installed: `gem install kamal`
   - SSH key with access to the deployment server

## Server Setup

### 1. Provision a Server

#### Using DigitalOcean

Create a droplet with the following specifications:

- **OS**: Ubuntu 22.04 LTS
- **Plan**: Basic ($12/month or higher recommended)
- **RAM**: 2GB minimum (4GB recommended)
- **SSH Keys**: Add your SSH public key

```bash
# Using doctl (DigitalOcean CLI)
doctl compute droplet create synorg-production \
  --image ubuntu-22-04-x64 \
  --size s-2vcpu-4gb \
  --region nyc3 \
  --ssh-keys YOUR_SSH_KEY_FINGERPRINT
```

#### Using Other Providers

Kamal works with any server that has:
- SSH access
- Docker installed
- Public IP address

### 2. Install Docker on the Server

SSH into your server and run:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Add your user to the docker group (optional, for running without sudo)
sudo usermod -aG docker $USER

# Verify installation
docker --version
```

### 3. Configure SSH Access

Ensure you can SSH into your server without a password:

```bash
# Test SSH connection
ssh root@YOUR_SERVER_IP

# If using a non-root user, ensure they have sudo access
# and can run docker commands
```

## Configuration

### 1. Update config/deploy.yml

Edit `config/deploy.yml` and replace placeholder values:

```yaml
servers:
  web:
    - YOUR_SERVER_IP  # Replace with your actual server IP
```

For multiple environments (staging/production), you can create:
- `config/deploy.production.yml`
- `config/deploy.staging.yml`

And deploy with: `kamal deploy -d production`

### 2. Configure Environment Variables

Required environment variables are defined in `config/deploy.yml` under the `env` section:

- **RAILS_MASTER_KEY**: Rails credentials encryption key
- **DATABASE_URL**: PostgreSQL connection string

Optional variables:
- **JOB_CONCURRENCY**: Number of Solid Queue workers
- **WEB_CONCURRENCY**: Number of Puma workers
- **RAILS_LOG_LEVEL**: Logging level (debug, info, warn, error)

### 3. Database Setup

You have two options for the database:

#### Option A: External Database (Recommended)

Use a managed PostgreSQL service (DigitalOcean Managed Database, AWS RDS, etc.):

```yaml
# config/deploy.yml
env:
  secret:
    - DATABASE_URL  # Set in .kamal/secrets
```

Set `DATABASE_URL` in your environment:
```bash
export DATABASE_URL="postgresql://user:password@host:port/database_name"
```

#### Option B: Dockerized Database (Accessory)

Use Kamal accessories to run PostgreSQL in a container:

```yaml
# config/deploy.yml
accessories:
  db:
    image: postgres:16
    host: YOUR_SERVER_IP
    port: "127.0.0.1:5432:5432"
    env:
      clear:
        POSTGRES_USER: synorg
        POSTGRES_DB: synorg_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
```

Then deploy the accessory:
```bash
kamal accessory boot db
```

## Secrets Management

See [docs/ops/secrets.md](./secrets.md) for detailed information on managing secrets.

### Required Secrets

1. **RAILS_MASTER_KEY**: Encryption key for Rails credentials
   - Location: `config/master.key` (never commit this!)
   - GitHub Secret: `RAILS_MASTER_KEY`

2. **DATABASE_URL**: PostgreSQL connection string
   - Format: `postgresql://user:password@host:port/database`
   - GitHub Secret: `DATABASE_URL`

3. **KAMAL_REGISTRY_PASSWORD**: Container registry authentication
   - For GitHub Container Registry: Use `GITHUB_TOKEN` (automatically provided)
   - GitHub Secret: Automatically available as `secrets.GITHUB_TOKEN`

4. **SSH_PRIVATE_KEY**: SSH key for server access (GitHub Actions only)
   - Your private SSH key with access to the deployment server
   - GitHub Secret: `SSH_PRIVATE_KEY`

5. **DEPLOY_HOST**: Server hostname or IP (GitHub Actions only)
   - Your server's IP address or hostname
   - GitHub Secret: `DEPLOY_HOST`

6. **DIGITALOCEAN_ACCESS_TOKEN**: DigitalOcean API token (optional)
   - Only needed if using DigitalOcean API features
   - GitHub Secret: `DIGITALOCEAN_ACCESS_TOKEN`

### Setting GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each required secret:
   - Name: `RAILS_MASTER_KEY`
   - Value: Contents of `config/master.key`
   - Click **Add secret**

Repeat for all required secrets.

### Local Secrets (.kamal/secrets)

For local deployments, secrets are sourced from `.kamal/secrets`:

```bash
# .kamal/secrets (example - customize for your setup)

# For local deployment: read from config/master.key
RAILS_MASTER_KEY=$(cat config/master.key)

# For local deployment: set your database URL
DATABASE_URL=postgresql://user:password@host:port/database_name

# For registry authentication (if not using GitHub Actions)
KAMAL_REGISTRY_PASSWORD=your_github_token_here
```

**Never commit** `.kamal/secrets` with real credentials!

## Deployment Workflows

### Automated Deployment (GitHub Actions)

The `.github/workflows/deploy.yml` workflow automatically deploys when you push to `main`:

1. Builds the Docker image
2. Pushes to GitHub Container Registry
3. Deploys to the configured servers using Kamal

**Workflow Steps:**
1. Build and push Docker image to `ghcr.io/mitchellfyi/synorg`
2. Set up SSH access to the deployment server
3. Run `kamal deploy` with environment secrets

**To trigger a deployment:**
```bash
git push origin main
```

**To manually trigger:**
1. Go to **Actions** → **Deploy** workflow
2. Click **Run workflow**
3. Select branch and click **Run workflow**

### Manual Deployment (Local)

#### First-Time Setup

1. Install Kamal:
   ```bash
   gem install kamal
   ```

2. Set up your secrets in `.kamal/secrets`

3. Initialize the servers:
   ```bash
   kamal setup
   ```

This will:
- Install Docker (if needed)
- Set up the Docker network
- Configure environment variables
- Start accessories (if any)

#### Deploying Updates

```bash
# Deploy the application
kamal deploy

# Deploy to a specific environment
kamal deploy -d production

# View deployment logs
kamal logs -f
```

#### Common Kamal Commands

```bash
# Check app status
kamal app details

# Access Rails console
kamal app exec --interactive --reuse "bin/rails console"

# Access server shell
kamal app exec --interactive --reuse "bash"

# View logs
kamal logs -f
kamal logs --since 1h

# Restart the app
kamal app restart

# Roll back to previous version
kamal rollback

# Update environment variables (without full redeploy)
kamal env push

# Stop the app
kamal app stop

# Remove all containers and data (destructive!)
kamal remove
```

## CI/CD Pipeline

### CI Workflow (.github/workflows/ci.yml)

Runs on every pull request (except drafts):

1. **Linting**
   - RuboCop (Ruby)
   - ERB Lint (templates)
   - ESLint (JavaScript)
   - Prettier (formatting)
   - TypeScript type checking

2. **Security Scans**
   - Brakeman (static analysis)
   - bundler-audit (dependency vulnerabilities)

3. **Tests**
   - RSpec test suite with PostgreSQL database
   - JavaScript asset builds

4. **Playwright Smoke Tests**
   - End-to-end browser tests (if configured)

### Deploy Workflow (.github/workflows/deploy.yml)

Runs on push to `main`:

1. **Build**
   - Build Docker image with all dependencies
   - Tag with commit SHA and `latest`
   - Push to GitHub Container Registry

2. **Deploy**
   - Set up SSH access
   - Run Kamal deployment
   - Health check and rollback on failure

## SSL/TLS Configuration

To enable HTTPS with Let's Encrypt:

```yaml
# config/deploy.yml
proxy:
  ssl: true
  host: synorg.example.com
```

Then update your Rails configuration:

```ruby
# config/environments/production.rb
config.assume_ssl = true
config.force_ssl = true
```

**Requirements:**
- Domain name pointed to your server's IP
- Port 80 and 443 open on the server
- Valid email for Let's Encrypt registration

## Monitoring and Debugging

### View Application Logs

```bash
# Follow logs in real-time
kamal logs -f

# View specific number of lines
kamal logs --lines 100

# View logs from specific time period
kamal logs --since 1h
kamal logs --since "2024-01-01 10:00:00"
```

### Access Rails Console

```bash
kamal app exec --interactive --reuse "bin/rails console"
```

### SSH into the Server

```bash
ssh root@YOUR_SERVER_IP
```

### Check Docker Containers

```bash
# SSH into server first
ssh root@YOUR_SERVER_IP

# List running containers
docker ps

# View logs for a specific container
docker logs synorg-web-1

# Inspect container
docker inspect synorg-web-1
```

### Health Checks

Kamal automatically performs health checks on the deployed containers. If a deployment fails health checks, it will automatically roll back.

Health check configuration:

```yaml
# config/deploy.yml
healthcheck:
  path: /up
  port: 3000
  max_attempts: 7
  interval: 20s
```

## Troubleshooting

### Deployment Fails

1. **Check Kamal version**: Ensure you're using a recent version
   ```bash
   kamal version
   gem update kamal
   ```

2. **Verify secrets**: Ensure all required secrets are set
   ```bash
   kamal env print
   ```

3. **Check Docker on server**: SSH in and verify Docker is running
   ```bash
   ssh root@YOUR_SERVER_IP
   docker ps
   ```

4. **Review logs**: Check deployment logs for errors
   ```bash
   kamal logs --since 30m
   ```

### Container Won't Start

1. **Check image build**: Ensure the image builds locally
   ```bash
   docker build -t synorg .
   docker run -it synorg
   ```

2. **Verify environment variables**: Ensure all required ENV vars are set
   ```bash
   kamal env print
   ```

3. **Check database connectivity**: Ensure `DATABASE_URL` is correct and accessible

### Database Migration Issues

Run migrations manually:

```bash
kamal app exec "bin/rails db:migrate"
```

### Performance Issues

1. **Increase server resources**: Upgrade to a larger droplet
2. **Adjust worker counts**: Update `WEB_CONCURRENCY` and `JOB_CONCURRENCY`
3. **Monitor resources**: Check RAM/CPU usage
   ```bash
   ssh root@YOUR_SERVER_IP
   htop
   docker stats
   ```

### SSL Certificate Issues

1. **Verify DNS**: Ensure your domain points to the server IP
   ```bash
   dig synorg.example.com
   ```

2. **Check ports**: Ensure 80 and 443 are open
   ```bash
   sudo ufw status
   ```

3. **Review Traefik logs**: Kamal uses Traefik for SSL termination
   ```bash
   docker logs synorg-traefik
   ```

## Best Practices

1. **Always test in staging first**: Use separate environments for testing
2. **Keep secrets secure**: Never commit secrets to git
3. **Monitor deployments**: Watch logs during deployment
4. **Backup database**: Regular backups before major deployments
5. **Use feature flags**: For gradual rollouts and easy rollbacks
6. **Document changes**: Update this guide when changing deployment process
7. **Review resource usage**: Monitor and adjust server resources as needed

## Rolling Back

If a deployment goes wrong:

```bash
# Automatic rollback (if health checks fail)
# Kamal does this automatically

# Manual rollback to previous version
kamal rollback

# Or deploy a specific version
kamal deploy --version=<previous-version>
```

## Scaling

### Horizontal Scaling (Multiple Servers)

Add more servers to `config/deploy.yml`:

```yaml
servers:
  web:
    - 192.168.0.1
    - 192.168.0.2
    - 192.168.0.3
```

### Dedicated Job Workers

Split background jobs to dedicated servers:

```yaml
servers:
  web:
    - 192.168.0.1
    - 192.168.0.2
  job:
    hosts:
      - 192.168.0.3
    cmd: bin/jobs
```

## Additional Resources

- [Kamal Documentation](https://kamal-deploy.org)
- [Docker Documentation](https://docs.docker.com)
- [GitHub Actions Documentation](https://docs.github.com/actions)
- [DigitalOcean Tutorials](https://www.digitalocean.com/community/tutorials)
- [Rails Deployment Guide](https://guides.rubyonrails.org/deployment.html)

## Support

For deployment issues:
1. Check this documentation
2. Review Kamal documentation
3. Check application logs
4. Open an issue in the repository
