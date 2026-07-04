# Security Posture

Date: 2026-07-04

Scope: Flutter mobile app, Fastify API, Docker Compose runtime, n8n automation workflow, GitHub Actions, public README media, and release/package metadata.

## Executive Summary

CashFlow Manager is designed as a local-first finance app. The strongest security property is that core personal-finance use does not require an account, network call, PostgreSQL, n8n, or AI provider. Server, automation, payment, and package-publish lanes are optional and must stay behind explicit configuration.

Current posture: no hardcoded production secrets found in local scans, API npm audit reports zero known vulnerabilities, Flutter dependency advisory review reports no current advisory on installed packages, Docker Compose hardening is present for API/frontend/n8n services, and CI contains secret/dependency/container/SBOM gates. Remaining release blockers are platform QA, full-repo security scanner evidence from CI/Linux, GitHub security-feature visibility, and production secret management.

## Threat Model

| Asset | Main risk | Current control |
|---|---|---|
| Local finance data | Device access, accidental export, unsafe restore | PIN gate, opt-in biometrics, lifecycle relock, encrypted backup v2, restore preview, destructive-flow re-auth |
| PIN secret | Offline guessing, weak storage | Salted PBKDF2-HMAC-SHA256, failed-attempt cooldown, secure storage |
| CSV/PDF exports | Sensitive data disclosure, spreadsheet formula injection | Explicit export flows, formula escaping for CSV cells |
| API account data | Unauthorized route access, token misuse | JWT/JWKS, Zod/env validation, route-level auth, refresh-token reuse detection |
| Webhooks | Forged automation/payment calls | Raw body HMAC verification and timing-safe comparison |
| PostgreSQL | Direct database exposure | Flutter never connects directly to PostgreSQL; API is the trust boundary |
| n8n workflow | Public editor/token exposure, prompt data leakage | Optional Docker profile, private/internal deployment guidance, HMAC webhook, provider receives only `{ question, locale }` |
| CI/package publishing | Secret leakage, compromised images | GitHub Actions permissions scoped, Docker Hub publish gated by secrets, GHCR publish via `GITHUB_TOKEN`, SBOM artifacts |

## Verified Controls

### Mobile app

- Offline-first by default; no account or network required for core finance.
- PIN setup/unlock/relock path covered by tests.
- Biometric unlock is opt-in and PIN remains fallback.
- Backup restore previews data shape before replacement.
- Reset data and backup restore require re-authentication.
- CSV export escapes formula-leading characters.

### API

- Runtime image now uses Node.js 26 Alpine.
- Fastify routes use request validation and route-level rate limits on sensitive surfaces.
- CORS is disabled by default unless explicitly configured.
- Helmet is registered for HTTP hardening.
- Health/readiness endpoints are separated: `/healthz` for process health and `/readyz` for migrated schema readiness.
- Prisma raw SQL usage observed in health checks is parameterized template usage.

### Docker Compose

- API/frontend/n8n services use `security_opt: no-new-privileges:true`.
- API/frontend services drop Linux capabilities with `cap_drop: [ALL]`.
- API/frontend runtime containers are `read_only: true` with explicit `tmpfs`.
- Local default database passwords are placeholders and must be overridden outside git for any non-local deployment.

### GitHub Actions

- Checkout actions are upgraded to `actions/checkout@v7`.
- Node runners are aligned to Node.js 26 for API CI/security jobs.
- Security workflow runs OpenAPI lint, npm audit, Flutter outdated advisory capture, Gitleaks, Trivy filesystem scan, Docker image scans, and source SBOM generation.
- Docker publish workflow publishes GHCR by default and Docker Hub only when Docker Hub secrets exist.

## Local Audit Evidence

| Check | Result | Notes |
|---|---|---|
| Secret regex scan | Pass | Only placeholders/local defaults found: `.env.example`, `.env.production.example`, Docker Compose local DB URLs, CI local test DB URLs |
| API dependency audit | Pass | `npm --prefix api audit --json`: 0 vulnerabilities |
| API production dependency audit | Pass | `npm --prefix api audit --omit=dev --json`: 0 vulnerabilities |
| Flutter advisory review | Pass | `flutter pub outdated --json`: current packages reported `isCurrentAffectedByAdvisory:false` |
| Docker Compose config | Pass | `docker compose config --quiet` |
| Dangerous-code pattern scan | Pass with review | No `eval`, shell exec, unsafe HTML injection, or unparameterized query pattern found in reviewed app/API code |
| Gitleaks secret scan | Pass | Dockerized Gitleaks scanned 110 commits and reported no leaks |
| Trivy API dependency scan | Pass | Dockerized Trivy scan of `api/package-lock.json`: 0 high/critical vulnerabilities |
| Trivy Flutter dependency scan | Pass | Dockerized Trivy scan of `pubspec.lock`: 0 high/critical vulnerabilities |
| Trivy Dockerfile config scan | Pass | Dockerized Trivy config scan of `api/Dockerfile`: 0 high/critical misconfigurations |
| Full Trivy filesystem scan | Limited locally | Full Windows bind-mount scan stalled on generated/cache trees; targeted lockfile/config scans completed and CI remains the full-repo scanner |
| GitHub Dependabot alerts API | Not accessible | GitHub returned 403: Dependabot alerts disabled or token lacks required repository permission |
| GitHub code scanning API | Not accessible | GitHub returned 403: code scanning not enabled or token lacks required scope |
| GitHub package API | Not accessible | User/package API returned 403 without `read:packages`; package presence must be verified by UI or registry manifest commands |

## Findings

### No Critical Findings

No production secret, private key, API token, keystore, local database, or signing asset was found in the tracked diff or local secret scan.

### Medium

1. GitHub security visibility is limited from the current token/session.
   Impact: Dependabot/code scanning/package state cannot be fully audited through the GitHub API from this machine.
   Mitigation: enable Dependabot alerts/code scanning in repository settings, then rerun the API checks with an owner token that can read those surfaces.

2. Full local Trivy filesystem scan is slow on Windows bind mounts.
   Impact: CI remains the authoritative full-repo scanner; local preflight uses targeted dependency/config scans to avoid hanging on generated/cache trees.
   Mitigation: run the existing `.github/workflows/security.yml` on GitHub for full evidence, or rerun Trivy from Linux/WSL with generated directories excluded.

3. Local placeholder passwords exist in examples and Docker defaults.
   Impact: safe for local dev, unsafe if copied unchanged to production.
   Mitigation: keep `.env*` ignored, override passwords and webhook secrets in deployment secret stores, and never expose n8n publicly without TLS/reverse proxy/private network.

## Release Security Gate

Before a tagged release, run:

```bash
npm --prefix api audit
npm --prefix api audit --omit=dev
flutter pub outdated --json
docker compose config --quiet
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest detect --source=/repo --redact --exit-code=1
docker run --rm -v "$PWD:/repo" aquasec/trivy:latest fs --exit-code 1 --severity CRITICAL,HIGH /repo
```

Also verify the GitHub Actions security, CodeQL, CI, and Docker Publish runs are green on the target commit.

## Unresolved Questions

- Should the repository remain private until real-device Android and macOS/iOS gates pass, or should it become public earlier for portfolio/demo visibility?
- Should GitHub Advanced Security/code scanning be enabled for this private repository, or should the project rely on workflow-based CodeQL/SARIF artifacts only?
