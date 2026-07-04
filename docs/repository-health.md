# Repository Health Audit

Date: 2026-07-04

Scope: unmerged remote branches, open Dependabot pull requests, dependency refresh state, GitHub About/sidebar metadata, package visibility, and release presentation.

## Current Repository State

| Area | Status | Evidence |
|---|---|---|
| Default branch | `master` | Local branch tracks `origin/master` |
| Visibility | Private | `gh repo view ... --json isPrivate` returned `true` |
| GitHub About | Needs final sync after this pass | Description and topics are listed below |
| Open unmerged Dependabot branches | 12 after prune | `git fetch --all --prune --tags` then `git branch -r --no-merged origin/master` |
| Open Dependabot PRs | 12 | `gh pr list --state open --json number,title,headRefName,mergeStateStatus,mergeable` |
| Package API access | Limited | GitHub package API returned 403 without `read:packages` |
| Docker Hub packages | Verified by manifest in this pass | `nguyenson1710/cashflow-manager-api:latest` and `nguyenson1710/cashflow-manager-frontend:latest` resolved |
| GHCR packages | Verified by manifest in this pass | `ghcr.io/jasontm17/cashflow-manager-api:1.0.0` and `ghcr.io/jasontm17/cashflow-manager-frontend:1.0.0` resolved; GitHub package API needs additional token scope |

The user mentioned 13 unmerged branches. After pruning stale refs on 2026-07-04, the authoritative remote list is 12 unmerged Dependabot branches.

## Dependabot PR Audit

| PR | Branch | Area | Requested update | Resolution in this pass |
|---:|---|---|---|---|
| 22 | `dependabot/docker/api/node-26-alpine` | API Docker | `node:26-alpine` | Applied to `api/Dockerfile` |
| 26 | `dependabot/npm_and_yarn/api/vitest-4.1.9` | API dev dependency | `vitest@4.1.9` | Applied to `api/package.json` and lockfile |
| 27 | `dependabot/npm_and_yarn/api/emnapi/runtime-1.11.1` | API transitive/dev dependency | `@emnapi/runtime@1.11.1` | Applied to `api/package.json` and lockfile |
| 28 | `dependabot/npm_and_yarn/api/emnapi/core-1.11.1` | API transitive/dev dependency | `@emnapi/core@1.11.1` | Applied to `api/package.json` and lockfile |
| 30 | `dependabot/pub/sqlite3-3.3.3` | Flutter dependency | `sqlite3@3.3.3` | Superseded by `sqlite3 ^3.3.4` |
| 31 | `dependabot/pub/flutter_riverpod-3.3.2` | Flutter dependency | `flutter_riverpod@3.3.2` | Applied to `pubspec.yaml` and lockfile |
| 32 | `dependabot/pub/path_provider-2.1.6` | Flutter dependency | `path_provider@2.1.6` | Applied to `pubspec.yaml` and lockfile |
| 33 | `dependabot/github_actions/actions/checkout-7` | GitHub Actions | `actions/checkout@v7` | Applied to all workflows using checkout |
| 35 | `dependabot/pub/pdf-3.13.0` | Flutter dependency | `pdf@3.13.0` | Applied to `pubspec.yaml` and lockfile |
| 36 | `dependabot/pub/printing-5.15.0` | Flutter dependency | `printing@5.15.0` | Applied to `pubspec.yaml` and lockfile |
| 37 | `dependabot/npm_and_yarn/api/types/node-26.0.1` | API dev dependency | `@types/node@26.0.1` | Applied to `api/package.json`; CI Node version aligned to 26 |
| 38 | `dependabot/npm_and_yarn/api/fastify-5.9.0` | API dependency | `fastify@5.9.0` | Applied to `api/package.json` and lockfile |

Planned cleanup after validation and push: close these Dependabot PRs as superseded by the master dependency refresh, delete their remote branches where GitHub permits it, fetch/prune again, and verify `git branch -r --no-merged origin/master` no longer lists stale Dependabot refs.

## GitHub About Target

Recommended repository description:

```text
Professional offline-first Flutter personal finance app with PIN/biometrics, SQLite, Riverpod 3, Node 26 Fastify/PostgreSQL API, OpenAPI, Docker Hub/GHCR packages, and n8n HMAC automation.
```

Recommended homepage:

```text

```

Keep homepage empty until there is a stable public product/release/download page.

Recommended topics:

```text
android, android-app, dart, docker, fastify, finance-app, flutter, flutter-app, mobile-app, n8n, offline-finance, offline-first, openapi, personal-finance, postgresql, prisma, riverpod, security, sqlite, vietnamese
```

## Package Presentation

| Package | Registry | Expected tags | Verification path |
|---|---|---|---|
| `cashflow-manager-api` | Docker Hub | `latest` | `docker manifest inspect nguyenson1710/cashflow-manager-api:latest` |
| `cashflow-manager-frontend` | Docker Hub | `latest` | `docker manifest inspect nguyenson1710/cashflow-manager-frontend:latest` |
| `cashflow-manager-api` | GHCR | `1.0.0`, `v1.0.0`, `latest`, SHA tags | GitHub Packages UI or token with `read:packages` |
| `cashflow-manager-frontend` | GHCR | `1.0.0`, `v1.0.0`, `latest`, SHA tags | GitHub Packages UI or token with `read:packages` |

The repository package sidebar should show the API and frontend container packages. If the package sidebar is blank for other viewers, check package visibility on GHCR/Docker Hub and rerun the Docker Publish workflow with registry secrets configured.

## Documentation/Media State

| Asset | Status |
|---|---|
| README screenshots | Regenerated from deterministic seeded fake data in the UI redesign pass |
| README GIF | Rebuilt on 2026-07-04 from current light-mode screenshots |
| Architecture diagram | Added as `docs/media/project-architecture.svg` and `docs/media/project-architecture.png` |
| Security posture | Added as `docs/security-posture.md` |
| Branch/package audit | This document |

## Follow-up Checklist

- Validate API/Flutter/Docker/docs gates after dependency refresh.
- Push focused commits to `master`.
- Close superseded Dependabot PRs with a comment pointing to the pushed master commit.
- Fetch/prune remotes and confirm the stale Dependabot branch count is zero or document any branch GitHub refuses to delete.
- Sync GitHub About description/topics to the target above.
- Re-run package manifest checks for Docker Hub and GHCR where token scope permits.

## Unresolved Questions

- Should stale Dependabot PRs be closed immediately after this pass, or left open for GitHub audit history after master includes the same or newer versions?
- Should repository visibility remain private until Android real-device and macOS/iOS release blockers are cleared?
