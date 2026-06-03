# System Architecture / Kiến trúc hệ thống / システムアーキテクチャ

CashFlow Manager follows the **C4 model**: Context → Container → Component → Code. Diagrams use Mermaid.js v11.

## C4 Level 1 — System Context

```mermaid
flowchart TB
    User["👤 User<br/>Vietnamese, English, Japanese"]

    subgraph CashFlow["CashFlow Manager System"]
        Mobile["📱 Flutter Mobile App<br/>Android · iOS"]
        API["🔧 Fastify API<br/>Node.js · TypeScript"]
        DB[("🗄️ PostgreSQL 16<br/>Account & Sync Data")]
        N8N["⚙️ n8n Automation<br/>AI Analysis Workflow"]
    end

    OpenAI["🤖 OpenAI-compatible<br/>Chat Provider"]
    SePay["💳 SePay<br/>Direct Payments"]
    Stores["🏪 App Stores<br/>IAP Verification"]

    User -->|"Offline-first usage"| Mobile
    Mobile -->|"HTTPS · OpenAPI 3.1"| API
    Mobile -->|"JWT Bearer"| API
    API --> DB
    API -->|"HMAC Webhook"| N8N
    N8N --> OpenAI
    API -.->|"Optional"| SePay
    API -.->|"Optional"| Stores
```

**Key relationships:**
- The mobile app works **completely offline** without any backend connection
- The API is only needed for **optional account sync** and **AI analysis**
- n8n automation is **optional** — gated behind Docker profile `automation`
- SePay and IAP verification are **optional payment foundations**

## C4 Level 2 — Container

```mermaid
flowchart TB
    subgraph Device["📱 User Device"]
        Flutter["Flutter App<br/>Dart · Riverpod · SQLite"]
    end

    subgraph Docker["🐳 Docker Runtime"]
        subgraph Services["Application Services"]
            API2["api<br/>Fastify · Prisma · JWT/JWKS<br/>Port :3000"]
            Frontend["frontend<br/>Nginx APK Artifact Server<br/>Port :8080"]
        end

        subgraph Data["Data Stores"]
            PG[("postgres<br/>PostgreSQL 16<br/>Port :5432→5433")]
            N8NPG[("n8n-postgres<br/>PostgreSQL 16<br/>n8n Internal DB")]
        end

        subgraph Tools["Tools (profiles)"]
            Migrate["migrate<br/>Prisma Migrate Deploy"]
            Seed["seed<br/>Demo Data Seed"]
        end

        subgraph Automation["Automation (profile: automation)"]
            N8NService["n8n<br/>Workflow Engine<br/>Port :5678"]
            N8NImport["n8n-import<br/>Workflow Import"]
            N8NActivate["n8n-activate<br/>Workflow Activation"]
        end
    end

    Flutter -->|"HTTPS"| API2
    Flutter -->|"Wget APK"| Frontend
    API2 --> PG
    API2 -->|"HMAC Signed"| N8NService
    N8NService --> N8NPG
    Migrate --> PG
    Seed --> PG
```

**Container details:**

| Container | Image | Port | Healthcheck |
|-----------|-------|------|-------------|
| `api` | `Dockerfile` (multi-stage, Node 22 distroless) | 3000 | `GET /healthz` |
| `frontend` | `Dockerfile.frontend` (nginx:alpine) | 8080 | Wget APK artifact |
| `postgres` | `postgres:16-alpine` | 5433→5432 | `pg_isready` |
| `n8n` | `n8nio/n8n:1.121.3` | 5678 | `GET /healthz` |
| `n8n-postgres` | `postgres:16-alpine` | internal | `pg_isready` |
| `migrate` | `api/Dockerfile` tools target | — | One-shot |
| `seed` | `api/Dockerfile` tools target | — | One-shot |

## C4 Level 3 — Flutter Component

```mermaid
flowchart TB
    subgraph UI["UI Layer"]
        Screens["Screens<br/>Dashboard · Transactions · Wallets<br/>Budgets · Reports · Settings"]
        Widgets["Shared Widgets<br/>ShimmerLoading · AnimatedBalance<br/>GradientHero · EmptyState"]
        Localization["Localization<br/>AppLocalizations<br/>VI · EN · JA"]
    end

    subgraph State["State Layer (Riverpod)"]
        FinanceProvider["financeControllerProvider<br/>AsyncNotifier"]
        LocaleProvider["localeControllerProvider"]
        PrivacyProvider["privacyLockProvider"]
        AccountProvider["remoteAccountProvider"]
        SyncProvider["remoteSyncProvider"]
    end

    subgraph Data["Data Layer"]
        Store["LocalFinanceStore<br/>SQLite (sqflite)"]
        SyncClient["RemoteSyncClient<br/>OpenAPI Client"]
        SessionStore["RemoteSessionStore<br/>Secure Storage"]
    end

    subgraph Services["Service Layer"]
        Calculator["FinanceCalculator<br/>Balances · Budgets · Forecasts"]
        Exporter["ExportService<br/>CSV · PDF"]
        Backup["FinanceBackupService<br/>Encrypt · Restore"]
        Privacy["PrivacyLockService<br/>PBKDF2 · Biometric"]
    end

    Screens --> FinanceProvider
    Widgets --> Screens
    Localization --> Screens
    FinanceProvider --> Store
    FinanceProvider --> SyncClient
    FinanceProvider --> Calculator
    SyncClient --> SessionStore
    Exporter --> Store
    Backup --> Store
    Privacy --> SessionStore
```

## C4 Level 3 — Fastify API Component

```mermaid
flowchart TB
    subgraph Entrypoints["Entrypoints"]
        Health["GET /healthz<br/>GET /readyz"]
        JWKS["GET /.well-known/jwks.json"]
        Auth["POST /v1/auth/register<br/>POST /v1/auth/login<br/>POST /v1/auth/refresh<br/>POST /v1/auth/logout"]
        Finance["CRUD /v1/wallets<br/>CRUD /v1/categories<br/>CRUD /v1/transactions<br/>CRUD /v1/budgets<br/>CRUD /v1/goals"]
        Sync["GET /v1/sync/bootstrap<br/>GET /v1/sync/changes<br/>POST /v1/sync/push"]
        AI["POST /v1/ai/analysis"]
    end

    subgraph Middleware["Middleware Chain"]
        direction LR
        ReqId["request-id"] --> Trace["trace-propagation"]
        Trace --> Access["access-log"]
        Access --> Recover["recover"]
        Recover --> Timeout["timeout"]
        Timeout --> Metrics["metrics"]
    end

    subgraph Core["Core Services"]
        AuthService["AuthService<br/>Ed25519 JWT · Refresh Tokens"]
        FinanceService["FinanceService<br/>Validation · Soft Delete · Revision"]
        SyncService["SyncService<br/>Bootstrap · Changes · Push · Conflict"]
        AIService["AIProxyService<br/>HMAC Sign → n8n Webhook"]
    end

    subgraph Infrastructure["Infrastructure"]
        Prisma["Prisma Client<br/>PostgreSQL Adapter"]
        Env["Environment<br/>Zod Validated"]
        RateLimit["Rate Limiter<br/>Per-route · In-memory"]
    end

    Entrypoints --> Middleware
    Middleware --> Core
    AuthService --> Prisma
    FinanceService --> Prisma
    SyncService --> Prisma
    AIService --> Env
```

## Deployment View

```mermaid
flowchart LR
    subgraph GH["GitHub"]
        Repo["Source Code<br/>master branch"]
        Actions["GitHub Actions<br/>CI · Security · Release · Publish"]
        GHCR["GitHub Container Registry<br/>ghcr.io/jasontm17/*"]
    end

    subgraph DH["Docker Hub"]
        DockerHub["nguyenson1710/*"]
    end

    subgraph Target["Deployment Targets"]
        Local["Local<br/>docker compose up"]
        VPS["VPS / Cloud VM<br/>docker compose + TLS"]
    end

    Repo --> Actions
    Actions -->|"push on master/tag"| GHCR
    Actions -->|"push on master/tag"| DockerHub
    GHCR --> Target
    DockerHub --> Target
    Local -->|"docker compose pull"| GHCR
```

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Mobile Framework | Flutter 3.44 · Dart 3.12 | Cross-platform UI |
| State Management | Riverpod 2.x | Reactive state |
| Local Database | SQLite (sqflite) | Offline-first storage |
| API Runtime | Fastify 5.x · Node.js 22 | REST API server |
| ORM | Prisma 7.8 | Type-safe DB access |
| Auth | Ed25519 JWT · JWKS | Asymmetric signing |
| Database | PostgreSQL 16 | Server-side persistence |
| Automation | n8n 1.121 | AI workflow orchestration |
| Frontend Serve | Nginx Alpine | APK artifact hosting |
| CI/CD | GitHub Actions | Test · Build · Publish |
| Container Registry | GHCR · Docker Hub | Image distribution |
| API Contract | OpenAPI 3.1 | Source of truth |
| Monitoring | Healthz · Readyz · /metrics | Observability endpoints |

## Key Architectural Decisions

See [ADR index](adr/) for full decision records:

| ADR | Decision |
|-----|----------|
| [0001](adr/0001-record-architecture-decisions.md) | Record architecture decisions |
| [0002](adr/0002-offline-first-architecture.md) | Offline-first: local SQLite, no mandatory backend |
| [0003](adr/0003-ed25519-jwt-auth.md) | Ed25519 asymmetric JWT with JWKS publication |
| [0004](adr/0004-integer-financial-amounts.md) | All money values stored as integers (VND) |

## Design Principles

1. **Offline-first**: App fully functional without network, account, or backend
2. **Sync is opt-in**: Remote sync never blocks or corrupts local data
3. **Separation of concerns**: Flutter/API/n8n are independent deployable units
4. **Contract-first**: OpenAPI 3.1 is canonical; generated clients eliminate drift
5. **Security by default**: PIN hash, encrypted backup, HMAC webhooks, JWT rotation
6. **Integer money**: All financial amounts are integers — no floating-point
