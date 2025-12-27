# Architecture Documentation

## System Overview

このプロジェクトは、Spotify Connect から Roon WebRadio へ音楽をストリーミングするための Docker イメージを提供します。
ALSA デバイスがないホスト環境でも動作するように設計されています。

This project provides a Docker image for streaming music from Spotify Connect to Roon WebRadio.
It's designed to work in host environments without ALSA devices.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        User's Spotify App                       │
│                     (Phone, Desktop, etc.)                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ Spotify Connect Protocol
                             │ (mDNS discovery)
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Docker Container                           │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                      librespot                            │ │
│  │  - Spotify Connect クライアント                           │ │
│  │  - Spotify から音声を受信                                 │ │
│  │  - RAW PCM (s16le, 44.1kHz, stereo) を出力              │ │
│  └─────────────────────────┬─────────────────────────────────┘ │
│                            │ FIFO pipe                          │
│                            │ /tmp/librespot-audio               │
│                            ↓                                    │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              HTTP Streaming Server                        │ │
│  │              (Node.js + Express)                          │ │
│  │                                                           │ │
│  │  ┌─────────────────────────────────────────────┐        │ │
│  │  │            FFmpeg Process                   │        │ │
│  │  │  - FIFO から PCM 読み込み                   │        │ │
│  │  │  - MP3/Opus などにエンコード                │        │ │
│  │  │  - HTTP ストリーム出力                      │        │ │
│  │  └─────────────────────────────────────────────┘        │ │
│  │                                                           │ │
│  │  Endpoints:                                               │ │
│  │  - GET /stream  → Audio stream                          │ │
│  │  - GET /health  → Health check                          │ │
│  │  - GET /        → Info page                             │ │
│  └───────────────────────────┬───────────────────────────────┘ │
└────────────────────────────────┼──────────────────────────────┘
                                 │ HTTP Stream
                                 │ Port 3000 (configurable)
                                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                           Roon Core                             │
│                   (WebRadio として追加)                         │
│          http://<docker-host>:3000/stream                      │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. librespot

**役割 (Role):**
- Spotify Connect プロトコルを実装
- Spotify アプリからの音声ストリームを受信
- RAW PCM データを FIFO パイプに出力

**設定 (Configuration):**
```bash
librespot \
  --name "${DEVICE_NAME}" \
  --backend pipe \                    # FIFO パイプに出力
  --device /tmp/librespot-audio \     # FIFO パイプのパス
  --bitrate 320 \                     # ビットレート
  --initial-volume 100 \              # 初期音量
  --volume-ctrl linear \              # 音量制御方式
  --enable-volume-normalisation       # 音量正規化
```

### 2. FIFO Pipe (Named Pipe)

**役割 (Role):**
- librespot と Streaming Server 間のデータ転送
- ALSA デバイス不要のソリューション

**特徴 (Features):**
- バッファサイズはOSによって管理される
- ブロッキング I/O（読み手と書き手の同期）
- Docker コンテナ内の `/tmp` に配置

### 3. HTTP Streaming Server

**役割 (Role):**
- FIFO パイプから音声データを読み取り
- FFmpeg でエンコード
- HTTP ストリームとして配信

**Technology Stack:**
- Node.js 18
- Express.js (HTTP サーバー)
- FFmpeg (オーディオエンコーディング)

**FFmpeg Pipeline:**
```bash
ffmpeg \
  -f s16le \              # 入力フォーマット (16-bit signed little-endian)
  -ar 44100 \             # サンプルレート
  -ac 2 \                 # ステレオ
  -i /tmp/librespot-audio \  # 入力ソース (FIFO)
  -f mp3 \                # 出力フォーマット
  -b:a 320k \             # ビットレート
  -                       # stdout に出力
```

### 4. Docker Container

**Base Images:**
- Builder stage: `rust:1.75-slim` (librespot のビルド)
- Runtime stage: `node:18-slim` (サーバー実行)

**Exposed Ports:**
- 3000: HTTP ストリーミングポート (設定可能)

**Network Mode:**
- `host` モード推奨 (Spotify Connect の mDNS 検出に必要)

## Data Flow

1. **Spotify App → librespot**
   - Protocol: Spotify Connect (mDNS + proprietary)
   - Format: Encrypted Spotify stream (Ogg Vorbis)

2. **librespot → FIFO Pipe**
   - Format: RAW PCM
   - Sample format: s16le (16-bit signed little-endian)
   - Sample rate: 44.1 kHz
   - Channels: 2 (stereo)

3. **FIFO Pipe → FFmpeg**
   - Read blocking operation
   - Continuous stream processing

4. **FFmpeg → HTTP Response**
   - Format: MP3 (default) or other configured format
   - Bitrate: 320 kbps (default) or configured
   - HTTP headers: proper streaming headers

5. **HTTP Stream → Roon**
   - Protocol: HTTP/1.1
   - Connection: Keep-Alive
   - Content-Type: audio/mp3

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVICE_NAME` | `Spotify Connect (Roon)` | Spotify アプリに表示される名前 |
| `BITRATE` | `320` | librespot ビットレート (96, 160, 320) |
| `STREAM_FORMAT` | `mp3` | ストリーム形式 (mp3, opus, aac) |
| `STREAMING_PORT` | `3000` | HTTP サーバーポート |
| `FIFO_PATH` | `/tmp/librespot-audio` | FIFO パイプのパス |
| `INITIAL_VOLUME` | `100` | 初期音量 (0-100) |
| `VOLUME_CTRL` | `linear` | 音量制御 (linear, log) |

## Advantages of This Design

1. **No ALSA Required**
   - FIFO パイプを使用することで ALSA デバイスが不要
   - Docker コンテナで簡単に実行可能

2. **Flexible Audio Format**
   - FFmpeg により様々な形式に変換可能
   - Roon の要件に合わせて調整可能

3. **Scalable**
   - 複数のクライアントが同時に `/stream` に接続可能
   - 各クライアントに個別の FFmpeg プロセス

4. **Monitoring**
   - Health check エンドポイントで監視可能
   - クライアント数の確認

5. **Easy Deployment**
   - Docker Compose で一発起動
   - 環境変数で簡単にカスタマイズ

## Performance Considerations

### CPU Usage
- librespot: 最小限 (デコードのみ)
- FFmpeg: クライアント数に比例 (1クライアントあたり 5-10% CPU)

### Memory Usage
- librespot: ~20-50 MB
- Node.js server: ~30-50 MB
- FFmpeg per client: ~10-20 MB

### Network
- Spotify → librespot: ~320 kbps (設定による)
- Container → Roon: ~320 kbps per client (設定による)

## Troubleshooting

See [README.md](README.md) and [BUILD_NOTES.md](BUILD_NOTES.md) for troubleshooting information.
