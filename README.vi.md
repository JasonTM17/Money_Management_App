# CashFlow Manager

<p align="center">
  <img src="assets/brand/cashflow-logo-mark.png" alt="Logo CashFlow Manager" width="96" height="96">
</p>

<p align="center">
  <strong>Ứng dụng quản lý tài chính cá nhân offline-first cho tiếng Việt, English và 日本語.</strong>
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

CashFlow Manager là app Flutter offline-first cho Android/iOS, giúp quản lý số dư, thu chi, ví, ngân sách, mục tiêu tiết kiệm, dự báo dòng tiền và báo cáo tháng. App dùng SQLite cục bộ, Riverpod, khóa PIN và sinh trắc học opt-in, xuất CSV/PDF/backup JSON, kèm nền tảng API Fastify/Prisma/PostgreSQL và workflow n8n HMAC tùy chọn.

## Demo

![Dashboard CashFlow Manager](docs/media/hero-dashboard.png)

![Luồng demo CashFlow Manager](docs/media/demo-cashflow-flow.gif)

| Tổng quan | Giao dịch | Ngân sách |
|---|---|---|
| ![Ảnh tổng quan](docs/media/screenshot-dashboard.png) | ![Ảnh giao dịch](docs/media/screenshot-transactions.png) | ![Ảnh ngân sách](docs/media/screenshot-wallets-budgets.png) |

| Ví | Báo cáo | Cài đặt riêng tư |
|---|---|---|
| ![Ảnh ví](docs/media/screenshot-wallets.png) | ![Ảnh báo cáo](docs/media/screenshot-reports.png) | ![Ảnh cài đặt](docs/media/screenshot-privacy-settings.png) |

## Tính năng chính

- Dashboard hiển thị tổng số dư, thu tháng này, chi tháng này, dòng tiền ròng, biểu đồ, giao dịch gần đây và cảnh báo ngân sách.
- Năm tab dưới cùng gồm Tổng quan, Giao dịch, Ví, Ngân sách và Báo cáo; app bar giữ hành động Thêm giao dịch và Cài đặt, không dùng nút nổi che nội dung.
- Quản lý giao dịch thu/chi với ví, danh mục, ngày, ghi chú, lặp lại, tìm kiếm và bộ lọc.
- Quản lý ví tiền mặt, ngân hàng, ví điện tử, thẻ tín dụng và chuyển tiền giữa ví.
- Tạo/sửa/xóa ngân sách tháng, cảnh báo khi gần hoặc vượt hạn mức.
- Mục tiêu tiết kiệm với tiến độ và gợi ý số tiền cần tiết kiệm mỗi tháng.
- Báo cáo tháng với biểu đồ thu/chi, chi tiêu theo danh mục, top chi tiêu, dự báo, CSV và PDF.
- Khóa riêng tư bằng PIN đã hash PBKDF2-HMAC-SHA256, sinh trắc học opt-in, cooldown khi sai PIN, relock khi app rời foreground.
- Backup/restore JSON có preview, giới hạn file, mã hóa v2 bằng passphrase và xác thực lại trước khi thay dữ liệu; import JSON legacy v1 vẫn được hỗ trợ.

## Kiến trúc

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

## Công nghệ

- Flutter 3.44 / Dart 3.12
- Riverpod, SQLite, `fl_chart`, `local_auth`, `flutter_secure_storage`
- CSV, PDF, Printing, Share Plus, File Picker
- Fastify, Prisma, PostgreSQL 16, Docker Compose
- n8n workflow có HMAC verification
- GitHub Actions cho Flutter, Android emulator smoke, iOS simulator/no-codesign validation, API, Docker, release artifact

## Chạy nhanh

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

Với Docker Desktop:

```bash
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
```

## Kiểm thử

```bash
flutter analyze
flutter test --no-pub -r expanded
flutter test --no-pub integration_test/cashflow_smoke_test.dart -d <device-id> -r expanded
flutter test --no-pub scripts/capture_demo_media_test.dart -r expanded
flutter build apk --debug
```

## Cấu trúc repo

```text
api/                   # Fastify/Prisma backend
infra/n8n/             # Workflow n8n import/activation
lib/app/               # Theme, localization, app setup
lib/core/              # Models, money math, export, privacy, sync DTOs
lib/data/              # SQLite local store
lib/features/home/     # Controller và UI chính
scripts/               # Utility scripts và capture demo media
test/                  # Unit/widget tests
docs/                  # Product/technical/release docs và media
```

## Release và package

- GitHub Release `v1.0.0` đã publish tại `https://github.com/JasonTM17/Money_Management_App/releases/tag/v1.0.0` với APK `cashflow-manager-v1.0.0-android.apk` và App Bundle `cashflow-manager-v1.0.0-android.aab`; release workflow mới sẽ attach SBOM/checksum ở lần chạy tagged release tiếp theo.
- iOS simulator/no-codesign validation cần macOS/Xcode/Swift; signed archive/IPA cần Apple signing assets và không claim là đã build trên Windows.
- Docker publish workflow đã publish GHCR public manifests cho `ghcr.io/jasontm17/cashflow-manager-api:1.0.0` và `ghcr.io/jasontm17/cashflow-manager-frontend:1.0.0`; release builds cũng có tag `v1.0.0`, git SHA và `latest`. Docker Hub `latest` manifests cho `nguyenson1710/cashflow-manager-api` và `nguyenson1710/cashflow-manager-frontend` đã verify.
- GitHub About để homepage trống cho tới khi có trang release/download công khai riêng.
## Ghi chú riêng tư

Dữ liệu tài chính là local-first. PIN luôn là fallback, sinh trắc học chỉ bật khi người dùng opt-in. Không commit secrets, `.env*`, signing key, database local, backup thật, private agent folders hoặc internal planning notes. n8n/API chỉ dùng token qua local env hoặc deployment secrets.

## Giới hạn hiện tại

- UI tạo tài khoản/đồng bộ trên mobile chưa nối vào sync push/change phía server.
- Supabase/Firebase sync ngoài scope MVP.
- OCR hóa đơn vẫn là phần local-first cho phase sản phẩm kế tiếp.
- iOS release archive cần macOS/Xcode.
