# Roon Librespot FLAC Streamer

librespotで受け取ったSpotifyの音声をFLAC形式でストリーミングするDockerイメージです。

A Docker image that streams audio received from Spotify via librespot in FLAC format.

## Features

- 🎵 Spotify Connect対応 (Spotify Connect support)
- 🎼 FLAC形式での高音質ストリーミング (High-quality streaming in FLAC format)
- 🌐 HTTP経由でのストリーミング配信 (HTTP streaming support)
- 🐳 Dockerで簡単にデプロイ (Easy deployment with Docker)
- 🔧 カスタマイズ可能な設定 (Customizable configuration)
- 💾 キャッシュ機能でパフォーマンス向上 (Performance improvement with cache)
- ⚡ 軽量・高性能なGoベースのストリーミングサーバー (Lightweight, high-performance Go-based streaming server)

## Requirements

- Docker
- Docker Compose (optional, but recommended)
- Spotify Premium account (for Spotify Connect)

## 📚 Documentation

- 🚀 [Getting Started Guide](GETTING_STARTED.md) - 初心者向けステップバイステップガイド
- 🏗️ [System Components](SYSTEM_COMPONENTS.md) - システム構成要素の詳細説明
- 🐳 [Docker Image Guide](DOCKER_IMAGE_GUIDE.md) - Dockerイメージの構造と最適化
- 🔧 [Architecture Details](ARCHITECTURE.md) - アーキテクチャの技術詳細
- 🌐 [HTTP Streaming Guide](HTTP_STREAMING_GUIDE.md) - HTTPストリーミングの詳細

📖 **New to this project? See the [Getting Started Guide](GETTING_STARTED.md) for step-by-step instructions!**

## Quick Start

### Using Docker Compose (Recommended)

1. Clone this repository:
```bash
git clone https://github.com/WakuwakuP/roon-librespot-streamer.git
cd roon-librespot-streamer
```

2. Start the container:
```bash
docker-compose up -d
# or with newer Docker versions:
docker compose up -d
```

3. The device will appear as "Roon Librespot FLAC Streamer" in your Spotify Connect device list.

4. Access the FLAC stream at `http://localhost:8080/stream` or view the web interface at `http://localhost:8080/`

### Using Docker

Build and run the image:
```bash
docker build -t roon-librespot-streamer .
docker run -d \
  --name roon-librespot-streamer \
  --network host \
  --add-host apresolve.spotify.com:0.0.0.0 \
  -e DEVICE_NAME="Roon Librespot FLAC Streamer" \
  -e BITRATE=320 \
  -v librespot-cache:/cache \
  roon-librespot-streamer
```

**Note:** The `--add-host apresolve.spotify.com:0.0.0.0` flag fixes audio key errors. See [Troubleshooting](#audio-key-errors) for more details.

### Build Options

このプロジェクトは2つのDockerfileを提供しています:

This project provides two Dockerfiles:

1. **Dockerfile** (Default) - Uses pre-built librespot binaries for faster builds
   - Suitable for x86_64 and aarch64 architectures
   - Build time: ~30 seconds
   - Requires network access to download binaries
   - Uses librespot stable version v0.8.0

2. **Dockerfile.build-from-source** - Builds librespot from source for maximum compatibility
   - Build time: ~15-30 minutes (Rust compilation)
   - Requires more disk space and memory
   - Works on any architecture supported by Rust
   - Uses librespot stable version v0.8.0

To use the default (binary) build:
```bash
docker build -t roon-librespot-streamer .
```

To use the source build:
```bash
docker build -f Dockerfile.build-from-source -t roon-librespot-streamer .
```

**Note for CI/CD environments**: If you encounter SSL certificate issues or network restrictions, use the source build option which clones from git.

## Testing the Image

Once built, you can test the image locally:

```bash
# Test that the image runs
docker run --rm roon-librespot-streamer librespot --help

# Test in verbose mode
docker run --rm -e DEVICE_NAME="Test Streamer" roon-librespot-streamer
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVICE_NAME` | `Roon Librespot FLAC Streamer` | Spotify Connectで表示されるデバイス名 (Device name shown in Spotify Connect) |
| `BITRATE` | `320` | ビットレート (96, 160, 320) |
| `INITIAL_VOLUME` | `50` | 初期音量 (0-100) |
| `VOLUME_CONTROL` | `linear` | ボリュームコントロール (linear, log, fixed) |
| `BACKEND` | `pipe` | オーディオバックエンド (pipe for FLAC streaming, alsa for direct output) |
| `HTTP_PORT` | `8080` | HTTPストリーミングサーバーのポート番号 (HTTP streaming server port) |
| `HTTP_BIND_ADDR` | `0.0.0.0` | HTTPサーバーのバインドアドレス (HTTP server bind address) |
| `PIPELINE_INIT_WAIT` | `3` | パイプライン初期化待機時間（秒） (Pipeline initialization wait time in seconds) |
| `STREAM_NAME` | `Roon Librespot FLAC Streamer` | ストリーム名 (Stream name for Icecast/Roon) |
| `STREAM_GENRE` | `Spotify` | ストリームジャンル (Stream genre for Icecast/Roon) |
| `STREAM_URL` | `https://github.com/...` | ストリーム情報URL (Stream info URL for Icecast/Roon) |
| `STREAM_DESCRIPTION` | `Spotify via Librespot...` | ストリーム説明 (Stream description for Icecast/Roon) |
| `CACHE_SIZE_LIMIT` | `1G` | キャッシュサイズ制限 |
| `RUST_LOG` | `warn,libmdns=error` | ログレベル (error, warn, info, debug, trace) / モジュール指定も可能 (Log level, module-specific filtering supported) |
| `SPOTIFY_USERNAME` | - | (Optional) Spotifyユーザー名 |
| `SPOTIFY_PASSWORD` | - | (Optional) Spotifyパスワード |
| `EXTRA_ARGS` | - | (Optional) librespot追加引数 |

### Backend Options

#### Pipe Backend (FLAC Streaming)
デフォルトの設定です。PCM音声をFLACに変換してHTTP経由でストリーミングします。

The default configuration. Converts PCM audio to FLAC and streams via HTTP.

```yaml
environment:
  - BACKEND=pipe
  - HTTP_PORT=8080
```

ストリーム配信のエンドポイント (Streaming endpoints):
- メインストリーム (Main stream): `http://{HOST}:8080/stream`
- Webインターフェース (Web interface): `http://{HOST}:8080/`
- ヘルスチェック (Health check): `http://{HOST}:8080/health`

#### ALSA Backend (Direct Audio Output)
直接ALSAデバイスに音声を出力します。

Outputs audio directly to an ALSA device.

```yaml
environment:
  - BACKEND=alsa
  - DEVICE=default
volumes:
  - /dev/snd:/dev/snd
devices:
  - /dev/snd:/dev/snd
```

## HTTP Streaming

### Accessing the Stream

HTTPストリーミングバックエンドを使用すると、FLAC音声ストリームにHTTP経由でアクセスできます。

When using the HTTP streaming backend, you can access the FLAC audio stream via HTTP.

**エンドポイント (Endpoints):**
- **メインストリーム (Main stream)**: `http://{HOST}:8080/stream`
  - FLAC形式のオーディオストリーム (FLAC audio stream)
- **Webインターフェース (Web interface)**: `http://{HOST}:8080/`
  - 使用方法と状態を表示 (Shows usage and status)
- **ヘルスチェック (Health check)**: `http://{HOST}:8080/health`
  - サーバーの状態をJSON形式で返す (Returns server status in JSON)

### 使用例 (Usage Examples)

**メディアプレイヤーで再生 (Playing with media players):**

```bash
# VLC
vlc http://localhost:8080/stream

# mpv
mpv http://localhost:8080/stream

# ffplay
ffplay http://localhost:8080/stream
```

**ブラウザでアクセス (Browser access):**
```
http://localhost:8080/
```

**カスタムポートで起動 (Custom port):**
```yaml
environment:
  - HTTP_PORT=9000
  - HTTP_BIND_ADDR=0.0.0.0
```

### 機能 (Features)

- ✅ 最大10クライアントの同時接続に対応 (Supports up to 10 concurrent clients)
- ✅ 自動的なタイムアウト処理 (Automatic timeout handling)
- ✅ エラーハンドリングとログ出力 (Error handling and logging)
- ✅ 軽量で高性能 (Lightweight and high-performance)
- ✅ JSONヘルスチェックAPI (JSON health check API)
- ✅ Icecast互換ヘッダー対応 (Icecast-compatible headers for Roon and other clients)

### Roonとの統合 (Roon Integration)

このストリーミングサーバーはIcecast互換のヘッダーを送信するため、Roonのインターネットラジオ機能に登録できます。

This streaming server sends Icecast-compatible headers, allowing it to be registered as an internet radio station in Roon.

**Roonへの登録手順 (How to register in Roon):**

1. このコンテナを起動する (Start this container)
2. Spotifyアプリでデバイスに接続し、音楽を再生する (Connect to the device in Spotify and play music)
3. Roonアプリを開く (Open Roon app)
4. Settings → Add Radio → Live Radio を選択 (Select Settings → Add Radio → Live Radio)
5. ストリームURLを入力: `http://{YOUR_IP}:8080/stream` (Enter stream URL: `http://{YOUR_IP}:8080/stream`)
6. Roonがストリーム情報を自動検出します (Roon will automatically detect stream info)

**カスタムストリーム情報 (Custom stream information):**

```yaml
environment:
  - STREAM_NAME=My Spotify Stream
  - STREAM_GENRE=Various
  - STREAM_DESCRIPTION=Spotify streaming via Librespot
  - STREAM_URL=http://my-server.local:8080
```

## Usage Examples

### カスタムデバイス名で起動 (Start with custom device name)

```bash
docker run -d \
  --name my-streamer \
  --network host \
  --add-host apresolve.spotify.com:0.0.0.0 \
  -e DEVICE_NAME="My Custom Streamer" \
  -v librespot-cache:/cache \
  roon-librespot-streamer
```

### 高ビットレートで起動 (Start with high bitrate)

```yaml
environment:
  - BITRATE=320
  - INITIAL_VOLUME=75
```

### Spotify認証情報を使用 (Using Spotify credentials)

```yaml
environment:
  - SPOTIFY_USERNAME=your_username
  - SPOTIFY_PASSWORD=your_password
```

**Note:** Spotify Connectを使用する方が推奨されます。認証情報の使用は必須ではありません。

**Note:** Using Spotify Connect is recommended. Credentials are not required.

## Troubleshooting

### デバイスが見つからない (Device not found)

1. `--network host`が設定されているか確認してください (Ensure `--network host` is set)
2. ファイアウォールがポート57500をブロックしていないか確認してください (Check firewall for port 57500)
3. 同じネットワークに接続されているか確認してください (Ensure you're on the same network)

### 音声が再生されない (No audio playback)

1. ログを確認してください: `docker logs roon-librespot-streamer`
2. BACKENDの設定を確認してください
3. ALSAバックエンドの場合、デバイスマッピングを確認してください

### キャッシュをクリア (Clear cache)

```bash
docker-compose down -v
docker-compose up -d
```

### Audio Key Errors / 音声キーエラー

If you see errors like "error audio key 0 1" or "Service unavailable { audio key error }", this prevents track playback because librespot cannot retrieve decryption keys from Spotify.

**症状 (Symptoms)**:
```
[ERROR librespot_core::audio_key] error audio key 0 1
[WARN librespot_playback::player] Unable to load key, continuing without decryption: Service unavailable { audio key error }
[ERROR librespot_playback::player] Unable to read audio file: Symphonia Decoder Error: Deadline expired before operation could complete
[ERROR librespot_playback::player] Skipping to next track, unable to load track
```

**解決策 (Solution)**:

This is caused by DNS resolution issues with `apresolve.spotify.com`. The fix is to block this domain, forcing librespot to use hardcoded API endpoints.

**For Docker Compose users** (already configured by default):
The `docker-compose.yml` file includes the fix via `extra_hosts`. Just ensure you're using the latest version:
```bash
docker-compose down
docker-compose pull
docker-compose up -d
```

**For Docker run users**:
Add the `--add-host` flag:
```bash
docker run -d \
  --name roon-librespot-streamer \
  --network host \
  --add-host apresolve.spotify.com:0.0.0.0 \
  -e DEVICE_NAME="Roon Librespot FLAC Streamer" \
  -v librespot-cache:/cache \
  roon-librespot-streamer
```

**For systems without Docker**:
Add the following line to your `/etc/hosts` file (requires root):
```bash
echo "0.0.0.0 apresolve.spotify.com" | sudo tee -a /etc/hosts
```

**注意 (Note)**: This workaround is based on solutions from the librespot community and has been confirmed to fix audio key errors. See [librespot issue #1649](https://github.com/librespot-org/librespot/issues/1649) for more details.

### トラックが再生できない / Track Unavailable Errors

If you see errors like "Track should be available, but no alternatives found" or "Skipping to next track, unable to load track", this is typically caused by Spotify backend changes that require an updated librespot version.

**症状 (Symptoms)**:
```
[ERROR librespot_playback::player] Track should be available, but no alternatives found.
[WARN librespot_playback::player] <spotify:track:...> is not available
[ERROR librespot_playback::player] Skipping to next track, unable to load track
```

**解決策 (Solution)**:
1. Update to the latest version of this project (uses librespot stable version v0.8.0)
2. Rebuild the Docker image:
   ```bash
   docker-compose down
   docker-compose up -d --build
   ```
3. Clear the cache if the issue persists:
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

**注意 (Note)**: This project now uses librespot stable version v0.8.0, which provides reliable Spotify Connect functionality and audio playback.

### ログの調整 (Adjusting Log Levels)

librespotは`RUST_LOG`環境変数でログレベルを制御できます。

You can control log levels using the `RUST_LOG` environment variable.

**デフォルト設定 (Default)**: `warn,libmdns=error,symphonia_bundle_mp3=error` - 警告レベル以上を表示、ただしmDNSとMP3デマルチプレクサの警告は非表示（これらは致命的ではありません）

Note: MP3 demuxer warnings like "skipping junk" or "invalid mpeg audio header" are non-fatal and typically don't affect playback. They're suppressed by default to reduce log noise.

**詳細ログ (Verbose logging)**:
```yaml
environment:
  - RUST_LOG=info  # 情報レベル以上を表示
```

**デバッグログ (Debug logging)**:
```yaml
environment:
  - RUST_LOG=debug  # デバッグ情報を含むすべてのログを表示
```

**特定モジュールのみ (Module-specific)**:
```yaml
environment:
  - RUST_LOG=warn,librespot=debug  # librespotのみデバッグレベル
```

**mDNS警告を表示 (Show mDNS warnings)**:
```yaml
environment:
  - RUST_LOG=warn  # すべての警告を表示 (mDNS含む)
```

**MP3デマルチプレクサ警告を表示 (Show MP3 demuxer warnings)**:
```yaml
environment:
  - RUST_LOG=warn,libmdns=error  # MP3警告を表示、mDNSは非表示
```

### MP3 Demuxer警告 / MP3 Demuxer Warnings

Symphoniaの MP3 デマルチプレクサから以下のような警告が表示されることがあります:

You may see warnings from Symphonia's MP3 demuxer like:
```
[WARN symphonia_bundle_mp3::demuxer] skipping junk at X bytes
[WARN symphonia_bundle_mp3::demuxer] invalid mpeg audio header
```

**これらは致命的なエラーではありません (These are not fatal errors)**

These warnings indicate that the MP3 decoder encountered unexpected data in the audio stream, but they are typically non-fatal and playback usually continues normally. These warnings are suppressed by default to reduce log noise.

**原因 (Causes)**:
- ストリームにわずかに破損したデータが含まれている (Minor corruption in the stream data)
- ネットワークの問題により不完全なデータを受信 (Incomplete data reception due to network issues)
- Spotifyのストリーム形式の変更 (Changes in Spotify's streaming format)

**解決策 (Solutions)**:
1. デフォルトの設定では、これらの警告は抑制されています (Default configuration suppresses these warnings)
2. 音声が正常に再生される場合、無視しても問題ありません (If audio plays normally, these can be safely ignored)
3. 音声が再生されない場合は、以下を試してください (If audio doesn't play, try):
   - コンテナを再起動: `docker-compose restart`
   - キャッシュをクリア: `docker-compose down -v && docker-compose up -d`
   - 別のトラックを試す (Try a different track)

## Architecture

```
Spotify App → Spotify Connect → librespot → PCM Audio → ffmpeg → FLAC → HTTP Server → Clients
                                                                                    ↓
                                                                        http://{IP}:{PORT}/stream
```

1. **librespot**: Spotify Connectクライアントとして動作し、Spotifyから音声を受信
2. **stream-mixer.py**: 音声ストリームの連続性を保証（librespot idle時に無音を挿入）
3. **ffmpeg**: PCM音声をFLAC形式に変換
4. **HTTP Streaming Server (Go)**: FLAC音声をHTTP経由で配信
   - 軽量で高性能 (Lightweight and high-performance)
   - 複数クライアントに対応 (Multi-client support)
   - エラーハンドリング (Error handling)
   - ヘルスチェックAPI (Health check API)
5. **Docker**: すべてのコンポーネントをコンテナ化して簡単にデプロイ

📖 **詳細なアーキテクチャ情報**: 
- [SYSTEM_COMPONENTS.md](SYSTEM_COMPONENTS.md) - システムコンポーネントの詳細とデータフロー
- [DOCKER_IMAGE_GUIDE.md](DOCKER_IMAGE_GUIDE.md) - Dockerイメージの構成と最適化ガイド
- [ARCHITECTURE.md](ARCHITECTURE.md) - アーキテクチャの技術詳細

## License

This project is provided as-is. Please refer to the licenses of the included components:
- [librespot](https://github.com/librespot-org/librespot) - MIT License
- [ffmpeg](https://ffmpeg.org/) - LGPL/GPL

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## References

- [librespot Documentation](https://github.com/librespot-org/librespot)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [FLAC Format](https://xiph.org/flac/)