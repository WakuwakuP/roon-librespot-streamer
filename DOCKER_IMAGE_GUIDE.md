# Docker イメージ構成ガイド / Docker Image Structure Guide

このドキュメントでは、roon-librespot-streamerのDockerイメージの構造と構成方法について詳しく説明します。

This document provides detailed information about the structure and configuration of the roon-librespot-streamer Docker image.

## 📋 目次 / Table of Contents

1. [イメージ構成の概要](#イメージ構成の概要--image-structure-overview)
2. [ビルドオプション](#ビルドオプション--build-options)
3. [ファイル構造](#ファイル構造--file-structure)
4. [ビルドプロセス](#ビルドプロセス--build-process)
5. [実行時の設定](#実行時の設定--runtime-configuration)
6. [最適化とベストプラクティス](#最適化とベストプラクティス--optimization-and-best-practices)

## イメージ構成の概要 / Image Structure Overview

### レイヤー構造 / Layer Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    Final Docker Image                           │
│                   (debian:bullseye-slim)                        │
│                                                                 │
│  Runtime Binaries:                                              │
│  ├── /usr/local/bin/librespot          (from rust builder)     │
│  ├── /usr/local/bin/streaming-server   (from go builder)       │
│  ├── /usr/local/bin/entrypoint.sh      (from source)          │
│  └── /stream-mixer.py                  (from source)          │
│                                                                 │
│  Runtime Dependencies:                                          │
│  ├── libasound2                        (ALSA libraries)       │
│  ├── ffmpeg                            (Audio conversion)     │
│  ├── python3                           (Stream mixer)         │
│  └── ca-certificates                   (SSL/TLS)              │
│                                                                 │
│  User & Directories:                                            │
│  ├── User: librespot (non-root)                               │
│  ├── /home/librespot (working directory)                      │
│  ├── /cache (volume for librespot cache)                      │
│  └── /config (configuration files)                            │
│                                                                 │
│  Exposed Ports:                                                 │
│  ├── 57500 (Spotify Connect / mDNS)                           │
│  └── 8080  (HTTP Streaming)                                   │
└─────────────────────────────────────────────────────────────────┘
        ▲                           ▲
        │                           │
┌───────┴────────┐         ┌────────┴─────────┐
│  Go Builder    │         │  Rust Builder     │
│  (golang:1.21) │         │  (rust:1.85)      │
│                │         │                   │
│  Builds:       │         │  Builds:          │
│  - HTTP Server │         │  - librespot      │
│    (optimized) │         │    (from source)  │
└────────────────┘         └───────────────────┘
```

## ビルドオプション / Build Options

### 1. デフォルトビルド / Default Build (推奨 / Recommended)

**ファイル**: `Dockerfile`

**特徴 / Features**:
- ✅ 高速ビルド (~30秒)
- ✅ 事前ビルド済みlibrespotバイナリを使用
- ✅ x86_64とaarch64をサポート
- ⚠️ ネットワークアクセスが必要

**使用方法 / Usage**:
```bash
docker build -t roon-librespot-streamer .
```

**適用シナリオ / Use Cases**:
- 本番環境での使用
- CI/CDパイプライン（ネットワークアクセス可能な場合）
- 一般的なx86_64またはaarch64システム

### 2. ソースからビルド / Build from Source

**ファイル**: `Dockerfile.build-from-source`

**特徴 / Features**:
- ✅ 最大の互換性
- ✅ すべてのアーキテクチャをサポート
- ✅ カスタマイズ可能
- ⚠️ ビルド時間が長い (~15-30分)
- ⚠️ より多くのディスク容量とメモリが必要

**使用方法 / Usage**:
```bash
docker build -f Dockerfile.build-from-source -t roon-librespot-streamer .
```

**適用シナリオ / Use Cases**:
- 非標準アーキテクチャ
- librespotの機能カスタマイズ
- SSL証明書の問題がある環境
- オフライン環境（Gitリポジトリのミラーが必要）

### 比較表 / Comparison Table

| 項目 / Feature | デフォルト / Default | ソースから / From Source |
|---|---|---|
| ビルド時間 / Build Time | ~30秒 / ~30s | ~15-30分 / ~15-30min |
| イメージサイズ / Image Size | ~350 MB | ~350 MB |
| アーキテクチャ / Architecture | x86_64, aarch64 | All Rust-supported |
| ネットワーク要件 / Network | Required | Git access only |
| カスタマイズ性 / Customization | Limited | Full |
| 推奨用途 / Recommended For | Production | Special requirements |

## ファイル構造 / File Structure

### プロジェクトファイル / Project Files

```
roon-librespot-streamer/
│
├── 📄 Dockerfile                    # デフォルトビルド定義
├── 📄 Dockerfile.build-from-source  # ソースビルド定義
├── 📄 docker-compose.yml            # Docker Compose設定
├── 📄 .dockerignore                 # Docker除外ファイル
│
├── 📄 entrypoint.sh                 # コンテナエントリポイント
├── 📄 stream-mixer.py               # 音声ストリーム連続性保証
│
├── 📁 streaming-server/             # Go HTTPサーバー
│   ├── main.go                      # サーバー実装
│   └── go.mod                       # Go依存関係
│
├── 📄 README.md                     # プロジェクト概要
├── 📄 ARCHITECTURE.md               # アーキテクチャ詳細
├── 📄 SYSTEM_COMPONENTS.md          # システムコンポーネント解説
├── 📄 GETTING_STARTED.md            # 初心者ガイド
├── 📄 HTTP_STREAMING_GUIDE.md       # HTTPストリーミングガイド
└── 📄 DOCKER_IMAGE_GUIDE.md         # このファイル
```

### コンテナ内のファイル配置 / Container File Layout

```
/
├── usr/local/bin/
│   ├── librespot              # Spotify Connectクライアント
│   ├── streaming-server       # HTTP streaming server (Go)
│   └── entrypoint.sh          # 起動スクリプト
│
├── stream-mixer.py            # ストリームミキサー (Python)
│
├── home/librespot/            # 非rootユーザーのホーム
│   └── (working directory)
│
├── cache/                     # librespotキャッシュ (volume)
│   └── (Spotify cache data)
│
├── config/                    # 設定ファイル (optional)
│   └── credentials.json       # Spotify認証情報 (optional)
│
└── tmp/audio/                 # 実行時作成
    └── librespot.pcm          # Named pipe (PCM audio)
```

## ビルドプロセス / Build Process

### Multi-stage Build の詳細

#### Stage 1: Go Builder

```dockerfile
FROM golang:1.21-bullseye AS go-builder
WORKDIR /build
COPY streaming-server/ ./
RUN go build -ldflags="-s -w" -o streaming-server main.go
```

**実行内容**:
1. Go 1.21環境を準備
2. streaming-serverのソースをコピー
3. 最適化フラグ付きでビルド:
   - `-s`: シンボルテーブル削除
   - `-w`: DWARFデバッグ情報削除
   - 結果: バイナリサイズ削減 (~50%)

**出力**: `/build/streaming-server` (約5-8 MB)

#### Stage 2: Rust Builder

**オプションA: デフォルトビルド (Dockerfile)**
```dockerfile
FROM rust:1.85-bullseye AS builder
# 事前ビルド済みバイナリをダウンロード
RUN curl -L https://github.com/.../librespot -o /usr/local/bin/librespot
```

**オプションB: ソースビルド (Dockerfile.build-from-source)**
```dockerfile
FROM rust:1.85-bullseye AS builder
RUN git clone https://github.com/librespot-org/librespot.git && \
    cd librespot && \
    git checkout 3eca1ab && \
    cargo build --release \
        --no-default-features \
        --features "alsa-backend,with-libmdns,native-tls"
```

**実行内容**:
1. Rust 1.85環境を準備
2. 必要なビルド依存関係をインストール
3. librespotをクローン
4. 特定のコミット (3eca1ab) をチェックアウト
5. 必要な機能のみを有効化してビルド:
   - `alsa-backend`: ALSAオーディオ出力
   - `with-libmdns`: mDNS discovery
   - `native-tls`: TLS暗号化

**出力**: `/build/librespot/target/release/librespot` (約10-15 MB)

#### Stage 3: Final Image

```dockerfile
FROM debian:bullseye-slim

# ランタイム依存関係のみをインストール
RUN apt-get update && apt-get install -y \
    libasound2 \
    ffmpeg \
    alsa-utils \
    ca-certificates \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# ビルド成果物をコピー
COPY --from=builder /build/librespot/target/release/librespot /usr/local/bin/
COPY --from=go-builder /build/streaming-server /usr/local/bin/

# スクリプトをコピー
COPY entrypoint.sh /usr/local/bin/
COPY stream-mixer.py /stream-mixer.py

# 非rootユーザーを作成
RUN useradd -m -s /bin/bash librespot
RUN mkdir -p /config /cache && chown -R librespot:librespot /config /cache

USER librespot
WORKDIR /home/librespot
```

**実行内容**:
1. 最小限のDebianベースイメージから開始
2. ランタイムに必要なパッケージのみをインストール
3. ビルド済みバイナリをコピー
4. セキュリティのため非rootユーザーとして実行
5. 必要なディレクトリを作成・権限設定

### ビルド最適化 / Build Optimizations

#### レイヤーキャッシング / Layer Caching

Docker Buildxを使用すると、変更されていないレイヤーが再利用されます:

```bash
# キャッシュを有効化してビルド
docker buildx build --cache-from type=local,src=/tmp/.buildx-cache \
                    --cache-to type=local,dest=/tmp/.buildx-cache \
                    -t roon-librespot-streamer .
```

#### マルチプラットフォームビルド / Multi-platform Build

```bash
# ARM64とAMD64の両方をビルド
docker buildx build --platform linux/amd64,linux/arm64 \
                    -t username/roon-librespot-streamer:latest \
                    --push .
```

## 実行時の設定 / Runtime Configuration

### 環境変数 / Environment Variables

完全なリストは[README.md](README.md#configuration)を参照してください。

See [README.md](README.md#configuration) for the complete list.

#### 必須設定 / Essential Configuration

```yaml
environment:
  # デバイス名（Spotify Connectに表示）
  - DEVICE_NAME=Roon Librespot FLAC Streamer
  
  # ビットレート（96, 160, 320）
  - BITRATE=320
  
  # バックエンド（pipe または alsa）
  - BACKEND=pipe
  
  # HTTPポート
  - HTTP_PORT=8080
```

#### ログ設定 / Logging Configuration

```yaml
environment:
  # デフォルト: 警告レベル、mDNS/MP3警告は抑制
  - RUST_LOG=warn,libmdns=error,symphonia_bundle_mp3=error
  
  # 詳細ログ: すべての情報を表示
  - RUST_LOG=info
  
  # デバッグログ: トラブルシューティング用
  - RUST_LOG=debug
```

### ボリュームマウント / Volume Mounts

#### キャッシュボリューム / Cache Volume (推奨 / Recommended)

```yaml
volumes:
  - librespot-cache:/cache
```

- **目的**: Spotifyキャッシュを永続化してパフォーマンス向上
- **サイズ**: 環境変数 `CACHE_SIZE_LIMIT` で制御 (デフォルト: 1GB)

#### 認証情報ファイル / Credentials File (オプション / Optional)

```yaml
volumes:
  - ./credentials.json:/config/credentials.json:ro
```

- **目的**: Spotify認証情報の永続化
- **推奨**: Spotify Connectを使用する方が簡単

### ネットワーク設定 / Network Configuration

#### Host Network (推奨 / Recommended)

```yaml
network_mode: host
```

**理由 / Reason**:
- mDNS discoveryに必要
- Spotify Connectが自動的にデバイスを検出
- ファイアウォール設定が簡単

#### Bridge Network (代替 / Alternative)

```yaml
ports:
  - "57500:57500"  # Spotify Connect
  - "8080:8080"    # HTTP Streaming
```

**注意 / Note**: 
- mDNS discoveryが機能しない可能性
- 追加の設定が必要

### 特殊ホスト設定 / Special Host Configuration

```yaml
extra_hosts:
  - "apresolve.spotify.com:0.0.0.0"
```

**目的 / Purpose**: 
- audio key errorを修正
- librespotがハードコードされたAPIエンドポイントを使用するよう強制
- 詳細: [librespot issue #1649](https://github.com/librespot-org/librespot/issues/1649)

## 最適化とベストプラクティス / Optimization and Best Practices

### 1. イメージサイズの最適化 / Image Size Optimization

#### 現在の最適化 / Current Optimizations

✅ Multi-stage buildを使用してビルドツールを除外
✅ 最小限のベースイメージ (debian:bullseye-slim)
✅ ビルド時に最適化フラグを使用 (`-s -w` for Go, `--release` for Rust)
✅ apt-get clean と不要なファイル削除

#### さらなる改善案 / Further Improvements

```dockerfile
# Alpine Linuxベースイメージ（実験的）
FROM alpine:latest
# より小さいイメージサイズ (~50-100 MB削減)
# ただし、互換性の問題が発生する可能性
```

### 2. ビルド速度の最適化 / Build Speed Optimization

#### キャッシュの活用 / Cache Utilization

```dockerfile
# 依存関係を先にコピー
COPY go.mod go.sum ./
RUN go mod download

# その後ソースコードをコピー
COPY . .
RUN go build
```

#### 並列ビルド / Parallel Builds

```bash
# Rustのビルドジョブ数を指定
cargo build --release -j 4
```

### 3. セキュリティのベストプラクティス / Security Best Practices

#### ✅ 実装済み / Already Implemented

- 非rootユーザーとして実行
- 最小限の依存関係
- 定期的な依存関係の更新
- 特定のコミットハッシュを使用（再現性）

#### 推奨事項 / Recommendations

```bash
# 定期的にベースイメージを更新
docker pull debian:bullseye-slim

# セキュリティスキャン
docker scan roon-librespot-streamer

# 脆弱性チェック
trivy image roon-librespot-streamer
```

### 4. パフォーマンスチューニング / Performance Tuning

#### コンテナリソース制限 / Container Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
    reservations:
      cpus: '0.5'
      memory: 256M
```

#### FFmpeg最適化 / FFmpeg Optimization

```bash
# entrypoint.shでFFmpegのスレッド数を指定
ffmpeg -threads 2 -f s16le -ar 44100 -ac 2 -i - \
    -c:a flac -compression_level 5 -f flac pipe:1
```

### 5. モニタリングとログ / Monitoring and Logging

#### ヘルスチェック / Health Check

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

#### ログの集約 / Log Aggregation

```bash
# JSON形式でログを出力
docker logs --timestamps roon-librespot-streamer

# ログドライバーを使用
docker run --log-driver=json-file \
           --log-opt max-size=10m \
           --log-opt max-file=3 \
           roon-librespot-streamer
```

## 🔧 カスタマイズ例 / Customization Examples

### カスタムlibrespotビルド / Custom librespot Build

```dockerfile
# Dockerfile.custom
FROM rust:1.85-bullseye AS builder

# 追加機能を有効化
RUN cargo build --release \
    --no-default-features \
    --features "alsa-backend,with-libmdns,native-tls,pulseaudio-backend"
```

### カスタムストリーミングサーバー / Custom Streaming Server

```go
// streaming-server/main.go
const (
    maxClients = 20  // クライアント数を増やす
    bufferSize = 16384  // バッファサイズを倍増
)
```

### 複数インスタンスのデプロイ / Multiple Instance Deployment

```yaml
# docker-compose.multi.yml
services:
  streamer-room1:
    build: .
    environment:
      - DEVICE_NAME=Room 1 Streamer
      - HTTP_PORT=8081
    network_mode: host
  
  streamer-room2:
    build: .
    environment:
      - DEVICE_NAME=Room 2 Streamer
      - HTTP_PORT=8082
    network_mode: host
```

## 📊 トラブルシューティング / Troubleshooting

### ビルドエラー / Build Errors

#### 問題: SSL証明書エラー

```
error: failed to fetch `https://github.com/...`
SSL certificate problem
```

**解決策 / Solution**:
```bash
# ソースビルドを使用
docker build -f Dockerfile.build-from-source -t roon-librespot-streamer .
```

#### 問題: メモリ不足

```
error: could not compile `librespot`
Killed (signal 9)
```

**解決策 / Solution**:
```bash
# Dockerにより多くのメモリを割り当て
# Docker Desktop: Settings → Resources → Memory: 4GB以上

# または、事前ビルド済みバイナリを使用
docker build -t roon-librespot-streamer .
```

### 実行時エラー / Runtime Errors

#### 問題: デバイスが見つからない

**チェック項目 / Checklist**:
1. ✅ `network_mode: host` が設定されているか
2. ✅ ファイアウォールがポート57500を許可しているか
3. ✅ 同じネットワークに接続されているか

#### 問題: 音声が再生されない

```bash
# コンテナログを確認
docker logs roon-librespot-streamer

# FFmpegエラーを確認
docker exec roon-librespot-streamer cat /tmp/ffmpeg-error.log

# HTTPサーバーの状態を確認
curl http://localhost:8080/health
```

## 📚 関連リソース / Related Resources

- [Docker公式ドキュメント](https://docs.docker.com/)
- [Docker Compose リファレンス](https://docs.docker.com/compose/compose-file/)
- [librespot GitHub](https://github.com/librespot-org/librespot)
- [Go公式ドキュメント](https://golang.org/doc/)
- [FFmpeg ドキュメント](https://ffmpeg.org/documentation.html)

## 🎓 まとめ / Summary

このDockerイメージは以下の設計原則に基づいて構築されています:

This Docker image is built based on the following design principles:

1. **モジュール性 / Modularity**: 各コンポーネントは独立して更新可能
2. **セキュリティ / Security**: 非rootユーザー、最小限の依存関係
3. **パフォーマンス / Performance**: Multi-stage build、最適化されたバイナリ
4. **柔軟性 / Flexibility**: 環境変数による簡単な設定
5. **堅牢性 / Robustness**: エラーハンドリング、自動再接続

すべてのコンポーネントが適切に整理され、本番環境での使用に適した構成となっています。

All components are properly organized and the configuration is suitable for production use.
