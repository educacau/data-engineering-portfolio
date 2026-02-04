# Security Policy

## Supported Versions

This project is a portfolio demonstration. The latest version on the main branch is supported.

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| older   | :x:                |

## Reporting a Vulnerability

If you discover a security concern, please email the maintainer directly rather than using the public issue tracker.

**Please include:**
- Description of the issue
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Security Best Practices

This project implements several security measures:

### Docker Security
- Non-root users in containers
- Read-only file systems where applicable
- Resource limits configured
- Secrets managed via Docker secrets

### Network Security
- Internal networks for backend services
- TLS encryption for external endpoints
- Firewall rules documented

### Credential Management
- No hardcoded credentials in repository
- `.env.example` template with placeholders
- Secrets stored in separate files (gitignored)
- Docker secrets for sensitive data

## Known Limitations

This is a **demo/portfolio project** intended for local development and evaluation:

- Self-signed certificates (not for production)
- Demo credentials in `.env.example` (change before deployment)
- No authentication on some services (behind local network only)
- Optimized for ease of demo, not production hardening

## Production Considerations

If adapting this project for production use:

1. Replace all default credentials
2. Use proper CA-signed certificates
3. Enable authentication on all services
4. Implement network segmentation
5. Set up proper monitoring and alerting
6. Regular security updates and patching
7. Conduct security assessment

## Updates

Security updates are applied monthly via Dependabot.
