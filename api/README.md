# CashFlow Manager API

## Purpose

Backend API for CashFlow Manager account, authenticated sync, and optional AI analysis features. The Flutter app stays offline-first locally and talks to this service only for authenticated remote sync.

## API surface

- `GET /.well-known/jwks.json` — public EdDSA signing keys for bearer token verification.
- `GET /healthz` — process health check.
- `GET /readyz` — PostgreSQL readiness check that verifies the migrated application schema exists.
- `/v1/auth/*`, `/v1/me`, finance resource routes, and read-only sync bootstrap are tracked in `../docs/openapi.yaml`.

## Env vars

| name | required | default | description |
|---|---:|---|---|
| `DATABASE_URL` | yes | local Compose placeholder | PostgreSQL connection string. Use real secret only in local `.env` or deployment secret store. |
| `API_PORT` | no | `3000` | HTTP listen port inside the API container. |
| `API_HOST_PORT` | no | `3000` | Docker Compose host port mapped to the API container; set to `3001` if host `3000` is busy. |
| `NODE_ENV` | no | `development` | Runtime mode: `development`, `test`, or `production`. |
| `ACCESS_TOKEN_PRIVATE_KEY_PEM` | production | dev-only generated key | Ed25519 private key PEM for signing access tokens. |
| `ACCESS_TOKEN_PUBLIC_KEY_PEM` | production | dev-only generated key | Ed25519 public key PEM published through JWKS. |
| `ACCESS_TOKEN_KID` | no | `local-development-key` | Key ID advertised in JWT headers and JWKS. |
| `ACCESS_TOKEN_ISSUER` | no | `cashflow-manager-api` | Access-token issuer claim. |
| `ACCESS_TOKEN_AUDIENCE` | no | `cashflow-manager-mobile` | Access-token audience claim. |
| `N8N_CHATBOT_WEBHOOK_URL` | no | unset | n8n webhook URL for `/v1/ai/analysis`; leave unset to return a 503 unavailable response. |
| `N8N_CHATBOT_WEBHOOK_SECRET` | when webhook URL is set | unset | HMAC-SHA256 secret used by the API and n8n workflow to sign and verify `x-cashflow-signature-sha256`; store real values only in local `.env` or deployment secrets. |
| `N8N_HOST_PORT` | no | `5678` | Docker Compose host port for the optional n8n automation UI/API. |
| `N8N_ENCRYPTION_KEY` | automation | local placeholder | Stable n8n encryption key shared by the runtime and workflow import container. |
| `N8N_AI_CHAT_COMPLETIONS_URL` | automation AI | unset | OpenAI-compatible chat completions endpoint used by the imported workflow. |
| `N8N_AI_API_KEY` | automation AI | unset | Local/deployment AI provider token for the imported workflow; never commit a real value. |
| `N8N_AI_MODEL` | automation AI | unset | Model name passed to the chat completions endpoint. |

## Run locally

```bash
npm install
npm run prisma:generate
npm run dev
```

With PostgreSQL and the separate frontend artifact container:

```bash
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
```

If host port `3000` is already in use, remap only the API host port:

```powershell
$env:API_HOST_PORT = '3001'
docker compose up --build
```

If host port `8080` is already in use, remap only the frontend artifact server host port:

```powershell
$env:FRONTEND_HOST_PORT = '8081'
docker compose up --build
```

The default Compose project uses persistent local volumes. For a destructive fresh database smoke, use an isolated project name instead of deleting normal development data:

```powershell
$env:COMPOSE_PROJECT_NAME = 'cashflow-smoke'
$env:API_HOST_PORT = '3001'
$env:FRONTEND_HOST_PORT = '8081'
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
```

If you deliberately run Prisma from the host, first confirm the published Postgres port with `docker compose port postgres 5432`, then set `DATABASE_URL` to that host port (default: `localhost:5433`).

## Test

```bash
npm run prisma:generate
npm run typecheck
npm run build
npm test
npm audit --audit-level=moderate
```

Coverage gates will be added when route modules move beyond the health/readiness skeleton.

## Runbook

- Start stack: run `postgres`, `migrate`, `seed`, then `api frontend` using the commands above.
- If host `3000` is busy, set `API_HOST_PORT=3001` and use `http://localhost:3001` for checks.
- Check API health: open `http://localhost:3000/healthz`.
- Check database readiness: open `http://localhost:3000/readyz` after migrations are applied.
- Check JWKS: open `http://localhost:3000/.well-known/jwks.json` and confirm the active `kid` is present.
- Apply existing migrations with `npm run prisma:deploy`; use `npm run prisma:migrate` only for local schema iteration.
- Seed demo data: `npm run db:seed` after migrations are applied.
- If Prisma returns `P1010`, verify `docker compose port postgres 5432` (default host port `5433`), TCP password auth, and database ownership before changing schema code.
- Rotate database credentials in deployment secrets, then restart `api` and `postgres` services.
