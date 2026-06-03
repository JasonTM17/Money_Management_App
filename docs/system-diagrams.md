# System Diagrams / Sơ đồ hệ thống / システム図

Dynamic behavior diagrams: sync, auth, AI analysis, backup, and CI/CD flows. Mermaid.js v11.
For static architecture (C4 model), see [System Architecture](system-architecture.md).

---

## 1. Full Account Sync Flow

End-to-end sync: registration → bootstrap → changes → push → conflict resolution.

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant Local as SQLite (local)
    participant API as Fastify API
    participant DB as PostgreSQL

    Note over User,DB: === Phase 1: Account Setup ===
    User->>App: Create account (email + password)
    App->>API: POST /v1/auth/register
    API->>DB: Insert user, hash password
    API-->>App: { accessToken, refreshToken }
    App->>Local: Store tokens securely

    Note over User,DB: === Phase 2: Bootstrap ===
    User->>App: Enable sync
    App->>API: GET /v1/sync/bootstrap
    API->>DB: Load server finance snapshot
    API-->>App: { wallets, categories, budgets, goals, cursor }
    App->>Local: Merge into local DB, record cursor

    Note over User,DB: === Phase 3: Local Edit + Push ===
    User->>App: Add transaction "Coffee 45,000đ"
    App->>Local: Insert immediately (offline-first)
    App->>Local: Mark row dirty, record baseRevision
    App->>API: POST /v1/sync/push { clientMutationId, baseRevision, changes }

    alt Revision valid (200)
        API->>DB: Apply mutation, increment revision
        API-->>App: { newRevision, serverTimestamp }
        App->>Local: Mark row clean, update revision
    else Stale revision (409 sync_conflict)
        API-->>App: 409 { serverRevision, conflictType }
        App->>Local: Keep local data, surface conflict
        App->>API: GET /v1/sync/changes?since=cursor
        API-->>App: Recent server changes
        App->>Local: Apply server changes locally
        User->>App: Resolve conflict manually
    end

    Note over User,DB: === Phase 4: Pull Changes ===
    App->>API: GET /v1/sync/changes?since=lastCursor
    API->>DB: Load changes ordered by revision
    API-->>App: [{ changeType, entity, revision, timestamp }]
    App->>Local: Apply each change, advance cursor
```

---

## 2. Authentication Flow

Register → Login → Token Refresh → JWKS Verification.

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Fastify Auth
    participant DB as PostgreSQL
    participant Verifier as External Verifier (other service)

    Note over User,Verifier: === Registration ===
    User->>App: Register (email, password, name)
    App->>API: POST /v1/auth/register
    API->>API: Validate input (Zod)
    API->>DB: Check email uniqueness
    API->>DB: Insert user, hash password (argon2)
    API->>API: Generate Ed25519 keypair (if first user)
    API->>API: Sign accessToken { sub, aud, iss, exp }
    API->>API: Create rotating refreshToken (opaque 32B)
    API->>DB: Store refreshToken hash
    API-->>App: { accessToken, refreshToken, user }

    Note over User,Verifier: === Login ===
    User->>App: Login (email, password)
    App->>API: POST /v1/auth/login
    API->>DB: Lookup user by email
    API->>API: Verify password hash
    API->>API: Sign new accessToken
    API->>DB: Rotate refreshToken (invalidate old)
    API-->>App: { accessToken, refreshToken }

    Note over User,Verifier: === Token Refresh ===
    App->>API: POST /v1/auth/refresh { refreshToken }
    API->>DB: Find matching refreshToken hash
    alt Valid refresh token
        API->>DB: Rotate refreshToken
        API->>API: Sign new accessToken
        API-->>App: { accessToken, refreshToken }
    else Invalid or reused (revocation)
        API->>DB: Revoke ALL user refresh tokens
        API-->>App: 401 { error: "token_revoked" }
    end

    Note over User,Verifier: === JWKS Verification ===
    Verifier->>API: GET /.well-known/jwks.json
    API-->>Verifier: { keys: [{ kid, kty, crv, x }] }
    Verifier->>Verifier: Cache JWKS (30 min TTL)
    Verifier->>Verifier: Verify JWT signature with public key
    Verifier->>Verifier: Validate claims (iss, aud, exp, sub)
```

---

## 3. AI Analysis Flow

HMAC-protected API → n8n → OpenAI-compatible provider → response.

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Fastify API
    participant N8N as n8n Workflow
    participant AI as OpenAI-compatible Provider

    User->>App: Tap "Phân tích chi tiêu"
    App->>API: POST /v1/ai/analysis
    Note right of App: Authorization: Bearer <accessToken>
    Note right of App: Body: { query, context }

    API->>API: Validate JWT
    API->>API: Validate input (Zod)
    API->>API: Build payload { query, userId, locale }
    API->>API: Sign payload with HMAC-SHA256
    Note right of API: X-Signature-SHA256: <hex>

    API->>N8N: POST webhook (HMAC signed)
    N8N->>N8N: Verify HMAC signature
    alt HMAC mismatch
        N8N-->>API: 401 Unauthorized
        API-->>App: 502 AI service unavailable
    else HMAC valid
        N8N->>N8N: Extract query + context
        N8N->>AI: POST /v1/chat/completions
        Note right of N8N: System prompt: Vietnamese finance assistant
        Note right of N8N: Model: gpt-4o-mini (configurable)

        AI-->>N8N: { choices: [{ message: { content: "..." } }] }
        N8N->>N8N: Extract content, validate JSON
        N8N-->>API: { analysis, insights, suggestions }
        Note left of N8N: Strict JSON answer enforced

        API-->>App: { analysis, insights, suggestions }
        App->>App: Render AI analysis card
    end
```

---

## 4. Backup & Restore Flow

Encrypted backup export + secure restore with preview.

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant Privacy as PrivacyLockService
    participant Backup as FinanceBackupService
    participant Local as SQLite

    Note over User,Local: === Backup Export ===
    User->>App: Settings → Export Backup
    App->>Privacy: Re-authenticate (PIN/biometric)
    Privacy-->>App: Authenticated
    App->>Backup: exportBackup(passphrase)
    Backup->>Local: Read all finance data
    Backup->>Backup: JSON serialize
    Backup->>Backup: AES-GCM encrypt (passphrase-derived key)
    Backup-->>App: Encrypted backup file (.json.enc)
    App->>App: Share sheet (save/send)

    Note over User,Local: === Backup Restore ===
    User->>App: Settings → Restore Backup → Select file
    App->>Backup: validateBackup(file)
    alt File > 5 MB
        Backup-->>App: Error: file too large
    else Encrypted (schema v2)
        App->>User: Prompt for passphrase
        Backup->>Backup: AES-GCM decrypt
    else Plaintext (schema v1, legacy)
        Backup->>Backup: JSON parse directly
    end
    Backup->>Backup: Validate data shape (required fields)
    Backup-->>App: Preview: { walletCount, txCount, budgetCount }

    App->>User: Confirm restore (preview shown)
    User->>App: Confirm
    App->>Privacy: Re-authenticate
    Privacy-->>App: Authenticated
    App->>Backup: restoreBackup(data)
    Backup->>Local: Replace all finance tables
    Backup-->>App: Restore complete
    App->>App: Reload FinanceState
```

---

## 5. CI/CD Pipeline Flow

```mermaid
flowchart LR
    Push["git push<br/>master branch"] --> CI{CI Workflow}

    subgraph CI["GitHub Actions CI"]
        Flutter["Flutter<br/>analyze · test · build"]
        Android["Android Emulator<br/>integration smoke"]
        iOS["iOS Simulator<br/>smoke · no-codesign"]
        API_CI["API<br/>generate · typecheck · test"]
        PG["PostgreSQL<br/>migrate · seed"]
        Docker["Docker<br/>compose config · build"]
    end

    CI --> Security{Security Workflow}
    subgraph Security2["Security Scans"]
        Gitleaks["Gitleaks<br/>secret scan"]
        Trivy["Trivy<br/>fs + image scan"]
        Audit["npm audit<br/>flutter outdated"]
    end

    Security --> CodeQL[CodeQL SAST]

    CodeQL --> Publish{Docker Publish}
    subgraph Publish2["Docker Publish"]
        GHCR["ghcr.io/jasontm17/*"]
        DH["nguyenson1710/*"]
    end

    classDef pass fill:#DCFCE7,stroke:#16A34A,color:#052E16;
    classDef scan fill:#EFF6FF,stroke:#2563EB,color:#10233F;
    classDef publish fill:#FEF3C7,stroke:#D97706,color:#3A2500;
    class Flutter,Android,iOS,API_CI,PG,Docker pass;
    class Gitleaks,Trivy,Audit,CodeQL scan;
    class GHCR,DH publish;
```

---

## 6. Local-First Data Flow

```mermaid
flowchart TD
    UserAction["User creates, edits, or deletes data"] --> Controller["FinanceController<br/>command handler"]
    Controller --> Validate["Local validation<br/>money math, referential integrity"]
    Validate --> SQLite[("SQLite<br/>cashflow_manager.sqlite")]
    SQLite --> State["FinanceState<br/>rebuilt on change"]
    State --> UI["UI Rebuild"]
    UI --> Dashboard["Dashboard"]
    UI --> Transactions["Transactions"]
    UI --> Budgets["Budgets"]
    UI --> Reports["Reports"]

    State --> Derived["Derived Insights"]
    Derived --> Alerts["Budget alerts"]
    Derived --> Forecast["Cashflow forecast"]
    Derived --> Suggestions["Saving suggestions"]

    SQLite -.->|"dirty rows"| Queue["Sync Queue<br/>(optional)"]
    Queue -.->|"when account + network"| Remote["RemoteSyncClient"]
    Remote -.->|"HTTPS · JWT"| API["Fastify API"]

    classDef immediate fill:#F0FDF4,stroke:#22C55E,color:#102A18;
    classDef derived fill:#FEF9C3,stroke:#CA8A04,color:#2E2000;
    classDef optional fill:#F5F3FF,stroke:#7C3AED,color:#25114D;
    class UserAction,Controller,Validate,SQLite,State,UI,Dashboard,Transactions,Budgets,Reports immediate;
    class Derived,Alerts,Forecast,Suggestions derived;
    class Queue,Remote,API optional;
```

---

## Reading Notes

- All diagrams use Mermaid.js v11 — render in any Mermaid-compatible viewer
- For static C4 architecture diagrams, see [System Architecture](system-architecture.md)
- For screen-level flows, see [UI Flow](ui-flow.md)
- For database schema details, see [Database Schema](database-schema.md)
- Export any diagram to PNG/SVG with `mermaid-cli` or the `/ck:tech-graph` skill
