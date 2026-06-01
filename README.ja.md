# CashFlow Manager

<p align="center">
  <img src="assets/brand/cashflow-logo-mark.png" alt="CashFlow Manager ロゴ" width="96" height="96">
</p>

<p align="center">
  <strong>ベトナム語、英語、日本語に対応した offline-first の個人資産管理アプリ。</strong>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.vi.md">Tiếng Việt</a> · <a href="README.ja.md">日本語</a>
</p>

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-ready-3DDC84?logo=android&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-compose-2496ED?logo=docker&logoColor=white)
![OpenAPI](https://img.shields.io/badge/OpenAPI-3.1-6BA539?logo=openapiinitiative&logoColor=white)
![Version](https://img.shields.io/badge/version-1.0.0%2B1-16A34A)
![License](https://img.shields.io/badge/license-MIT-blue)

CashFlow Manager は Android/iOS 向け Flutter 製 offline-first 個人資産管理アプリです。支出、収入、ウォレット、予算、貯蓄目標、キャッシュフロー予測、月次レポートを管理できます。ローカル SQLite、Riverpod、PIN と任意有効化の生体認証ロック、CSV/PDF/JSON エクスポートに加え、任意で Fastify/Prisma/PostgreSQL API と n8n HMAC ワークフローも利用できます。

## デモ

![CashFlow Manager dashboard](docs/media/hero-dashboard.png)

![CashFlow Manager demo flow](docs/media/demo-cashflow-flow.gif)

| ダッシュボード | 取引 | 予算 |
|---|---|---|
| ![Dashboard screenshot](docs/media/screenshot-dashboard.png) | ![Transactions screenshot](docs/media/screenshot-transactions.png) | ![Budgets screenshot](docs/media/screenshot-wallets-budgets.png) |

| ウォレット | レポート | プライバシー設定 |
|---|---|---|
| ![Wallets screenshot](docs/media/screenshot-wallets.png) | ![Reports screenshot](docs/media/screenshot-reports.png) | ![Privacy settings screenshot](docs/media/screenshot-privacy-settings.png) |

## 主な機能

- 現在残高、月次収入、月次支出、純キャッシュフロー、チャート、最近の取引、予算アラートを表示。
- 下部ナビゲーションは Dashboard、Transactions、Wallets、Budgets、Reports の 5 タブで、取引追加と設定は app bar action として配置し、フローティングボタンで内容を覆いません。
- ウォレット、カテゴリ、日付、メモ、繰り返し、検索、フィルタ付きの収入/支出管理。
- 現金、銀行、電子ウォレット、クレジットカード対応モデルとウォレット間送金。
- 月次予算の作成/編集/削除、80% 到達や超過の警告。
- 貯蓄目標、進捗、月ごとの推奨貯蓄額。
- 月次レポート、カテゴリ別支出、上位支出、予測、CSV/PDF 共有。
- PBKDF2-HMAC-SHA256 で保護された PIN、任意で有効化する生体認証、失敗時 cooldown、アプリ離脱時の再ロック。
- JSON バックアップ/復元、プレビュー、ファイル検証、破壊的操作前の再認証。

## アーキテクチャ

```text
Flutter mobile app offline-first
  ├─ Riverpod controllers
  ├─ SQLite local finance store
  ├─ Finance calculator, export, backup, privacy lock
  └─ Optional remote sync client
        ↓ HTTPS / OpenAPI
Fastify API service
  ├─ Auth + JWKS
  ├─ Finance validation routes
  ├─ Sync bootstrap foundation
  └─ PostgreSQL persistence
        ↓ HMAC webhook
n8n automation
  └─ OpenAI-compatible chat completions workflow
```

API contract: [`docs/openapi.yaml`](docs/openapi.yaml)

## 技術スタック

- Flutter 3.44 / Dart 3.12
- Riverpod, SQLite, `fl_chart`, `local_auth`, `flutter_secure_storage`
- CSV, PDF, Printing, Share Plus, File Picker
- Fastify, Prisma, PostgreSQL 16, Docker Compose
- HMAC 検証付き n8n workflow
- Flutter/API/Docker/release artifact 向け GitHub Actions

## クイックスタート

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Backend API

```bash
npm --prefix api install
npm --prefix api run prisma:generate
npm --prefix api run typecheck
npm --prefix api test
```

Docker Desktop 利用時:

```bash
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
```

## テスト

```bash
flutter analyze
flutter test --no-pub -r expanded
flutter test --no-pub scripts/capture_demo_media_test.dart -r expanded
flutter build apk --debug
```

## リポジトリ構成

```text
api/                   # Fastify/Prisma backend
infra/n8n/             # n8n workflow import/activation
lib/app/               # Theme, localization, app setup
lib/core/              # Models, money math, export, privacy, sync DTOs
lib/data/              # SQLite local store
lib/features/home/     # Controller and main UI
scripts/               # Utilities and demo media capture
test/                  # Unit/widget tests
docs/                  # Product/technical/release docs and media
```

## リリースとパッケージ

- Android release は Windows で APK/AAB を検証します。`v1.0.0` の標準 artifact は `dist/` 内の `cashflow-manager-v1.0.0-android.apk` と `cashflow-manager-v1.0.0-android.aab` です。
- iOS archive には macOS/Xcode/Swift が必要で、Windows で archive 済みとは記載しません。
- Docker publish は Docker Hub を維持し、GitHub Packages/GHCR にも mirror します: `ghcr.io/jasontm17/cashflow-manager-api` と `ghcr.io/jasontm17/cashflow-manager-frontend`。release tag では `latest`、git SHA、semver tag を使います。
- GitHub About の homepage は、実際の公開 release/download ページができるまで `https://github.com/JasonTM17/Money_Management_App#readme` を使います。
## プライバシー

金融データは local-first です。PIN は常に fallback として残り、生体認証はユーザーが任意で有効化します。Secrets、`.env*`、署名キー、ローカル DB、本物の backup、private agent folders、internal planning notes は commit しません。n8n/API の token は local env または deployment secrets で管理します。

## 現在の制限

- Production cloud sync はまだありません。アプリは offline-first のままで、account/sync server は別 rollout のための foundation です。
- Supabase/Firebase sync は MVP scope 外。
- レシート OCR は次の製品フェーズで扱う local-first 機能です。
- iOS release archive には macOS/Xcode が必要。
