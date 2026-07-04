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

Detailed threat model, local audit evidence, and unresolved security questions are tracked in [`docs/security-posture.md`](docs/security-posture.md).

CashFlow Manager protects local financial data with:

- Local-only PIN and opt-in biometric privacy gate.
- Salted PBKDF2-HMAC-SHA256 PIN hashing.
- Failed PIN cooldown.
- Lifecycle relock when the app leaves foreground.
- Re-authentication before data reset and backup restore.
- Encrypted backup schema v2 with passphrase-derived AES-GCM, plus legacy schema v1 JSON import compatibility.
- Backup restore preview and schema validation before local data replacement.
- CSV formula escaping before spreadsheet export.

Backend and automation security expectations:

- No direct Flutter-to-PostgreSQL access.
- JWT/JWKS for authenticated backend routes.
- Per-route abuse limits for auth, sync push, AI analysis, payment verification, and SePay webhooks.
- Timing-safe HMAC signature verification for n8n and SePay webhook calls over the raw JSON request body.
- Refresh-token reuse detection that revokes outstanding sessions for the same account.
- Release mobile sync disabled unless `CASHFLOW_SYNC_ENABLED=true` and `CASHFLOW_API_BASE_URL` is HTTPS; localhost HTTP is development-only.
- n8n must remain private/internal in production behind TLS and a reverse proxy or private network boundary.
- Secrets only in local `.env` files or deployment secret stores.
- Release gates include dependency audit, secret scan, Trivy scan, checksum generation, and SBOM generation where CI has the required tools.
- No API keys, keystores, local database files, private notes, or credentials in git.

## Out of Scope

- Social engineering.
- Denial-of-service testing without prior approval.
- Attacks against third-party providers outside this repository.
- Reports based only on missing future features already listed as deferred.
