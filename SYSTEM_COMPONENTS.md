# システム構成要素 / System Components

このドキュメントは、roon-librespot-streamerのDockerイメージに含まれるすべてのコンポーネントと、それらがどのように連携しているかを説明します。

This document explains all components included in the roon-librespot-streamer Docker image and how they work together.

## 📦 コンポーネント一覧 / Component List

### 1. 🎵 librespot
**役割 / Role**: Spotify Connectクライアント

**説明 / Description**:
- SpotifyのオフィシャルAPIを使用してSpotify Connectプロトコルを実装
- Spotifyアプリから音声ストリームを受信
- PCM (Pulse Code Modulation) 形式で音声を出力

**バージョン / Version**: 
- Version: v0.8.0 (stable)
- Release Date: 2024

**機能 / Features**:
- Spotify Connectデバイスとして表示
- 高品質音声ストリーミング (最大320kbps)
- キャッシュによるパフォーマンス向上
- 音量制御とノーマライゼーション

### 2. 🔄 stream-mixer.py
**役割 / Role**: 音声ストリーム連続性の保証

**説明 / Description**:
- librespotの出力を監視し、無音を挿入することで連続的なストリームを維持
- librespotがアイドル状態またはエラー時でもクライアントのタイムアウトを防止
- 名前付きパイプからの読み取りをタイムアウト付きで処理

**技術詳細 / Technical Details**:
- 言語: Python 3
- 入力: Named pipe (s16le PCM, 44.1kHz, stereo)
- 出力: stdout (continuous PCM stream)
- タイムアウト処理: 0.1秒ごとにチェック

**主な機能 / Key Features**:
- 音声データがある時: リアルタイムで転送
- 音声データがない時: 無音 (0x00) を生成して送信
- パイプエラー時: 自動再接続とシームレスな復帰
- ログ出力: stderr経由で音声ストリームを汚染しない

### 3. 🎬 ffmpeg
**役割 / Role**: 音声フォーマット変換

**説明 / Description**:
- PCM音声をFLAC形式に変換
- ロスレス圧縮により音質を維持
- リアルタイムストリーミングに最適化

**設定 / Configuration**:
- 入力: PCM s16le, 44.1kHz, stereo
- 出力: FLAC, compression level 5
- フォーマット: FLAC container via pipe

### 4. 🌐 HTTP Streaming Server (Go)
**役割 / Role**: HTTPストリーミング配信

**説明 / Description**:
- 軽量で高性能なHTTPサーバー
- FLAC音声をHTTP経由で複数クライアントに配信
- Icecast2互換ヘッダーでRoon統合を実現

**技術詳細 / Technical Details**:
- 言語: Go 1.21+
- 最大同時接続数: 10クライアント
- タイムアウト: 30秒
- バッファサイズ: 8192バイト

**エンドポイント / Endpoints**:
- `GET /stream` - FLAC音声ストリーム
- `GET /` - Webインターフェース (使用方法と状態表示)
- `GET /health` - ヘルスチェック (JSON)

**Icecast互換ヘッダー / Icecast-compatible Headers**:
- `icy-name`: ストリーム名
- `icy-genre`: ジャンル
- `icy-url`: 情報URL
- `icy-br`: ビットレート (1411 kbps for FLAC)
- `icy-description`: ストリーム説明

## 🔗 データフロー / Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Docker Container                              │
│                                                                         │
│  ┌──────────┐                                                          │
│  │ Spotify  │ (Ogg Vorbis, up to 320kbps)                             │
│  │   App    │                                                          │
│  └────┬─────┘                                                          │
│       │ Spotify Connect Protocol                                       │
│       ▼                                                                 │
│  ┌──────────────┐                                                      │
│  │  librespot   │                                                      │
│  │              │                                                      │
│  │ - Receives   │                                                      │
│  │   Spotify    │                                                      │
│  │   stream     │                                                      │
│  │ - Decodes to │                                                      │
│  │   PCM        │                                                      │
│  └──────┬───────┘                                                      │
│         │ PCM (s16le, 44.1kHz, stereo)                                 │
│         ▼                                                               │
│  ┌──────────────┐                                                      │
│  │ Named Pipe   │                                                      │
│  │ /tmp/audio/  │                                                      │
│  │ librespot.pcm│                                                      │
│  └──────┬───────┘                                                      │
│         │                                                               │
│         ▼                                                               │
│  ┌───────────────┐                                                     │
│  │stream-mixer.py│                                                     │
│  │               │                                                     │
│  │ - Reads from  │                                                     │
│  │   pipe with   │                                                     │
│  │   timeout     │                                                     │
│  │ - Injects     │                                                     │
│  │   silence when│                                                     │
│  │   needed      │                                                     │
│  │ - Ensures     │                                                     │
│  │   continuous  │                                                     │
│  │   stream      │                                                     │
│  └──────┬────────┘                                                     │
│         │ Continuous PCM stream                                        │
│         ▼                                                               │
│  ┌──────────────┐                                                      │
│  │    ffmpeg    │                                                      │
│  │              │                                                      │
│  │ - Converts   │                                                      │
│  │   PCM to FLAC│                                                      │
│  │ - Compression│                                                      │
│  │   level: 5   │                                                      │
│  └──────┬───────┘                                                      │
│         │ FLAC stream                                                  │
│         ▼                                                               │
│  ┌──────────────────┐                                                  │
│  │ HTTP Streaming   │                                                  │
│  │ Server (Go)      │                                                  │
│  │                  │                                                  │
│  │ - Broadcasts to  │                                                  │
│  │   multiple       │                                                  │
│  │   clients        │                                                  │
│  │ - Icecast headers│                                                  │
│  │ - Web interface  │                                                  │
│  └──────┬───────────┘                                                  │
│         │ HTTP on port 8080                                            │
└─────────┼──────────────────────────────────────────────────────────────┘
          │
          ▼
    ┌─────────────────────────┐
    │  http://{IP}:8080/      │
    │                         │
    │  • /stream - FLAC audio │
    │  • / - Web interface    │
    │  • /health - Status API │
    └─────────────────────────┘
          │
          ├──► VLC, mpv, ffplay (メディアプレイヤー / Media Players)
          ├──► Webブラウザ (Web Browsers)
          └──► Roon (Internet Radio)
```

## 🏗️ Docker イメージ構造 / Docker Image Structure

### Multi-stage Build

Dockerイメージは3つのステージで構築されます:

The Docker image is built in 3 stages:

#### Stage 1: Go Builder
```dockerfile
FROM golang:1.21-bullseye AS go-builder
```
- Go HTTP streaming serverをビルド
- 最適化フラグ: `-ldflags="-s -w"` (バイナリサイズ削減)

#### Stage 2: Rust Builder
```dockerfile
FROM rust:1.85-bullseye AS builder
```
- librespotをソースからビルド（build-from-sourceの場合）
- または事前ビルド済みバイナリをダウンロード（デフォルト）
- 必要な機能のみを有効化: `alsa-backend`, `with-libmdns`, `native-tls`

#### Stage 3: Final Image
```dockerfile
FROM debian:bullseye-slim
```
- ランタイム依存関係のみをインストール
- 非rootユーザー (`librespot`) として実行
- 必要なバイナリとスクリプトのみをコピー

### イメージサイズの最適化 / Image Size Optimization

- Multi-stage buildによりビルドツールを最終イメージから除外
- 最小限のランタイム依存関係
- 圧縮されたバイナリ

## 🔧 起動プロセス / Startup Process

### entrypoint.sh の処理フロー

1. **環境変数の読み込み**
   - デバイス名、ビットレート、ボリューム設定など
   - デフォルト値の設定

2. **Pipe Backendの場合**:
   a. 出力ディレクトリ作成 (`/tmp/audio`)
   b. 名前付きパイプ作成 (`mkfifo`)
   c. HTTPストリーミングサーバー起動（バックグラウンド）
      - stream-mixer.py がパイプから読み取り
      - ffmpeg が PCM を FLAC に変換
      - streaming-server が HTTP 配信
   d. パイプラインの初期化待機（デフォルト3秒）
   e. librespot 起動

3. **ALSA Backendの場合**:
   - 直接ALSAデバイスに出力
   - HTTPストリーミングなし

4. **シグナルハンドリング**
   - SIGTERM/SIGINT で適切にクリーンアップ
   - プロセス終了時にパイプファイル削除

## 📊 リソース使用量 / Resource Usage

### メモリ / Memory
- librespot: ~50-100 MB
- stream-mixer.py: ~10-20 MB
- ffmpeg: ~20-50 MB
- HTTP streaming server: ~5-10 MB
- **合計 / Total**: ~100-200 MB

### CPU
- アイドル時: ~1-5%
- 音声再生時: ~10-20% (FLAC変換による)
- ピーク時: ~30%

### ディスク / Disk
- Docker イメージ: ~300-400 MB
- キャッシュ: 設定可能 (デフォルト 1GB)

### ネットワーク / Network
- Spotify → librespot: 最大320 kbps
- HTTP streaming: ~1.4 Mbps per client (FLAC)

## 🔐 セキュリティ / Security

### 非rootユーザー / Non-root User
- すべてのプロセスを `librespot` ユーザーとして実行
- 最小権限の原則に従う

### ネットワーク分離 / Network Isolation
- 必要なポートのみ公開:
  - 57500: Spotify Connect (mDNS discovery)
  - 8080: HTTP streaming (カスタマイズ可能)

### 依存関係の最小化 / Minimal Dependencies
- セキュリティ面を考慮した最小限のランタイムパッケージ
- 定期的なセキュリティアップデート

## 🎯 設計の利点 / Design Benefits

### 1. 📦 モジュール性 / Modularity
各コンポーネントは独立しており、個別に更新・置換可能

Each component is independent and can be updated or replaced individually

### 2. 🔄 堅牢性 / Robustness
- stream-mixer.py が連続性を保証
- エラー時の自動再接続
- 適切なエラーハンドリング

### 3. ⚡ パフォーマンス / Performance
- Goによる軽量HTTPサーバー
- 効率的なパイプライン設計
- 最小限のメモリフットプリント

### 4. 🔧 設定の柔軟性 / Configuration Flexibility
- 環境変数による簡単な設定
- 複数のバックエンドサポート (pipe, alsa)
- カスタマイズ可能なストリーム情報

### 5. 🌐 互換性 / Compatibility
- Icecast互換ヘッダーでRoon対応
- 標準的なメディアプレイヤーで再生可能
- Dockerによるクロスプラットフォーム対応

## 🔍 トラブルシューティング / Troubleshooting

### コンポーネント別診断 / Component-specific Diagnostics

#### librespot
```bash
# ログ確認
docker logs roon-librespot-streamer | grep librespot

# 詳細ログ
docker run -e RUST_LOG=debug roon-librespot-streamer
```

#### stream-mixer.py
```bash
# ミキサーログ確認
docker logs roon-librespot-streamer | grep StreamMixer
```

#### ffmpeg
```bash
# FFmpegエラー確認
docker exec roon-librespot-streamer cat /tmp/ffmpeg-error.log
```

#### HTTP Streaming Server
```bash
# サーバーログ確認
docker logs roon-librespot-streamer | grep StreamServer

# ヘルスチェック
curl http://localhost:8080/health
```

## 📚 関連ドキュメント / Related Documentation

- [README.md](README.md) - プロジェクト概要と使用方法
- [ARCHITECTURE.md](ARCHITECTURE.md) - システムアーキテクチャ詳細
- [GETTING_STARTED.md](GETTING_STARTED.md) - 初心者向けガイド
- [HTTP_STREAMING_GUIDE.md](HTTP_STREAMING_GUIDE.md) - HTTPストリーミングの詳細
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - 実装サマリー

## ✅ 要件の達成状況 / Requirements Achievement Status

Issue #30 で要求された項目:

Requirements requested in Issue #30:

1. ✅ **システムに必要な要素をピックアップする**
   - librespot, stream-mixer.py, ffmpeg, HTTP streaming server を特定・実装済み

2. ✅ **Librespotで再生できるところまで作る (Issue #29)**
   - Spotify Connect完全対応
   - 高品質音声ストリーミング
   - キャッシュとパフォーマンス最適化

3. ✅ **Icecast2を模倣する軽量webアプリを作る**
   - Go言語による高性能HTTPサーバー
   - Icecast互換ヘッダー実装
   - Webインターフェース提供

4. ✅ **2と3を接続してspotifyをroonのWebラジオとして聴けるようにする**
   - 完全なパイプライン実装
   - Roon Internet Radio対応
   - 複数クライアント同時接続サポート

すべての要件が実装され、動作確認済みです。

All requirements have been implemented and verified.
