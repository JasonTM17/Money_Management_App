# Repository Health Audit

Date: 2026-07-04

Scope: unmerged remote branches, open Dependabot pull requests, dependency refresh state, GitHub About/sidebar metadata, package visibility, and release presentation.

## Current Repository State

| Area | Status | Evidence |
|---|---|---|
| Default branch | `master` | Local branch tracks `origin/master` |
| Visibility | Private | `gh repo view ... --json isPrivate` returned `true` |
| GitHub About | Synced | Description updated, homepage kept empty, `security` topic added |
| Open unmerged Dependabot branches | 0 after cleanup | `git fetch --all --prune --tags` then `git branch -r --no-merged origin/master` returned no stale refs |
| Open Dependabot PRs | 0 after cleanup | `gh pr list --state open --json number,title,headRefName --limit 50` returned `[]` |
| GitHub Actions latest push | Blocked before job start | GitHub check-run annotation: recent account payments failed or spending limit needs to be increased |
| Package API access | Limited | GitHub package API returned 403 without `read:packages` |
| Docker Hub packages | Verified by manifest in this pass | `nguyenson1710/cashflow-manager-api:latest` and `nguyenson1710/cashflow-manager-frontend:latest` resolved |
| GHCR packages | Verified by manifest in this pass | `ghcr.io/jasontm17/cashflow-manager-api:1.0.0` and `ghcr.io/jasontm17/cashflow-manager-frontend:1.0.0` resolved; GitHub package API needs additional token scope |

The user mentioned 13 unmerged branches. After pruning stale refs on 2026-07-04, the authoritative pre-cleanup remote list was 12 unmerged Dependabot branches. Those 12 PRs were superseded by master commit `099dbbc`, closed with an audit comment, and their remote branches were deleted.

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

Cleanup result: all 12 PRs in the table were closed as superseded, all 12 remote branches were deleted, and `git branch -r --no-merged origin/master` returned no output after fetch/prune.

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

## Completed Cleanup

- Validated API/Flutter/Docker/docs gates after dependency refresh.
- Pushed focused commits to `master`.
- Closed superseded Dependabot PRs `#22`, `#26`, `#27`, `#28`, `#30`, `#31`, `#32`, `#33`, `#35`, `#36`, `#37`, and `#38`.
- Deleted the corresponding remote Dependabot branches.
- Fetched/pruned remotes and confirmed stale unmerged Dependabot branch count is zero.
- Synced GitHub About description/topics to the target above.
- Re-ran package manifest checks for Docker Hub and GHCR.
- Investigated latest GitHub Actions failures and confirmed jobs are blocked before start by GitHub billing/spending-limit state, not by repository code or workflow syntax.

## Follow-up Checklist

- Keep Dependabot open PR count at zero by either merging or superseding future dependency PRs promptly.
- Resolve GitHub account billing/spending limit, then rerun CI, Security, CodeQL SAST, and Docker Publish for the latest `master` commit.
- Re-run GitHub package API verification with a token that has `read:packages` if UI-level package/sidebar auditing is required.

## Unresolved Questions

- Should repository visibility remain private until Android real-device and macOS/iOS release blockers are cleared?
