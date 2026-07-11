# Deployment Guide / Hướng dẫn triển khai / デプロイガイド

## English

### Prerequisites
- Docker Desktop
- Android Studio for APK builds
- Flutter 3.44
- Docker Hub account

### Quick Deploy with Docker Compose

```bash
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
```

### Production Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| DATABASE_URL | Yes | PostgreSQL connection string |
| JWT_PRIVATE_KEY | Yes | Ed25519 private key (PEM) |
| JWT_PUBLIC_KEY | Yes | Ed25519 public key (PEM) |
| API_HOST_PORT | No | Host port for API (default: 3000) |
| FRONTEND_HOST_PORT | No | Host port for frontend (default: 8080) |

### Docker Hub Publishing

The Docker Publish workflow is configured to publish these Docker Hub images from `master` when Actions capacity and registry secrets are available:
- `nguyenson1710/cashflow-manager-api:latest`
- `nguyenson1710/cashflow-manager-frontend:latest`

If GitHub Actions quota/token is exhausted, Docker Hub/GHCR publishing is deferred. Keep local Docker builds as temporary evidence and rerun Docker Publish after Actions capacity is restored.

### Deployment Checklist
1. Verify `.env.production` is configured
2. Run `docker compose up --build -d`
3. Verify `/healthz` returns 200
4. Verify `/readyz` returns 200
5. Verify `/.well-known/jwks.json` returns valid JWKS

## Tiếng Việt

### Yêu cầu
- Docker Desktop
- Android Studio để build APK
- Flutter 3.44
- Tài khoản Docker Hub

### Triển khai nhanh

```bash
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
```

### Biến môi trường Production

| Biến | Bắt buộc | Mô tả |
|------|----------|-------|
| DATABASE_URL | Có | Chuỗi kết nối PostgreSQL |
| JWT_PRIVATE_KEY | Có | Khóa riêng Ed25519 (PEM) |
| JWT_PUBLIC_KEY | Có | Khóa công khai Ed25519 (PEM) |
| API_HOST_PORT | Không | Cổng host cho API (mặc định: 3000) |
| FRONTEND_HOST_PORT | Không | Cổng host cho frontend (mặc định: 8080) |

### Checklist triển khai
1. Cấu hình `.env.production`
2. Chạy `docker compose up --build -d`
3. Kiểm tra `/healthz` trả về 200
4. Kiểm tra `/readyz` trả về 200
5. Kiểm tra `/.well-known/jwks.json` hợp lệ

Nếu quota/token GitHub Actions đã hết, việc publish Docker Hub/GHCR sẽ tạm hoãn. Giữ bằng chứng build Docker local và chạy lại Docker Publish sau khi Actions hoạt động lại.

## 日本語

### 前提条件
- Docker Desktop
- Android Studio (APKビルド用)
- Flutter 3.44
- Docker Hub アカウント

### クイックデプロイ

```bash
docker compose up --build -d postgres
docker compose --profile tools run --rm --build migrate
docker compose --profile tools run --rm --build seed
docker compose up --build -d api frontend
```

### 本番環境変数

| 変数 | 必須 | 説明 |
|------|------|------|
| DATABASE_URL | はい | PostgreSQL接続文字列 |
| JWT_PRIVATE_KEY | はい | Ed25519秘密鍵 (PEM) |
| JWT_PUBLIC_KEY | はい | Ed25519公開鍵 (PEM) |
| API_HOST_PORT | いいえ | APIのホストポート (デフォルト: 3000) |
| FRONTEND_HOST_PORT | いいえ | フロントエンドのホストポート (デフォルト: 8080) |

### デプロイチェックリスト
1. `.env.production` を設定
2. `docker compose up --build -d` を実行
3. `/healthz` が200を返すことを確認
4. `/readyz` が200を返すことを確認
5. `/.well-known/jwks.json` が有効なJWKSを返すことを確認

GitHub Actions の quota/token が不足している場合、Docker Hub/GHCR への publish は保留です。ローカル Docker build の結果を一時的な証跡として残し、Actions 復旧後に Docker Publish を再実行してください。
