# System Diagrams

These Mermaid.js v11 diagrams summarize the CashFlow Manager runtime architecture, local-first data flow, optional sync, and automation boundaries.

## Runtime Architecture

```mermaid
flowchart TB
    User["Mobile user"] --> App["Flutter app<br/>Android, iOS, desktop-ready"]

    subgraph Device["User device"]
        App --> Gate["PrivacyGate<br/>PIN and opt-in biometrics"]
        Gate --> Controller["FinanceController<br/>Riverpod state"]
        Controller --> Store["LocalFinanceStore<br/>SQLite"]
        Controller --> Calculator["FinanceCalculator<br/>balances, budgets, forecasts"]
        Controller --> Exporter["Export and backup services<br/>CSV, PDF, JSON backup"]
        Controller --> SyncClient["RemoteSyncClient<br/>optional account sync"]
    end

    SyncClient -->|"HTTPS / OpenAPI"| Api["Fastify API"]

    subgraph Backend["Docker backend"]
        Api --> Auth["Auth, account, JWT, JWKS"]
        Api --> Finance["Finance CRUD and validation"]
        Api --> Sync["Sync bootstrap, changes, push"]
        Api --> Households["Households and shared budgets"]
        Api --> Entitlements["Entitlements, IAP, SePay foundations"]
        Api --> AiProxy["AI analysis proxy"]
        Api --> Pg[("PostgreSQL")]
    end

    AiProxy -->|"HMAC webhook"| N8N["n8n workflow"]
    N8N --> Provider["OpenAI-compatible chat provider"]

    classDef mobile fill:#E8F7EF,stroke:#16A34A,color:#092D1F;
    classDef backend fill:#EAF2FF,stroke:#2563EB,color:#10233F;
    classDef data fill:#FFF7E6,stroke:#D97706,color:#3A2500;
    class App,Gate,Controller,Store,Calculator,Exporter,SyncClient mobile;
    class Api,Auth,Finance,Sync,Households,Entitlements,AiProxy,N8N,Provider backend;
    class Pg data;
```

## Local-First Data Flow

```mermaid
flowchart LR
    Action["User creates or edits finance data"] --> Controller["FinanceController command"]
    Controller --> Validate["Local validation and money math"]
    Validate --> SQLite[("SQLite local store")]
    SQLite --> State["FinanceState reload"]
    State --> UI["Dashboard, transactions, budgets, reports"]
    State --> Derived["Derived insights<br/>cashflow, alerts, forecasts"]
    State --> Backup["Backup and export surfaces"]

    SQLite -. "dirty sync metadata" .-> Queue["Optional sync queue"]
    Queue -. "when account and network exist" .-> Remote["RemoteSyncClient"]

    classDef local fill:#F0FDF4,stroke:#22C55E,color:#102A18;
    classDef optional fill:#F5F3FF,stroke:#7C3AED,color:#25114D;
    class Action,Controller,Validate,SQLite,State,UI,Derived,Backup local;
    class Queue,Remote optional;
```

## Optional Account Sync

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter app
    participant Local as SQLite store
    participant API as Fastify API
    participant DB as PostgreSQL

    User->>App: Sign in or register
    App->>API: POST /v1/auth/login or /v1/auth/register
    API->>DB: Verify account and refresh token state
    API-->>App: Access token and refresh token
    App->>Local: Store remote session securely

    App->>API: GET /v1/sync/bootstrap
    API->>DB: Load server finance snapshot
    API-->>App: Bootstrap payload and cursor
    App->>Local: Merge acknowledged remote state

    User->>App: Edit wallet, transaction, budget, or goal
    App->>Local: Save local-first change immediately
    App->>API: POST /v1/sync/push with clientMutationId and baseRevision
    API->>DB: Apply mutation or detect conflict
    alt Mutation accepted
        API-->>App: Applied mutation and new revision
        App->>Local: Mark row clean with remote revision
    else Revision conflict
        API-->>App: 409 sync_conflict
        App->>Local: Keep local data and surface conflict path
    end
```

## Automation And Release Boundary

```mermaid
flowchart TB
    subgraph CI["GitHub Actions"]
        FlutterCI["Flutter analyze, tests, Android builds"]
        ApiCI["API Prisma generate, typecheck, tests"]
        DockerCI["Docker image build and publish lane"]
        ReleaseCI["Release APK, AAB, package metadata"]
    end

    subgraph Runtime["Optional local or hosted runtime"]
        Compose["Docker Compose"] --> Postgres[("PostgreSQL 16")]
        Compose --> Api["Fastify API container"]
        Compose --> Frontend["APK artifact server"]
        Compose --> N8N["n8n automation profile"]
        N8N --> N8NDb[("n8n PostgreSQL")]
    end

    Api -->|"signed webhook"| N8N
    N8N -->|"strict JSON answer"| Api
    Api -->|"optional"| SePay["SePay direct/off-store payments"]
    Api -->|"optional"| Stores["Apple or Google IAP verification"]

    classDef ci fill:#EFF6FF,stroke:#2563EB,color:#10233F;
    classDef runtime fill:#F8FAFC,stroke:#475569,color:#111827;
    classDef external fill:#FFF7ED,stroke:#EA580C,color:#3B1F00;
    class FlutterCI,ApiCI,DockerCI,ReleaseCI ci;
    class Compose,Postgres,Api,Frontend,N8N,N8NDb runtime;
    class SePay,Stores external;
```

## Reading Notes

- The mobile app remains useful without account, network, PostgreSQL, n8n, or payment providers.
- PostgreSQL is never accessed directly from Flutter; all remote data access goes through the Fastify API and OpenAPI contract.
- Sync is optional and conflict-aware; failed remote operations must not delete or corrupt local finance data.
- n8n receives only the signed AI-analysis payload from the API, not hidden local app data.