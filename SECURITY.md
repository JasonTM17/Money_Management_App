# Security Policy

## Supported Versions

Security fixes target the latest `1.0.x` release line.

## Reporting a Vulnerability

Please report vulnerabilities privately by opening a GitHub security advisory or contacting the repository owner through GitHub. Do not publish exploit details in public issues before a fix is available.

Include:

- Affected version or commit.
- Reproduction steps.
- Expected and actual impact.
- Whether the issue affects local mobile data, backend API data, Docker deployment, or n8n automation.

## Security Scope

CashFlow Manager protects local financial data with:

- Local-only PIN and opt-in biometric privacy gate.
- Salted PBKDF2-HMAC-SHA256 PIN hashing.
- Failed PIN cooldown.
- Lifecycle relock when the app leaves foreground.
- Re-authentication before data reset and backup restore.
- Backup restore preview and schema validation.
- CSV formula escaping before spreadsheet export.

Backend and automation security expectations:

- No direct Flutter-to-PostgreSQL access.
- JWT/JWKS for authenticated backend routes.
- HMAC signature verification for n8n webhook calls.
- Secrets only in local `.env` files or deployment secret stores.
- No API keys, keystores, local database files, private notes, or credentials in git.

## Out of Scope

- Social engineering.
- Denial-of-service testing without prior approval.
- Attacks against third-party providers outside this repository.
- Reports based only on missing future features already listed as deferred.
