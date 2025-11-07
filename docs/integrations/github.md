# GitHub Integration

This guide explains how to integrate Synorg with GitHub using webhooks and Personal Access Tokens (PATs).

## Overview

Synorg integrates with GitHub to:
- Receive webhook events for issues, pull requests, workflow runs, and check suites
- Process these events to update work items and runs automatically
- Use GitHub API to interact with repositories using fine-grained Personal Access Tokens

## Prerequisites

- A GitHub repository
- Admin access to the repository settings
- A Synorg project configured with the repository

## Setting Up Webhooks

### Step 1: Generate a Webhook Secret

Generate a strong, random secret for webhook signature verification:

```bash
ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'
```

Save this secret securely - you'll need it in the next steps.

### Step 2: Add Webhook Secret to Repository Secrets

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `SYNORG_WEBHOOK_SECRET` (or your preferred name)
5. Value: Paste the secret you generated in Step 1
6. Click **Add secret**

### Step 3: Configure Webhook in GitHub

1. Navigate to your GitHub repository
2. Go to **Settings** → **Webhooks**
3. Click **Add webhook**
4. Configure the webhook:
   - **Payload URL**: `https://your-synorg-instance.com/github/webhook`
   - **Content type**: `application/json`
   - **Secret**: Paste the same secret from Step 1
   - **Which events would you like to trigger this webhook?**: Select **Let me select individual events**
     - Check: `Issues`
     - Check: `Pull requests`
     - Check: `Pushes`
     - Check: `Workflow runs`
     - Check: `Check suites`
   - **Active**: Ensure this is checked
5. Click **Add webhook**

### Step 4: Configure Synorg Project

In your Synorg project settings, configure:

1. **Webhook Secret Name**: The name of the repository secret containing your webhook secret (e.g., `SYNORG_WEBHOOK_SECRET`)
2. **Repository Full Name**: The full name of your repository (e.g., `owner/repo`)

The webhook secret name tells Synorg where to find the actual secret value in your Rails credentials or environment variables.

## Setting Up Personal Access Token (PAT)

Synorg uses a fine-grained Personal Access Token to interact with GitHub's API.

### Step 1: Create a Fine-Grained PAT

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
2. Click **Generate new token**
3. Configure the token:
   - **Token name**: `Synorg API Access` (or your preferred name)
   - **Expiration**: Choose an appropriate expiration period
   - **Repository access**: Select **Only select repositories** and choose your repository
   - **Repository permissions**:
     - **Issues**: Read and write
     - **Pull requests**: Read and write
     - **Commit statuses**: Read and write
     - **Contents**: Read-only (for reading repository files)
     - **Metadata**: Read-only (automatically selected)
4. Click **Generate token**
5. **Important**: Copy the token immediately - you won't be able to see it again!

### Step 2: Add PAT to Repository Secrets

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `SYNORG_GITHUB_PAT` (or your preferred name)
5. Value: Paste the PAT you generated in Step 1
6. Click **Add secret**

### Step 3: Configure Synorg Project

In your Synorg project settings, configure:

1. **GitHub PAT Secret Name**: The name of the repository secret containing your PAT (e.g., `SYNORG_GITHUB_PAT`)

## How It Works

### Webhook Event Flow

1. An event occurs in your GitHub repository (e.g., an issue is opened)
2. GitHub sends a webhook payload to `https://your-synorg-instance.com/github/webhook`
3. Synorg verifies the webhook signature using the configured webhook secret
4. If valid, Synorg persists the event to the `webhook_events` table for debugging
5. Synorg processes the event based on its type:

#### Issues Events

- **opened**, **labeled**, **reopened**: Creates or updates a `work_item` with:
  - Issue number, title, body, labels, state, and URL
  - Status set to "pending" for open issues
- **closed**: Marks the corresponding `work_item` as completed

#### Pull Request Events

- **opened**: Creates a `run` record linked to the related `work_item` and `agent`
  - Looks for issue references in PR body (e.g., "Fixes #123")
- **closed**: Updates the `run` outcome:
  - "success" if merged
  - "failure" if closed without merging
  - Marks `work_item` as completed if merged

#### Push Events

- Currently logged for debugging
- Can be extended to trigger custom workflows

#### Workflow Run Events

- **completed**: Updates the related `run` with:
  - Outcome based on conclusion (success/failure)
  - Finished timestamp
  - Logs URL

#### Check Suite Events

- **completed**: Updates the related `run` with conclusion status

### API Access with PAT

Synorg uses the configured PAT to:
- Fetch issue details
- Create and update issue comments
- Fetch pull request information
- Access repository metadata

The PAT is accessed via the `github_pat_secret_name` configured in the project settings.

## Security Considerations

### Webhook Signature Verification

- All webhooks are verified using HMAC SHA-256 signatures
- Invalid signatures are rejected with a 401 Unauthorized response
- Webhook signature verification prevents unauthorized access

### Secret Storage

- **Never commit secrets to your repository**
- Secrets are stored in GitHub repository secrets
- Synorg only stores the _name_ of the secret, not the value
- Actual secret values are accessed from Rails credentials or environment variables

### PAT Permissions

- Use fine-grained PATs with minimum required permissions
- Limit PAT access to specific repositories
- Set appropriate expiration dates
- Rotate PATs regularly

### Best Practices

1. **Use unique secrets**: Generate a unique webhook secret for each project
2. **Rotate secrets**: Periodically rotate both webhook secrets and PATs
3. **Monitor webhook deliveries**: Check GitHub's webhook delivery logs for failures
4. **Audit access**: Regularly review PAT usage in GitHub settings
5. **Least privilege**: Only grant the minimum permissions required

## Troubleshooting

### Webhook Delivery Failures

1. Check GitHub's webhook delivery logs:
   - Go to **Settings** → **Webhooks** → Click on your webhook
   - View recent deliveries and their responses
2. Verify the payload URL is correct and accessible
3. Check Synorg logs for error messages
4. Ensure the webhook secret matches in all locations

### Signature Verification Failures

- Verify the webhook secret is correctly configured in:
  - GitHub webhook settings
  - GitHub repository secrets
  - Synorg project configuration
- Ensure the secret names match exactly

### API Authentication Failures

- Verify the PAT is still valid (not expired)
- Check that the PAT has the required permissions
- Ensure the PAT secret name matches in Synorg configuration
- Check Rails credentials or environment variables contain the PAT

### Missing Events

- Verify the webhook is configured to send the required event types
- Check that the webhook is marked as "Active"
- Review webhook delivery history in GitHub

## Environment Variables

Synorg can access secrets from environment variables or Rails credentials:

### Using Environment Variables

Set environment variables with your secret names:

```bash
export SYNORG_WEBHOOK_SECRET="your-webhook-secret-here"
export SYNORG_GITHUB_PAT="your-pat-here"
```

### Using Rails Credentials

Edit Rails credentials:

```bash
rails credentials:edit
```

Add your secrets:

```yaml
github:
  SYNORG_WEBHOOK_SECRET: your-webhook-secret-here
  SYNORG_GITHUB_PAT: your-pat-here
```

## API Reference

### Webhook Endpoint

**POST** `/github/webhook`

**Headers:**
- `X-GitHub-Event`: Event type (e.g., "issues", "pull_request")
- `X-Hub-Signature-256`: HMAC SHA-256 signature for verification
- `X-GitHub-Delivery`: Unique delivery ID

**Response Codes:**
- `202 Accepted`: Webhook received and queued for processing
- `400 Bad Request`: Invalid JSON payload
- `401 Unauthorized`: Signature verification failed
- `500 Internal Server Error`: Processing error

## Examples

### Example Webhook Payload (Issues Event)

```json
{
  "action": "opened",
  "issue": {
    "number": 123,
    "title": "Add webhook processing",
    "body": "Implement webhook handling for GitHub events",
    "state": "open",
    "labels": [
      {
        "name": "enhancement"
      }
    ],
    "html_url": "https://github.com/owner/repo/issues/123"
  }
}
```

### Example Webhook Payload (Pull Request Event)

```json
{
  "action": "opened",
  "pull_request": {
    "number": 45,
    "title": "Fix webhook processing",
    "body": "Fixes #123\n\nThis PR implements webhook handling",
    "state": "open",
    "merged": false,
    "html_url": "https://github.com/owner/repo/pull/45"
  }
}
```

## Additional Resources

- [GitHub Webhooks Documentation](https://docs.github.com/en/webhooks)
- [GitHub API Documentation](https://docs.github.com/en/rest)
- [Creating a Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [Securing Your Webhooks](https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries)
- [Fine-Grained Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)
