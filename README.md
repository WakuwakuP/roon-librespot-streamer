# Roon Librespot FLAC Streamer

librespotで受け取ったSpotifyの音声をFLAC形式でストリーミングするDockerイメージです。

A Docker image that streams audio received from Spotify via librespot in FLAC format.

## Features

- 🎵 Spotify Connect対応 (Spotify Connect support)
- 🎼 FLAC形式での高音質ストリーミング (High-quality streaming in FLAC format)
- 🐳 Dockerで簡単にデプロイ (Easy deployment with Docker)
- 🔧 カスタマイズ可能な設定 (Customizable configuration)
- 💾 キャッシュ機能でパフォーマンス向上 (Performance improvement with cache)

## Requirements

- Docker
- Docker Compose (optional, but recommended)

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

### Using Docker

Build and run the image:
```bash
docker build -t roon-librespot-streamer .
docker run -d \
  --name roon-librespot-streamer \
  --network host \
  -e DEVICE_NAME="Roon Librespot FLAC Streamer" \
  -e BITRATE=320 \
  -v librespot-cache:/cache \
  roon-librespot-streamer
```

### Build Options

このプロジェクトは2つのDockerfileを提供しています:

This project provides two Dockerfiles:

1. **Dockerfile** (Default) - Uses pre-built librespot binaries for faster builds
   - Suitable for x86_64 and aarch64 architectures
   - Build time: ~30 seconds
   - Requires network access to download binaries

2. **Dockerfile.build-from-source** - Builds librespot from source for maximum compatibility
   - Build time: ~15-30 minutes (Rust compilation)
   - Requires more disk space and memory
   - Works on any architecture supported by Rust

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
| `CACHE_SIZE_LIMIT` | `1G` | キャッシュサイズ制限 |
| `SPOTIFY_USERNAME` | - | (Optional) Spotifyユーザー名 |
| `SPOTIFY_PASSWORD` | - | (Optional) Spotifyパスワード |
| `EXTRA_ARGS` | - | (Optional) librespot追加引数 |

### Backend Options

#### Pipe Backend (FLAC Streaming)
デフォルトの設定です。PCM音声をFLACに変換してストリーミングします。

The default configuration. Converts PCM audio to FLAC for streaming.

```yaml
environment:
  - BACKEND=pipe
```

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

## Usage Examples

### カスタムデバイス名で起動 (Start with custom device name)

```bash
docker run -d \
  --name my-streamer \
  --network host \
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

## Architecture

```
Spotify App → Spotify Connect → librespot → PCM Audio → ffmpeg → FLAC Stream
```

1. **librespot**: Spotify Connectクライアントとして動作し、Spotifyから音声を受信
2. **ffmpeg**: PCM音声をFLAC形式に変換
3. **Docker**: すべてのコンポーネントをコンテナ化して簡単にデプロイ

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