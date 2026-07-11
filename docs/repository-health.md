# Repository Health Audit

Date: 2026-07-04
Last rechecked: 2026-07-11

Scope: unmerged remote branches, open Dependabot pull requests, dependency refresh state, GitHub About/sidebar metadata, package visibility, and release presentation.

## Current Repository State

| Area | Status | Evidence |
|---|---|---|
| Default branch | `master` | Local branch tracks `origin/master` |
| Visibility | Public | `gh repo view ... --json visibility` returned public visibility |
| GitHub About | Synced | Description updated, homepage kept empty, `security` topic added |
| Open unmerged Dependabot branches | 0 after cleanup | `git fetch --all --prune --tags` then `git branch -r --no-merged origin/master` returned no stale refs |
| Open Dependabot PRs | 0 after cleanup | `gh pr list --state open --json number,title,headRefName --limit 50` returned `[]` |
| GitHub Actions latest push | Deferred by Actions quota/token | User confirmed GitHub Actions quota/token is exhausted; latest check-run annotation surfaces this as a billing/spending-limit block before job startup |
| Package API access | Verified | `gh api user/packages/container/...` and `gh api users/JasonTM17/packages/container/...` returned both API and frontend package records |
| Docker Hub packages | Verified by manifest in this pass | `nguyenson1710/cashflow-manager-api:latest` and `nguyenson1710/cashflow-manager-frontend:latest` resolved |
| GHCR packages | Verified by manifest and package API | `ghcr.io/jasontm17/cashflow-manager-api:1.0.0` and `ghcr.io/jasontm17/cashflow-manager-frontend:1.0.0` resolved; GitHub package API also returned both packages |

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

| Package | Registry | Verified tag | Manifest digest |
|---|---|---|---|
| `cashflow-manager-api` | Docker Hub | `latest` | `sha256:44c8449b7cf9f970bffabe3c29027f62171a0a22127a03bc099324a98d72cd23` |
| `cashflow-manager-frontend` | Docker Hub | `latest` | `sha256:a609d47764a660bdb022efad62360084e3695a0c543e9f26a27a24502862f6ba` |
| `cashflow-manager-api` | GHCR | `1.0.0` | `sha256:ab89295de33dfacaf41b069d818b5aefd5eaaa98c236e6cfb3e9942eef608d58` |
| `cashflow-manager-frontend` | GHCR | `1.0.0` | `sha256:af9a0012daf3d81966165dcbd7a031a3534a7ca07c0b849cf2c03e5dfe1c4318` |

Verification commands used `docker manifest inspect` against Docker Hub and GHCR, plus GitHub package API reads for both container packages. Dockerfiles and publish metadata include `org.opencontainers.image.source=https://github.com/JasonTM17/Money_Management_App` plus title/description/url/documentation labels so the next package publish refreshes repository link metadata. If the repository sidebar does not refresh immediately for other viewers, keep the direct package links below visible and rerun Docker Publish after GitHub Actions quota/token is restored.

Direct package links are present in `README.md` so package access remains visible while the GitHub repository sidebar refreshes:

- Docker Hub API: `https://hub.docker.com/r/nguyenson1710/cashflow-manager-api`
- Docker Hub frontend: `https://hub.docker.com/r/nguyenson1710/cashflow-manager-frontend`
- GHCR API: `https://github.com/users/JasonTM17/packages/container/package/cashflow-manager-api`
- GHCR frontend: `https://github.com/users/JasonTM17/packages/container/package/cashflow-manager-frontend`

Additional audit, rechecked on 2026-07-11:

- `gh auth status` shows the active token includes package write access alongside repository access.
- `gh api user/packages/container/cashflow-manager-api` and `gh api user/packages/container/cashflow-manager-frontend` both return package records.
- `gh api users/JasonTM17/packages/container/cashflow-manager-api` and `gh api users/JasonTM17/packages/container/cashflow-manager-frontend` both return public package records.
- Direct GHCR package links remain in `README.md` as stable entry points even if GitHub's sidebar cache lags behind package metadata.

## Documentation/Media State

| Asset | Status |
|---|---|
| README screenshots | Regenerated from deterministic seeded fake data in the UI redesign pass |
| README GIF | Rebuilt on 2026-07-04 from current light-mode screenshots |
| Architecture diagram | Regenerated with `ck:tech-graph` as `docs/media/project-architecture.svg` and `docs/media/project-architecture.png` |
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
- Added explicit OCI title, description, URL, documentation, vendor, and source metadata for API/frontend images so package pages can link back to this repo after the next publish.
- Investigated latest GitHub Actions failures; user confirmed Actions quota/token is exhausted, and GitHub reports the pre-job block as billing/spending-limit state. No repository code or workflow syntax failure was reached.

## Follow-up Checklist

- Keep Dependabot open PR count at zero by either merging or superseding future dependency PRs promptly.
- Restore GitHub Actions quota/token or account billing capacity, then rerun CI, Security, CodeQL SAST, and Docker Publish for the latest `master` commit.
- After GitHub Actions quota/token is restored, rerun Docker Publish so OCI source/title/description metadata is republished for package sidebar refresh.

## Unresolved Questions

- Should repository homepage stay empty, or should it point to the GitHub Release page until a dedicated product site exists?
