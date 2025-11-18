# Security Documentation

This directory contains security-related documentation for Synorg.

## Documents

- **[webhooks.md](./webhooks.md)** - GitHub webhook security, including signature verification, rate limiting, and audit logging
- **[tokens.md](./tokens.md)** - Personal Access Token (PAT) management, including creation, storage, rotation, and best practices

## Quick Links

### For Administrators

- [Setting up webhook security](./webhooks.md#signature-verification)
- [Configuring rate limits](./webhooks.md#rate-limiting)
- [Reviewing audit logs](./webhooks.md#audit-logging)

### For Developers

- [Creating a GitHub PAT](./tokens.md#creating-a-personal-access-token)
- [Storing tokens securely](./tokens.md#storing-tokens-securely)
- [Token rotation procedure](./tokens.md#rotation-process)

## Security Principles

Synorg follows these core security principles:

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimal permissions required for operation
3. **Audit Everything**: Comprehensive logging of security events
4. **No Secrets in Database**: Credentials stored in secure secret managers
5. **Zero Trust**: Verify every request, assume breach

## Reporting Security Issues

If you discover a security vulnerability, please:

1. **DO NOT** open a public GitHub issue
2. Email security concerns to the project maintainers
3. Include details about the vulnerability and how to reproduce it
4. Allow reasonable time for a fix before public disclosure

## Security Checklist

Before deploying to production:

- [ ] Webhook secrets are randomly generated (≥32 bytes entropy)
- [ ] Rate limiting is enabled and tested
- [ ] PATs use fine-grained tokens with minimal scopes
- [ ] PATs are stored in GitHub Secrets or secret manager (not database)
- [ ] Audit logs are being captured and monitored
- [ ] HTTPS is enforced for all webhook endpoints
- [ ] Security updates are applied regularly
- [ ] Incident response plan is documented

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
