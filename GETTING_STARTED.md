# Getting Started Guide

このガイドでは、roon-librespot-streamerを最初から設定して実行する手順を説明します。

This guide walks you through setting up and running roon-librespot-streamer from scratch.

## Prerequisites (前提条件)

### Required (必須)
- Docker (version 20.10 or later)
- A Spotify Premium account (Spotify Connect requires Premium)
- Network connectivity

### Recommended (推奨)
- Docker Compose (for easier management)
- Basic understanding of Docker concepts

## Installation Steps (インストール手順)

### Step 1: Clone the Repository (リポジトリをクローン)

```bash
git clone https://github.com/WakuwakuP/roon-librespot-streamer.git
cd roon-librespot-streamer
```

### Step 2: Choose Your Configuration (設定を選択)

#### Option A: Use Default Settings (デフォルト設定を使用)

最も簡単な方法です。デフォルト設定で起動できます。

The easiest approach. Start with default settings:

```bash
docker compose up -d
```

#### Option B: Customize Settings (カスタム設定)

より細かく設定したい場合は、`.env`ファイルを作成します。

For more control, create a `.env` file:

```bash
# Copy the example file
cp .env.example .env

# Edit the file with your preferred settings
nano .env  # or use your preferred editor
```

編集後、起動します:

After editing, start the service:

```bash
docker compose up -d
```

### Step 3: Verify the Service (サービスを確認)

サービスが正常に起動しているか確認します:

Check that the service is running:

```bash
# Check container status
docker ps | grep roon-librespot-streamer

# View logs
docker logs roon-librespot-streamer
```

期待される出力:

Expected output:
```
Starting librespot with the following configuration:
  Device Name: Roon Librespot FLAC Streamer
  Bitrate: 320
  Backend: pipe
  ...
```

### Step 4: Connect from Spotify (Spotifyから接続)

1. Spotifyアプリを開く (Open the Spotify app)
2. 音楽を再生する (Play some music)
3. デバイス選択ボタンをクリック (Click the devices button)
4. "Roon Librespot FLAC Streamer"を選択 (Select "Roon Librespot FLAC Streamer")

![Spotify Connect Device Selection](https://i.imgur.com/placeholder.png)

### Step 5: Access the HTTP Stream (HTTPストリームにアクセス)

音楽が再生されると、HTTPストリームにアクセスできます。

Once music is playing, you can access the HTTP stream:

1. **Webブラウザで確認 (Check in web browser)**:
   ```
   http://localhost:8080/
   ```
   
2. **メディアプレイヤーで再生 (Play with media player)**:
   ```bash
   # VLC
   vlc http://localhost:8080/stream
   
   # mpv
   mpv http://localhost:8080/stream
   
   # ffplay
   ffplay http://localhost:8080/stream
   ```

3. **ヘルスチェック (Health check)**:
   ```
   http://localhost:8080/health
   ```

## Common Configurations (よく使う設定)

### Configuration 1: Basic Streaming (基本的なストリーミング)

デフォルト設定で十分な場合:

Default settings are sufficient:

```yaml
# docker-compose.yml (default)
environment:
  - DEVICE_NAME=Roon Librespot FLAC Streamer
  - BACKEND=pipe
  - BITRATE=320
  - HTTP_PORT=8080
```

アクセス (Access):
- ストリーム: `http://localhost:8080/stream`
- Webインターフェース: `http://localhost:8080/`

### Configuration 2: Multiple Devices (複数デバイス)

複数の部屋で使用する場合:

For multiple rooms:

```bash
# Room 1
docker run -d \
  --name librespot-room1 \
  --network host \
  -e DEVICE_NAME="Living Room Streamer" \
  -v librespot-cache-room1:/cache \
  roon-librespot-streamer

# Room 2
docker run -d \
  --name librespot-room2 \
  --network host \
  -e DEVICE_NAME="Bedroom Streamer" \
  -v librespot-cache-room2:/cache \
  roon-librespot-streamer
```

### Configuration 3: Direct Audio Output (直接音声出力)

スピーカーに直接出力する場合:

For direct speaker output:

```yaml
# docker-compose.yml
environment:
  - BACKEND=alsa
  - DEVICE=default
volumes:
  - /dev/snd:/dev/snd
devices:
  - /dev/snd:/dev/snd
```

### Configuration 4: High-Quality Settings (高音質設定)

最高品質の設定:

For maximum quality:

```yaml
environment:
  - BITRATE=320
  - BACKEND=pipe
  - VOLUME_CONTROL=fixed  # Disable volume control for bit-perfect output
  - INITIAL_VOLUME=100
```

## Updating (アップデート)

### Update the Container Image (コンテナイメージを更新)

```bash
# Stop the service
docker compose down

# Pull the latest changes
git pull

# Rebuild the image
docker compose build

# Start the service
docker compose up -d
```

### Updating Settings (設定を更新)

設定を変更する場合:

To change settings:

```bash
# Edit docker-compose.yml or .env
nano docker-compose.yml

# Restart the service
docker compose restart
```

## Maintenance (メンテナンス)

### View Logs (ログを表示)

```bash
# View all logs
docker logs roon-librespot-streamer

# Follow logs in real-time
docker logs -f roon-librespot-streamer

# View last 50 lines
docker logs --tail 50 roon-librespot-streamer
```

### Clear Cache (キャッシュをクリア)

キャッシュをクリアする必要がある場合:

If you need to clear the cache:

```bash
docker compose down -v
docker compose up -d
```

### Restart Service (サービスを再起動)

```bash
# Quick restart
docker compose restart

# Full restart (stops and starts)
docker compose down
docker compose up -d
```

## Performance Tuning (パフォーマンスチューニング)

### Increase Cache Size (キャッシュサイズを増やす)

```yaml
environment:
  - CACHE_SIZE_LIMIT=5G  # Increase from 1G to 5G
```

### Adjust Bitrate (ビットレートを調整)

ネットワーク帯域幅に応じて:

According to network bandwidth:

```yaml
environment:
  - BITRATE=160  # Lower quality, less bandwidth
  # or
  - BITRATE=320  # Higher quality, more bandwidth
```

### Enable Volume Normalization (音量正規化を有効化)

音量を自動調整する場合 (entrypoint.shで既に有効):

For automatic volume adjustment (already enabled in entrypoint.sh):

```bash
# Already included in entrypoint.sh:
--enable-volume-normalisation
```

## Uninstall (アンインストール)

完全に削除する場合:

To completely remove:

```bash
# Stop and remove containers
docker compose down

# Remove volumes (this deletes cached data)
docker compose down -v

# Remove images
docker rmi roon-librespot-streamer

# Remove the repository
cd ..
rm -rf roon-librespot-streamer
```

## Next Steps (次のステップ)

1. **Read ARCHITECTURE.md** for technical details
2. **Customize** your setup based on your needs
3. **Explore** advanced features
4. **Share** your setup with others

## Getting Help (ヘルプ)

問題が発生した場合:

If you encounter issues:

1. Check the [Troubleshooting section](README.md#troubleshooting) in README.md
2. Review logs: `docker logs roon-librespot-streamer`
3. Read [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
4. Open an issue on GitHub with logs and configuration

## Resources (リソース)

- [README.md](README.md) - Main documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [librespot documentation](https://github.com/librespot-org/librespot)
- [Docker documentation](https://docs.docker.com/)
- [FLAC format](https://xiph.org/flac/)
