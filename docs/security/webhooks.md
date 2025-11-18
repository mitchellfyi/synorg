# GitHub Webhook Security

This document details the security measures implemented for GitHub webhooks in Synorg, including signature verification, rate limiting, and audit logging.

## Overview

Synorg receives webhook events from GitHub to orchestrate work items based on repository activity. These webhooks must be properly secured to prevent:

- Unauthorized webhook deliveries from malicious actors
- Replay attacks using captured webhook payloads
- Denial of service through webhook flooding
- Information disclosure through error messages

## Signature Verification

### How It Works

All incoming webhooks **must** include a valid `X-Hub-Signature-256` header containing an HMAC SHA-256 signature of the request body. The signature is computed using a webhook secret configured in both GitHub and Synorg.

```
X-Hub-Signature-256: sha256=<signature>
```

The signature verification process:

1. **Extract Signature**: Read the `X-Hub-Signature-256` header from the incoming request
2. **Compute Expected Signature**: Calculate HMAC SHA-256 of the raw request body using the configured webhook secret
3. **Secure Comparison**: Use constant-time comparison to prevent timing attacks
4. **Accept or Reject**: Accept the webhook only if signatures match exactly

### Implementation

The verification is handled by the `WebhookVerifier` service:

```ruby
WebhookVerifier.verify(payload, signature, secret)
```

See: `app/services/webhook_verifier.rb`

### Configuration

Configure the webhook secret in your GitHub repository:

1. Navigate to **Settings → Webhooks** in your repository
2. Click **Add webhook** or edit an existing webhook
3. Set **Payload URL** to: `https://your-synorg-instance.com/github/webhook`
4. Set **Content type** to: `application/json`
5. Generate a strong **Secret** (use a password manager or `openssl rand -hex 32`)
6. Store the same secret in your Synorg project's `webhook_secret` field

**Never commit webhook secrets to version control.**

### Response Codes

| Status Code | Reason | Audit Log Event |
|------------|--------|----------------|
| `202 Accepted` | Valid signature, event processed | `webhook.received` |
| `400 Bad Request` | Missing signature | `webhook.missing_signature` |
| `400 Bad Request` | Invalid signature | `webhook.invalid_signature` |
| `400 Bad Request` | Malformed JSON payload | N/A |
| `429 Too Many Requests` | Rate limit exceeded | `webhook.rate_limited` |

**Note**: We return `400 Bad Request` (not `401 Unauthorized`) for signature failures because this is a client error with the request format, not an authentication failure in the traditional HTTP sense.

## Rate Limiting

### Configuration

Synorg uses [Rack::Attack](https://github.com/rack/rack-attack) to implement rate limiting on webhook endpoints:

- **Limit**: 100 requests per minute per IP address
- **Scope**: Only webhook endpoints (`POST /github/webhook`)
- **Response**: HTTP 429 with retry information in headers

### Rate Limit Headers

When a request is rate limited, the response includes:

```
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1699564800
Content-Type: application/json

{
  "error": "Rate limit exceeded. Try again later."
}
```

### Audit Logging

All rate limit violations are logged to the `audit_logs` table with:

- Event type: `webhook.rate_limited`
- Status: `blocked`
- IP address
- Request ID
- Timestamp

### Customization

To adjust rate limits, edit `config/initializers/rack_attack.rb`:

```ruby
throttle("webhooks/ip", limit: 100, period: 1.minute) do |req|
  if req.path == "/github/webhook" && req.post?
    req.ip
  end
end
```

For production deployments with multiple instances, configure Redis as the cache store:

```ruby
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
```

## Expected Headers

Valid webhook requests must include:

| Header | Required | Description | Example |
|--------|----------|-------------|---------|
| `X-GitHub-Event` | Yes | Type of webhook event | `issues`, `pull_request`, `push` |
| `X-Hub-Signature-256` | Yes | HMAC SHA-256 signature | `sha256=abc123...` |
| `X-GitHub-Delivery` | Yes | Unique delivery ID | `12345-67890-abcdef` |
| `Content-Type` | Yes | Must be `application/json` | `application/json` |
| `User-Agent` | No | GitHub user agent | `GitHub-Hookshot/abc123` |

## Supported Events

Synorg processes the following webhook event types:

- `issues` - Issue opened, closed, labeled, etc.
- `pull_request` - PR opened, closed, merged, etc.
- `push` - Code pushed to repository
- `workflow_run` - GitHub Actions workflow completed
- `check_suite` - Check suite completed

Unsupported events are accepted (HTTP 202) but not processed.

## Payload Examples

### Valid Webhook Request

```http
POST /github/webhook HTTP/1.1
Host: synorg.example.com
Content-Type: application/json
X-GitHub-Event: issues
X-Hub-Signature-256: sha256=abc123def456...
X-GitHub-Delivery: 12345-67890-abcdef

{
  "action": "opened",
  "issue": {
    "number": 42,
    "title": "Example issue",
    "state": "open"
  },
  "repository": {
    "full_name": "owner/repo"
  }
}
```

**Response**: HTTP 202 Accepted

### Invalid Signature

```http
POST /github/webhook HTTP/1.1
Host: synorg.example.com
Content-Type: application/json
X-GitHub-Event: issues
X-Hub-Signature-256: sha256=wrongsignature
X-GitHub-Delivery: 12345-67890-abcdef

{ ... }
```

**Response**: HTTP 400 Bad Request

### Missing Signature

```http
POST /github/webhook HTTP/1.1
Host: synorg.example.com
Content-Type: application/json
X-GitHub-Event: issues
X-GitHub-Delivery: 12345-67890-abcdef

{ ... }
```

**Response**: HTTP 400 Bad Request

### Rate Limited

After exceeding 100 requests/minute from the same IP:

**Response**: HTTP 429 Too Many Requests

```json
{
  "error": "Rate limit exceeded. Try again later."
}
```

## Audit Logging

All webhook-related security events are logged to the `audit_logs` table:

| Event Type | Status | Description |
|-----------|--------|-------------|
| `webhook.received` | `success` | Valid webhook processed successfully |
| `webhook.invalid_signature` | `blocked` | Signature verification failed |
| `webhook.missing_signature` | `blocked` | No signature provided |
| `webhook.rate_limited` | `blocked` | Rate limit exceeded |

Each audit log entry includes:
- **IP address**: Remote client IP
- **Request ID**: Rails request ID for correlation
- **Timestamp**: When the event occurred
- **Payload excerpt**: Sanitized summary (no secrets)

Access audit logs via the admin dashboard or query directly:

```ruby
# Recent security events
AuditLog.security_events.recent.limit(100)

# All webhook events
AuditLog.webhook_events.recent.limit(100)

# Blocked requests from specific IP
AuditLog.where(ip_address: "1.2.3.4", status: "blocked")
```

## Testing Webhooks

### Using GitHub CLI

```bash
# Send a test webhook
gh api repos/owner/repo/hooks/12345/tests -X POST
```

### Using curl

```bash
# Generate signature
SECRET="your-webhook-secret"
PAYLOAD='{"action":"opened","issue":{"number":42}}'
SIGNATURE="sha256=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2)"

# Send request
curl -X POST https://synorg.example.com/github/webhook \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: issues" \
  -H "X-Hub-Signature-256: $SIGNATURE" \
  -H "X-GitHub-Delivery: test-12345" \
  -d "$PAYLOAD"
```

### Local Testing

For local development, use a tool like [ngrok](https://ngrok.com/) or [smee.io](https://smee.io/) to expose your local server:

```bash
# Start ngrok
ngrok http 3000

# Update GitHub webhook URL to:
# https://abc123.ngrok.io/github/webhook
```

## Security Best Practices

1. **Use Strong Secrets**: Generate webhook secrets with at least 32 bytes of entropy
2. **Rotate Regularly**: Change webhook secrets periodically (see [Secret Rotation](./tokens.md#secret-rotation))
3. **Monitor Audit Logs**: Review blocked requests for suspicious patterns
4. **Use HTTPS**: Always use HTTPS for webhook endpoints in production
5. **Validate Payloads**: Never trust webhook data without validation
6. **Limit Exposure**: Only enable webhook events you actually need

## Troubleshooting

### Webhook Delivery Fails

1. Check GitHub webhook delivery logs in repository settings
2. Verify the webhook URL is correct and accessible
3. Check Synorg audit logs for the delivery ID
4. Verify the webhook secret matches in both GitHub and Synorg

### Signature Verification Fails

1. Ensure the webhook secret is identical in GitHub and Synorg
2. Verify you're using SHA-256 (not SHA-1)
3. Check that the payload is not being modified in transit
4. Review audit logs for the specific delivery

### Rate Limiting Issues

1. Check if legitimate traffic is being blocked
2. Adjust rate limits in `config/initializers/rack_attack.rb`
3. Consider using per-sender limits instead of per-IP
4. Review audit logs to identify the source

## References

- [GitHub Webhooks Documentation](https://docs.github.com/en/webhooks)
- [Securing Webhooks](https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries)
- [Rack::Attack Documentation](https://github.com/rack/rack-attack)
- [OWASP Webhook Security](https://cheatsheetseries.owasp.org/cheatsheets/Webhook_Security_Cheat_Sheet.html)
